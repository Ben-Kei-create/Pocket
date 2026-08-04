begin;

drop function if exists public.claim_star_coin_event(text);

create function public.claim_star_coin_event(p_event_key text)
returns table (
  star_coin_balance integer,
  awarded_coins integer,
  claimed boolean,
  wallet_revision bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  event_type_value text;
  base_reward_amount integer;
  reward_amount integer;
  payload text;
  payload_parts text[];
  first_feedback_id uuid;
  second_feedback_id uuid;
  first_avatar_key text;
  second_avatar_key text;
  interaction_base_coins_today integer;
  event_count_today integer;
  inserted_count integer;
  current_progress public.member_reward_progress%rowtype;
  is_pro boolean := false;
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
    base_reward_amount := 3;
    payload := substr(p_event_key, char_length('feedback-delivered:') + 1);
  elsif p_event_key like 'companion-tap:%' then
    event_type_value := 'companion_tap';
    base_reward_amount := 1;
    payload := substr(p_event_key, char_length('companion-tap:') + 1);
  elsif p_event_key like 'rare-birth:%' then
    event_type_value := 'rare_companion_birth';
    base_reward_amount := 5;
    payload := substr(p_event_key, char_length('rare-birth:') + 1);
  elsif p_event_key like 'rare-tap:%' then
    event_type_value := 'rare_companion_tap';
    base_reward_amount := 1;
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

  select exists (
    select 1 from public.memberships as membership
    where membership.user_id = current_user_id
      and membership.status in ('active', 'trialing')
      and (
        membership.current_period_end is null
        or membership.current_period_end > now()
      )
  ) into is_pro;

  reward_amount := base_reward_amount * case when is_pro then 2 else 1 end;

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
    if not is_pro then
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
    hashtextextended('poco-star-wallet:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  if exists (
    select 1 from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_key = p_event_key
  ) then
    return query select
      current_progress.star_coin_balance, 0, false,
      current_progress.wallet_revision;
    return;
  end if;

  if event_type_value = 'feedback_delivered' then
    select count(*)::integer into event_count_today
    from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_type = 'feedback_delivered'
      and transaction.created_at >= day_start;
    if event_count_today >= 20 then
      return query select
        current_progress.star_coin_balance, 0, false,
        current_progress.wallet_revision;
      return;
    end if;
  else
    select coalesce(sum(transaction.base_amount), 0)::integer
    into interaction_base_coins_today
    from public.star_coin_transactions as transaction
    where transaction.user_id = current_user_id
      and transaction.event_type in (
        'companion_tap', 'rare_companion_birth', 'rare_companion_tap'
      )
      and transaction.created_at >= day_start;
    if interaction_base_coins_today + base_reward_amount > 30 then
      return query select
        current_progress.star_coin_balance, 0, false,
        current_progress.wallet_revision;
      return;
    end if;
  end if;

  insert into public.star_coin_transactions (
    user_id, event_key, event_type, amount, base_amount
  ) values (
    current_user_id, p_event_key, event_type_value,
    reward_amount, base_reward_amount
  ) on conflict (user_id, event_key) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return query select
      current_progress.star_coin_balance, 0, false,
      current_progress.wallet_revision;
    return;
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance + reward_amount,
      lifetime_activity_coins = progress.lifetime_activity_coins + reward_amount,
      wallet_revision = progress.wallet_revision + 1,
      updated_at = now()
  where progress.user_id = current_user_id
  returning progress.* into current_progress;

  return query select
    current_progress.star_coin_balance, reward_amount, true,
    current_progress.wallet_revision;
end;
$$;

revoke all on function public.claim_star_coin_event(text)
  from public, anon;
grant execute on function public.claim_star_coin_event(text)
  to authenticated;

drop function if exists public.claim_daily_login_bonus();

create function public.claim_daily_login_bonus()
returns table (
  awarded_coins integer,
  star_coin_balance integer,
  login_streak integer,
  claimed boolean,
  claimed_day text,
  wallet_revision bigint
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
    hashtextextended('poco-star-wallet:' || current_user_id::text, 0)
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
      current_progress.login_streak, false, today_jst::text,
      current_progress.wallet_revision;
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
    user_id, event_key, event_type, amount, base_amount
  ) values (
    current_user_id,
    'login-bonus:' || today_jst::text,
    'login_bonus',
    reward_amount,
    reward_amount
  ) on conflict (user_id, event_key) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return query select
      0, current_progress.star_coin_balance,
      current_progress.login_streak, false, today_jst::text,
      current_progress.wallet_revision;
    return;
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance + reward_amount,
      login_streak = next_streak,
      last_login_bonus_day = today_jst,
      wallet_revision = progress.wallet_revision + 1,
      updated_at = now()
  where progress.user_id = current_user_id
  returning progress.* into current_progress;

  return query select
    reward_amount, current_progress.star_coin_balance,
    current_progress.login_streak, true, today_jst::text,
    current_progress.wallet_revision;
end;
$$;

revoke all on function public.claim_daily_login_bonus()
  from public, anon;
grant execute on function public.claim_daily_login_bonus()
  to authenticated;

commit;
