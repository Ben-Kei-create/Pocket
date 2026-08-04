begin;

create table if not exists public.member_reward_progress (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  star_coin_balance integer not null default 0 check (star_coin_balance >= 0),
  login_streak integer not null default 0 check (login_streak >= 0),
  last_login_bonus_day date,
  updated_at timestamptz not null default now()
);

create table if not exists public.member_achievement_stamps (
  user_id uuid not null references public.profiles(id) on delete cascade,
  stamp_key text not null check (
    stamp_key in (
      'first_feedback',
      'three_feedbacks',
      'first_project',
      'first_like',
      'creator_heart',
      'seven_day_streak'
    )
  ),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, stamp_key)
);

alter table public.member_reward_progress enable row level security;
alter table public.member_achievement_stamps enable row level security;

drop policy if exists "Members read own reward progress"
  on public.member_reward_progress;
create policy "Members read own reward progress"
  on public.member_reward_progress for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Members read own achievement stamps"
  on public.member_achievement_stamps;
create policy "Members read own achievement stamps"
  on public.member_achievement_stamps for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.member_reward_progress to authenticated;
grant select on public.member_achievement_stamps to authenticated;
revoke insert, update, delete on public.member_reward_progress from anon, authenticated;
revoke insert, update, delete on public.member_achievement_stamps from anon, authenticated;

-- Awards the daily bonus once per calendar day in Poco's launch timezone.
-- The advisory lock prevents simultaneous claims from multiple devices.
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
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-login-bonus:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select progress.*
  into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  if current_progress.last_login_bonus_day = today_jst then
    return query select
      0,
      current_progress.star_coin_balance,
      current_progress.login_streak,
      false,
      today_jst::text;
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

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance + reward_amount,
      login_streak = next_streak,
      last_login_bonus_day = today_jst,
      updated_at = now()
  where progress.user_id = current_user_id;

  select progress.*
  into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  return query select
    reward_amount,
    current_progress.star_coin_balance,
    current_progress.login_streak,
    true,
    today_jst::text;
end;
$$;

revoke all on function public.claim_daily_login_bonus() from public, anon;
grant execute on function public.claim_daily_login_bonus() to authenticated;

-- Achievement conditions are evaluated from trusted database records. The app
-- only asks for a refresh; it cannot choose which stamps to unlock.
create or replace function public.refresh_my_achievement_stamps()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  insert into public.member_achievement_stamps (user_id, stamp_key)
  select current_user_id, candidate.stamp_key
  from (
    values
      (
        'first_feedback'::text,
        exists (
          select 1 from public.feedback_ownership as ownership
          where ownership.user_id = current_user_id
        )
      ),
      (
        'three_feedbacks'::text,
        (select count(*) from public.feedback_ownership as ownership
         where ownership.user_id = current_user_id) >= 3
      ),
      (
        'first_project'::text,
        exists (
          select 1 from public.projects as project
          where project.creator_id = current_user_id
        )
      ),
      (
        'first_like'::text,
        exists (
          select 1 from public.feedback_likes as feedback_like
          where feedback_like.user_id = current_user_id
        )
      ),
      (
        'creator_heart'::text,
        exists (
          select 1
          from public.feedback_ownership as ownership
          join public.feedback_creator_receipts as receipt
            on receipt.feedback_id = ownership.feedback_id
          where ownership.user_id = current_user_id
        )
      ),
      (
        'seven_day_streak'::text,
        coalesce((
          select progress.login_streak
          from public.member_reward_progress as progress
          where progress.user_id = current_user_id
        ), 0) >= 7
      )
  ) as candidate(stamp_key, achieved)
  where candidate.achieved
  on conflict (user_id, stamp_key) do nothing;
end;
$$;

revoke all on function public.refresh_my_achievement_stamps() from public, anon;
grant execute on function public.refresh_my_achievement_stamps() to authenticated;

commit;
