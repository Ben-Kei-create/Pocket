-- A project's Poco owner and the author credited on the work are different
-- identities for fan-created and authorized feedback boxes.

alter table public.projects
  add column if not exists author_name text;

-- Before this migration creator_name was used as the work credit.
update public.projects
set author_name = creator_name
where author_name is null or btrim(author_name) = '';

alter table public.projects
  alter column author_name set not null;

-- creator_name is retained as an owner-profile snapshot for inserts and
-- internal compatibility. Public reads use the current profile name.
update public.projects as project
set creator_name = profile.display_name
from public.profiles as profile
where profile.id = project.creator_id;

comment on column public.projects.creator_name is
  'Snapshot of the Poco account name that owns this feedback box.';
comment on column public.projects.author_name is
  'Name credited on the work; it may differ from the Poco account owner.';

drop function if exists public.get_project(uuid);
drop function if exists public.browse_projects(uuid);

create function public.browse_projects(
  p_creator_id uuid default null
)
returns table (
  id uuid,
  creator_id uuid,
  title text,
  creator_name text,
  author_name text,
  category text,
  description text,
  image_url text,
  external_url text,
  created_at timestamptz,
  is_published boolean,
  feedback_count integer,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  relationship text,
  purpose text,
  verification_status text,
  content_rating text,
  is_content_locked boolean,
  accepts_questions boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  can_view_mature boolean := false;
begin
  if current_user_id is not null
     and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    select coalesce((
      select preference.show_mature_content
      from public.user_content_preferences as preference
      where preference.user_id = current_user_id
    ), false)
    into can_view_mature;
  end if;

  return query
  select
    project.id,
    project.creator_id,
    case when locked.is_locked then '年齢制限のある作品' else project.title end,
    profile.display_name,
    project.author_name,
    project.category,
    case when locked.is_locked
      then 'この作品は現在非表示です。'
      else project.description
    end,
    case when locked.is_locked then null else project.image_url end,
    case when locked.is_locked then null else project.external_url end,
    project.created_at,
    project.is_published,
    case when locked.is_locked then 0 else (
      select count(feedback.id)::integer
      from public.feedbacks as feedback
      where feedback.project_id = project.id
        and feedback.is_public
        and feedback.moderation_status = 'visible'
        and (feedback.expires_at is null or feedback.expires_at > now())
    ) end,
    profile.avatar_name,
    profile.avatar_url,
    profile.handle,
    project.relationship,
    project.purpose,
    project.verification_status,
    project.content_rating,
    locked.is_locked,
    project.accepts_questions
  from public.projects as project
  join public.profiles as profile on profile.id = project.creator_id
  cross join lateral (
    select (
      project.content_rating = 'mature'
      and project.creator_id is distinct from current_user_id
      and not can_view_mature
    ) as is_locked
  ) as locked
  where project.deleted_at is null
    and (
      (p_creator_id is null and project.is_published)
      or (
        p_creator_id is not null
        and project.creator_id = p_creator_id
        and (project.is_published or project.creator_id = current_user_id)
      )
    )
  order by project.created_at desc
  limit case when p_creator_id is null then 200 else 50 end;
end;
$$;

revoke all on function public.browse_projects(uuid) from public;
grant execute on function public.browse_projects(uuid) to anon, authenticated;

create function public.get_project(p_project_id uuid)
returns table (
  id uuid,
  creator_id uuid,
  title text,
  creator_name text,
  author_name text,
  category text,
  description text,
  image_url text,
  external_url text,
  created_at timestamptz,
  is_published boolean,
  feedback_count integer,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  relationship text,
  purpose text,
  verification_status text,
  content_rating text,
  is_content_locked boolean,
  accepts_questions boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_creator_id uuid;
begin
  select project.creator_id
  into target_creator_id
  from public.projects as project
  where project.id = p_project_id
    and project.deleted_at is null;

  if target_creator_id is null then
    return;
  end if;

  return query
  select project.*
  from public.browse_projects(target_creator_id) as project
  where project.id = p_project_id
  limit 1;
end;
$$;

revoke all on function public.get_project(uuid) from public;
grant execute on function public.get_project(uuid) to anon, authenticated;

-- Only an owner who registered the page as the work's actual creator can
-- produce the special creator heart. Authorized and fan-box owners still
-- add an ordinary Like, avoiding a false "the author reacted" signal.
create or replace function public.add_creator_heart_for_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.feedbacks as feedback
  set expires_at = null
  from public.projects as project
  where feedback.id = new.feedback_id
    and project.id = feedback.project_id
    and project.creator_id = new.user_id
    and project.relationship = 'creator'
    and feedback.expires_at is not null;

  insert into public.feedback_creator_receipts (feedback_id, creator_id, created_at)
  select feedback.id, new.user_id, new.created_at
  from public.feedbacks as feedback
  join public.projects as project on project.id = feedback.project_id
  where feedback.id = new.feedback_id
    and project.creator_id = new.user_id
    and project.relationship = 'creator'
  on conflict (feedback_id) do nothing;
  return new;
end;
$$;

revoke all on function public.add_creator_heart_for_like()
  from public, anon, authenticated;

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
      when project.creator_id = new.user_id
        and project.relationship = 'creator'
        then 'creator_heart'
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
