begin;

-- Immutable audit trail. App clients can read only their own history and can
-- never insert a balance or choose an award amount directly.
create table if not exists public.star_coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null check (char_length(event_key) between 1 and 180),
  event_type text not null check (
    event_type in (
      'login_bonus',
      'feedback_delivered',
      'companion_tap',
      'rare_companion_birth',
      'rare_companion_tap'
    )
  ),
  amount integer not null check (amount between 1 and 15),
  created_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create index if not exists star_coin_transactions_user_created_idx
  on public.star_coin_transactions (user_id, created_at desc);

alter table public.star_coin_transactions enable row level security;

drop policy if exists "Users read own star coin transactions"
  on public.star_coin_transactions;
create policy "Users read own star coin transactions"
  on public.star_coin_transactions for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.star_coin_transactions to authenticated;
revoke insert, update, delete on public.star_coin_transactions from anon, authenticated;

-- Mirrors Poco's deterministic UUID seed. It lets the database independently
-- verify the 15% companion and 5% rare-birth rules instead of trusting iOS.
create or replace function public.poco_stable_seed(p_value text)
returns bigint
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  result bigint := 0;
  position integer;
begin
  for position in 1..char_length(p_value) loop
    result := mod(result * 31 + ascii(substr(p_value, position, 1)), 2147483648);
  end loop;
  return result;
end;
$$;

revoke all on function public.poco_stable_seed(text) from public, anon, authenticated;

