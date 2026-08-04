begin;

alter table public.member_achievement_stamps
  drop constraint if exists member_achievement_stamps_stamp_key_check;
alter table public.member_achievement_stamps
  add constraint member_achievement_stamps_stamp_key_check check (
    stamp_key = any (array[
      'first_feedback', 'three_feedbacks', 'feedback_5', 'feedback_10',
      'feedback_20', 'feedback_30', 'feedback_50', 'feedback_100',
      'feedback_200', 'feedback_500', 'feedback_streak_2',
      'feedback_streak_3', 'feedback_streak_5', 'feedback_streak_7',
      'feedback_streak_10', 'feedback_streak_14', 'feedback_streak_21',
      'feedback_streak_30', 'feedback_streak_60', 'feedback_streak_100',
      'unique_projects_2', 'unique_projects_3', 'unique_projects_5',
      'unique_projects_10', 'unique_projects_20', 'unique_projects_30',
      'unique_projects_50', 'unique_projects_100', 'first_project',
      'projects_3', 'projects_5', 'projects_10', 'projects_20', 'projects_30',
      'first_like', 'likes_given_5', 'likes_given_10', 'likes_given_25',
      'likes_given_50', 'likes_given_100', 'likes_received_1',
      'likes_received_5', 'likes_received_10', 'likes_received_25',
      'likes_received_50', 'likes_received_100', 'creator_heart',
      'creator_hearts_3', 'creator_hearts_5', 'creator_hearts_10',
      'creator_hearts_25', 'creator_hearts_50', 'seven_day_streak',
      'thirty_day_login_streak'
    ]::text[])
  );

alter table public.notifications
  drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check check (
    type in (
      'new_feedback', 'feedback_like', 'creator_heart',
      'achievement', 'moderation', 'system'
    )
  );

