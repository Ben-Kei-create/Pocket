begin;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null check (char_length(event_key) between 1 and 240),
  type text not null check (
    type in ('new_feedback', 'feedback_like', 'creator_heart', 'moderation', 'system')
  ),
  project_id uuid references public.projects(id) on delete set null,
  feedback_id uuid references public.feedbacks(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  project_title text check (
    project_title is null or char_length(project_title) between 1 and 160
  ),
  actor_display_name text check (
    actor_display_name is null or char_length(actor_display_name) between 1 and 80
  ),
  message_preview text check (
    message_preview is null or char_length(message_preview) <= 160
  ),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (recipient_id, event_key)
);

create index if not exists notifications_recipient_created_at_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id, created_at desc)
  where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "Registered recipients read notifications"
  on public.notifications;
create policy "Registered recipients read notifications"
  on public.notifications for select
  to authenticated
  using (
    recipient_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

-- Clients never insert or mutate notification payloads. A narrow RPC below
-- is the only client path that changes read_at.
revoke all on public.notifications from anon;
revoke insert, update, delete on public.notifications from authenticated;
grant select on public.notifications to authenticated;
grant all on public.notifications to service_role;

create or replace function public.create_new_feedback_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
  target_project_title text;
  target_project_id uuid;
  public_actor_id uuid;
  actor_name text;
  target_message_preview text;
  feedback_created_at timestamptz;
begin
  select
    project.creator_id,
    project.title,
    feedback.project_id,
    feedback.author_profile_id,
    feedback.nickname,
    left(feedback.message, 160),
    feedback.created_at
  into
    target_user_id,
    target_project_title,
    target_project_id,
    public_actor_id,
    actor_name,
    target_message_preview,
    feedback_created_at
  from public.feedbacks as feedback
  join public.projects as project on project.id = feedback.project_id
  join auth.users as creator_account on creator_account.id = project.creator_id
  where feedback.id = new.feedback_id
    and coalesce(creator_account.is_anonymous, false) = false;

  if target_user_id is null or new.user_id = target_user_id then
    return new;
  end if;

  insert into public.notifications (
    recipient_id,
    event_key,
    type,
    project_id,
    feedback_id,
    actor_profile_id,
    project_title,
    actor_display_name,
    message_preview,
    created_at
  ) values (
    target_user_id,
    format('feedback:new:%s:%s', new.feedback_id, target_user_id),
    'new_feedback',
    target_project_id,
    new.feedback_id,
    public_actor_id,
    target_project_title,
    actor_name,
    target_message_preview,
    feedback_created_at
  )
  on conflict (recipient_id, event_key) do nothing;

  return new;
end;
$$;

revoke all on function public.create_new_feedback_notification()
  from public, anon, authenticated;

drop trigger if exists new_feedback_notification_after_insert
  on public.feedback_ownership;
create trigger new_feedback_notification_after_insert
  after insert on public.feedback_ownership
  for each row execute function public.create_new_feedback_notification();

create or replace function public.create_feedback_like_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
  target_project_id uuid;
  target_project_title text;
  target_message_preview text;
  notification_type text;
  public_actor_id uuid;
  actor_name text;
begin
  select
    ownership.user_id,
    feedback.project_id,
    project.title,
    left(feedback.message, 160),
    case
      when project.creator_id = new.user_id then 'creator_heart'
      else 'feedback_like'
    end
  into
    target_user_id,
    target_project_id,
    target_project_title,
    target_message_preview,
    notification_type
  from public.feedback_ownership as ownership
  join public.feedbacks as feedback on feedback.id = ownership.feedback_id
  join public.projects as project on project.id = feedback.project_id
  join auth.users as recipient_account on recipient_account.id = ownership.user_id
  where ownership.feedback_id = new.feedback_id
    and coalesce(recipient_account.is_anonymous, false) = false
  limit 1;

  if target_user_id is null or target_user_id = new.user_id then
    return new;
  end if;

  select profile.id, profile.display_name
  into public_actor_id, actor_name
  from public.profiles as profile
  join auth.users as actor_account on actor_account.id = profile.id
  where profile.id = new.user_id
    and coalesce(actor_account.is_anonymous, false) = false;

  insert into public.notifications (
    recipient_id,
    event_key,
    type,
    project_id,
    feedback_id,
    actor_profile_id,
    project_title,
    actor_display_name,
    message_preview,
    created_at
  ) values (
    target_user_id,
    format('feedback:%s:%s:%s', notification_type, new.feedback_id, new.user_id),
    notification_type,
    target_project_id,
    new.feedback_id,
    public_actor_id,
    target_project_title,
    actor_name,
    target_message_preview,
    new.created_at
  )
  on conflict (recipient_id, event_key) do nothing;

  return new;
end;
$$;

revoke all on function public.create_feedback_like_notification()
  from public, anon, authenticated;

drop trigger if exists feedback_like_notification_after_insert
  on public.feedback_likes;
create trigger feedback_like_notification_after_insert
  after insert on public.feedback_likes
  for each row execute function public.create_feedback_like_notification();

create or replace function public.mark_notification_read(p_notification_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  read_timestamp timestamptz;
begin
  if auth.uid() is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and recipient_id = auth.uid()
  returning read_at into read_timestamp;

  if read_timestamp is null then
    raise exception 'Notification not found' using errcode = 'P0002';
  end if;

  return read_timestamp;
end;
$$;

revoke all on function public.mark_notification_read(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

alter table public.notifications replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

commit;