create or replace function public.claim_star_coin_event(p_event_key text)
returns table (
  star_coin_balance integer,
  awarded_coins integer,
  claimed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  event_type_value text;
  reward_amount integer;
  payload text;
  payload_parts text[];
  first_feedback_id uuid;
  second_feedback_id uuid;
  first_avatar_key text;
  second_avatar_key text;
  interaction_coins_today integer;
  event_count_today integer;
  inserted_count integer;
  current_balance integer;
  day_start timestamptz := (
    (now() at time zone 'Asia/Tokyo')::date at time zone 'Asia/Tokyo'
  );
begin
  if current_user_id is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if p_event_key is null or char_length(p_event_key) > 180 then
    raise exception 'Invalid coin event' using errcode = 'P0005';
  end if;

  if p_event_key like 'feedback-delivered:%' then
    event_type_value := 'feedback_delivered';
    reward_amount := 3;
    payload := substr(p_event_key, char_length('feedback-delivered:') + 1);
  elsif p_event_key like 'companion-tap:%' then
    event_type_value := 'companion_tap';
    reward_amount := 1;
    payload := substr(p_event_key, char_length('companion-tap:') + 1);
  elsif p_event_key like 'rare-birth:%' then
    event_type_value := 'rare_companion_birth';
    reward_amount := 5;
    payload := substr(p_event_key, char_length('rare-birth:') + 1);
  elsif p_event_key like 'rare-tap:%' then
    event_type_value := 'rare_companion_tap';
    reward_amount := 1;
    payload := substr(p_event_key, char_length('rare-tap:') + 1);
  else
    raise exception 'Unknown coin event' using errcode = 'P0005';
  end if;

  if event_type_value in ('feedback_delivered', 'companion_tap') then
    if payload !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Invalid feedback event' using errcode = 'P0005';
    end if;
    first_feedback_id := payload::uuid;
  else
    payload_parts := string_to_array(payload, ':');
    if array_length(payload_parts, 1) <> 2
       or payload_parts[1] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or payload_parts[2] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Invalid companion pair' using errcode = 'P0005';
    end if;
    first_feedback_id := payload_parts[1]::uuid;
    second_feedback_id := payload_parts[2]::uuid;
    if first_feedback_id::text >= second_feedback_id::text then
      raise exception 'Companion pair must be canonical' using errcode = 'P0005';
    end if;
  end if;

  if event_type_value = 'feedback_delivered' then
    if not exists (
      select 1
      from public.feedback_ownership as ownership
      join public.feedbacks as feedback on feedback.id = ownership.feedback_id
      where ownership.user_id = current_user_id
        and ownership.feedback_id = first_feedback_id
        and feedback.moderation_status <> 'deleted_by_author'
    ) then
      raise exception 'Feedback reward is unavailable' using errcode = '42501';
    end if;
  elsif event_type_value = 'companion_tap' then
    if public.poco_stable_seed(upper(first_feedback_id::text)) % 100 >= 15
       or not exists (
         select 1 from public.feedbacks as feedback
         where feedback.id = first_feedback_id
           and feedback.is_public
           and feedback.moderation_status = 'visible'
       ) then
      raise exception 'Companion is unavailable' using errcode = 'P0005';
    end if;
  else
    -- Evolution rewards are a Poco Pro capability.
    if not exists (
      select 1 from public.memberships as membership
      where membership.user_id = current_user_id
        and membership.status in ('active', 'trialing')
        and (
          membership.current_period_end is null
          or membership.current_period_end > now()
        )
    ) then
      raise exception 'Poco Pro is required' using errcode = '42501';
    end if;

    if public.poco_stable_seed(upper(first_feedback_id::text)) % 100 >= 15
       or public.poco_stable_seed(upper(second_feedback_id::text)) % 100 >= 15
       or public.poco_stable_seed(payload) % 100 >= 5 then
      raise exception 'Rare companion is unavailable' using errcode = 'P0005';
    end if;

    select coalesce(
      profile.avatar_name,
      'fallback:' || (public.poco_stable_seed(upper(feedback.id::text)) % 5)::text
    )
    into first_avatar_key
    from public.feedbacks as feedback
    left join public.profiles as profile on profile.id = feedback.author_profile_id
    where feedback.id = first_feedback_id
      and feedback.is_public
      and feedback.moderation_status = 'visible';

    select coalesce(
      profile.avatar_name,
      'fallback:' || (public.poco_stable_seed(upper(feedback.id::text)) % 5)::text
    )
    into second_avatar_key
    from public.feedbacks as feedback
    left join public.profiles as profile on profile.id = feedback.author_profile_id
    where feedback.id = second_feedback_id
      and feedback.is_public
      and feedback.moderation_status = 'visible';

    if first_avatar_key is null
       or second_avatar_key is null
       or first_avatar_key <> second_avatar_key then
      raise exception 'Companion pair does not match' using errcode = 'P0005';
    end if;

    if event_type_value = 'rare_companion_tap'
       and not exists (
         select 1 from public.star_coin_transactions as transaction
         where transaction.user_id = current_user_id
           and transaction.event_key = 'rare-birth:' || payload
       ) then
      raise exception 'Rare companion birth is not recorded' using errcode = 'P0005';
    end if;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-star-coins:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select progress.star_coin_balance
  into current_balance
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  if exists (
    select 1 from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_key = p_event_key
  ) then
    return query select current_balance, 0, false;
    return;
  end if;

  if event_type_value = 'feedback_delivered' then
    select count(*)::integer
    into event_count_today
    from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_type = 'feedback_delivered'
      and transaction.created_at >= day_start;
    if event_count_today >= 20 then
      return query select current_balance, 0, false;
      return;
    end if;
  else
    select coalesce(sum(transaction.amount), 0)::integer
    into interaction_coins_today
    from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_type in (
        'companion_tap', 'rare_companion_birth', 'rare_companion_tap'
      )
      and transaction.created_at >= day_start;
    if interaction_coins_today + reward_amount > 30 then
      return query select current_balance, 0, false;
      return;
    end if;
  end if;

  insert into public.star_coin_transactions (
    user_id, event_key, event_type, amount
  ) values (
    current_user_id, p_event_key, event_type_value, reward_amount
  ) on conflict (user_id, event_key) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return query select current_balance, 0, false;
    return;
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance + reward_amount,
      updated_at = now()
  where progress.user_id = current_user_id
  returning progress.star_coin_balance into current_balance;

  return query select current_balance, reward_amount, true;
end;
$$;

revoke all on function public.claim_star_coin_event(text) from public, anon;
grant execute on function public.claim_star_coin_event(text) to authenticated;

-- Replaces migration 014's daily function so login awards use the same wallet
-- and append-only ledger while keeping the public RPC response unchanged.
create or replace function public.claim_daily_login_bonus()
returns table (
  awarded_coins integer,
  star_coin_balance integer,
  login_streak integer,
  claimed boolean,
  claimed_day text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  today_jst date := (now() at time zone 'Asia/Tokyo')::date;
  current_progress public.member_reward_progress%rowtype;
  next_streak integer;
  reward_amount integer;
  inserted_count integer;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-star-coins:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  if current_progress.last_login_bonus_day = today_jst then
    return query select
      0, current_progress.star_coin_balance,
      current_progress.login_streak, false, today_jst::text;
    return;
  end if;

  next_streak := case
    when current_progress.last_login_bonus_day = today_jst - 1
      then current_progress.login_streak + 1
    else 1
  end;
  reward_amount := (array[3, 3, 5, 3, 5, 7, 15])[
    ((next_streak - 1) % 7) + 1
  ];

  insert into public.star_coin_transactions (
    user_id, event_key, event_type, amount
  ) values (
    current_user_id,
    'login-bonus:' || today_jst::text,
    'login_bonus',
    reward_amount
  ) on conflict (user_id, event_key) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return query select
      0, current_progress.star_coin_balance,
      current_progress.login_streak, false, today_jst::text;
    return;
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance + reward_amount,
      login_streak = next_streak,
      last_login_bonus_day = today_jst,
      updated_at = now()
  where progress.user_id = current_user_id;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  return query select
    reward_amount, current_progress.star_coin_balance,
    current_progress.login_streak, true, today_jst::text;
end;
$$;

revoke all on function public.claim_daily_login_bonus() from public, anon;
grant execute on function public.claim_daily_login_bonus() to authenticated;

commit;