-- All achievement conditions are calculated from trusted database records.
-- Newly unlocked stamps and their inbox notifications are written atomically.
create or replace function public.refresh_my_achievement_stamps()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  feedback_count integer := 0;
  feedback_streak integer := 0;
  unique_project_count integer := 0;
  project_count integer := 0;
  likes_given integer := 0;
  likes_received integer := 0;
  creator_hearts integer := 0;
  login_streak integer := 0;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-achievements:' || current_user_id::text, 0)
  );

  select count(*)::integer
  into feedback_count
  from public.feedback_ownership as ownership
  where ownership.user_id = current_user_id;

  with feedback_days as (
    select distinct
      (ownership.created_at at time zone 'Asia/Tokyo')::date as feedback_day
    from public.feedback_ownership as ownership
    where ownership.user_id = current_user_id
  ), grouped_days as (
    select
      feedback_day,
      feedback_day - (row_number() over (order by feedback_day))::integer as island
    from feedback_days
  ), streaks as (
    select count(*)::integer as streak_length
    from grouped_days
    group by island
  )
  select coalesce(max(streak_length), 0)
  into feedback_streak
  from streaks;

  select count(distinct feedback.project_id)::integer
  into unique_project_count
  from public.feedback_ownership as ownership
  join public.feedbacks as feedback on feedback.id = ownership.feedback_id
  where ownership.user_id = current_user_id;

  select count(*)::integer
  into project_count
  from public.projects as project
  where project.creator_id = current_user_id
    and project.deleted_at is null;

  select count(*)::integer
  into likes_given
  from public.feedback_likes as feedback_like
  where feedback_like.user_id = current_user_id;

  select count(*)::integer
  into likes_received
  from public.feedback_ownership as ownership
  join public.feedback_likes as feedback_like
    on feedback_like.feedback_id = ownership.feedback_id
  where ownership.user_id = current_user_id;

  select count(*)::integer
  into creator_hearts
  from public.feedback_ownership as ownership
  join public.feedback_creator_receipts as receipt
    on receipt.feedback_id = ownership.feedback_id
  where ownership.user_id = current_user_id;

  select coalesce(progress.login_streak, 0)
  into login_streak
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;
  login_streak := coalesce(login_streak, 0);

  with candidates(stamp_key, achieved) as (
    values
      ('first_feedback', feedback_count >= 1),
      ('three_feedbacks', feedback_count >= 3),
      ('feedback_5', feedback_count >= 5),
      ('feedback_10', feedback_count >= 10),
      ('feedback_20', feedback_count >= 20),
      ('feedback_30', feedback_count >= 30),
      ('feedback_50', feedback_count >= 50),
      ('feedback_100', feedback_count >= 100),
      ('feedback_200', feedback_count >= 200),
      ('feedback_500', feedback_count >= 500),
      ('feedback_streak_2', feedback_streak >= 2),
      ('feedback_streak_3', feedback_streak >= 3),
      ('feedback_streak_5', feedback_streak >= 5),
      ('feedback_streak_7', feedback_streak >= 7),
      ('feedback_streak_10', feedback_streak >= 10),
      ('feedback_streak_14', feedback_streak >= 14),
      ('feedback_streak_21', feedback_streak >= 21),
      ('feedback_streak_30', feedback_streak >= 30),
      ('feedback_streak_60', feedback_streak >= 60),
      ('feedback_streak_100', feedback_streak >= 100),
      ('unique_projects_2', unique_project_count >= 2),
      ('unique_projects_3', unique_project_count >= 3),
      ('unique_projects_5', unique_project_count >= 5),
      ('unique_projects_10', unique_project_count >= 10),
      ('unique_projects_20', unique_project_count >= 20),
      ('unique_projects_30', unique_project_count >= 30),
      ('unique_projects_50', unique_project_count >= 50),
      ('unique_projects_100', unique_project_count >= 100),
      ('first_project', project_count >= 1),
      ('projects_3', project_count >= 3),
      ('projects_5', project_count >= 5),
      ('projects_10', project_count >= 10),
      ('projects_20', project_count >= 20),
      ('projects_30', project_count >= 30),
      ('first_like', likes_given >= 1),
      ('likes_given_5', likes_given >= 5),
      ('likes_given_10', likes_given >= 10),
      ('likes_given_25', likes_given >= 25),
      ('likes_given_50', likes_given >= 50),
      ('likes_given_100', likes_given >= 100),
      ('likes_received_1', likes_received >= 1),
      ('likes_received_5', likes_received >= 5),
      ('likes_received_10', likes_received >= 10),
      ('likes_received_25', likes_received >= 25),
      ('likes_received_50', likes_received >= 50),
      ('likes_received_100', likes_received >= 100),
      ('creator_heart', creator_hearts >= 1),
      ('creator_hearts_3', creator_hearts >= 3),
      ('creator_hearts_5', creator_hearts >= 5),
      ('creator_hearts_10', creator_hearts >= 10),
      ('creator_hearts_25', creator_hearts >= 25),
      ('creator_hearts_50', creator_hearts >= 50),
      ('seven_day_streak', login_streak >= 7),
      ('thirty_day_login_streak', login_streak >= 30)
  ), unlocked as (
    insert into public.member_achievement_stamps (user_id, stamp_key)
    select current_user_id, candidate.stamp_key
    from candidates as candidate
    where candidate.achieved
    on conflict (user_id, stamp_key) do nothing
    returning
      member_achievement_stamps.stamp_key,
      member_achievement_stamps.unlocked_at
  )
  insert into public.notifications (
    recipient_id, event_key, type, created_at
  )
  select
    current_user_id,
    'achievement:' || unlocked.stamp_key,
    'achievement',
    unlocked.unlocked_at
  from unlocked
  on conflict (recipient_id, event_key) do nothing;
end;
$$;

revoke all on function public.refresh_my_achievement_stamps() from public, anon;
grant execute on function public.refresh_my_achievement_stamps() to authenticated;

commit;
