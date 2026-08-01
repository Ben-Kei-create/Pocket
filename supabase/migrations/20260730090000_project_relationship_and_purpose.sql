-- Separate the creator's relationship to a work from how the page is used.
-- A project can now be, for example, creator-owned and event-distributed.

alter table public.projects
  add column if not exists purpose text not null default 'standard';

alter table public.projects
  drop constraint if exists projects_relationship_check;

-- Legacy `event` described a purpose rather than a rights relationship. Keep
-- its visible event meaning while converting the unknown relationship to the
-- conservative, non-official fan category. The owner can correct it in edit.
update public.projects
set purpose = 'event',
    relationship = 'fan',
    verification_status = 'unverified'
where relationship = 'event';

alter table public.projects
  add constraint projects_relationship_check check (
    relationship in ('creator', 'authorized', 'fan')
  ),
  add constraint projects_purpose_check check (
    purpose in ('standard', 'event')
  );

comment on column public.projects.relationship is
  'Rights relationship: creator, authorized, or fan.';
comment on column public.projects.purpose is
  'Page use: standard discovery or event/distribution.';

-- get_project depends on browse_projects' row type, so remove it before
-- extending browse_projects with the purpose column.
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
  is_content_locked boolean
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
    project.creator_name,
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
    locked.is_locked
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
  is_content_locked boolean
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
