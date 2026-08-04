begin;

-- Project deletion is a moderation-sensitive operation. Keep the project,
-- feedbacks and related audit rows intact during the recovery window instead
-- of relying on the original ON DELETE CASCADE relationship.
alter table public.projects
  add column if not exists deleted_at timestamptz;
alter table public.projects
  add column if not exists purge_after timestamptz;

alter table public.projects
  drop constraint if exists projects_soft_delete_window_check;
alter table public.projects
  add constraint projects_soft_delete_window_check check (
    (deleted_at is null and purge_after is null)
    or (
      deleted_at is not null
      and purge_after is not null
      and purge_after >= deleted_at
    )
  );

create index if not exists projects_purge_after_idx
  on public.projects (purge_after)
  where deleted_at is not null;

-- This audit row intentionally has no cascading project foreign key. It must
-- survive the eventual physical purge for abuse and support investigations.
create table if not exists public.project_deletion_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  creator_id uuid not null,
  actor_id uuid,
  project_title text not null,
  deleted_at timestamptz not null,
  purge_after timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists project_deletion_events_project_idx
  on public.project_deletion_events (project_id, created_at desc);

alter table public.project_deletion_events enable row level security;
revoke all on public.project_deletion_events from public, anon, authenticated;
grant all on public.project_deletion_events to service_role;

-- Direct DELETE is no longer an app capability. Registered owners request a
-- soft delete through the narrow RPC below.
drop policy if exists "Creators delete their own projects" on public.projects;
drop policy if exists "Registered creators delete their own projects" on public.projects;
revoke delete on public.projects from anon, authenticated;

-- Deleted projects cannot be edited back into a public state through REST.
drop policy if exists "Registered creators update their own projects" on public.projects;
create policy "Registered creators update active projects"
  on public.projects for update
  to authenticated
  using (
    creator_id = (select auth.uid())
    and deleted_at is null
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    creator_id = (select auth.uid())
    and deleted_at is null
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

create or replace function public.soft_delete_project(p_project_id uuid)
returns table (
  id uuid,
  deleted_at timestamptz,
  purge_after timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  deletion_time timestamptz := now();
  purge_time timestamptz := deletion_time + interval '30 days';
  target_project public.projects%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;

  select project.*
  into target_project
  from public.projects as project
  where project.id = p_project_id
    and project.creator_id = current_user_id
    and project.deleted_at is null
  for update;

  if not found then
    raise exception 'Project not found' using errcode = 'P0002';
  end if;

  update public.projects as project
  set is_published = false,
      deleted_at = deletion_time,
      purge_after = purge_time
  where project.id = p_project_id;

  insert into public.project_deletion_events (
    project_id,
    creator_id,
    actor_id,
    project_title,
    deleted_at,
    purge_after
  ) values (
    target_project.id,
    target_project.creator_id,
    current_user_id,
    target_project.title,
    deletion_time,
    purge_time
  );

  return query select p_project_id, deletion_time, purge_time;
end;
$$;

revoke all on function public.soft_delete_project(uuid) from public, anon;
grant execute on function public.soft_delete_project(uuid) to authenticated;

-- Public feedback is readable only while its parent project is active. The
-- feedback author and project creator retain access for support/moderation.
drop policy if exists "Visible feedback is readable" on public.feedbacks;
create policy "Visible feedback is readable"
  on public.feedbacks for select
  to anon, authenticated
  using (
    (
      moderation_status = 'visible'
      and (
        (
          is_public
          and exists (
            select 1
            from public.projects
            where projects.id = feedbacks.project_id
              and projects.is_published
              and projects.deleted_at is null
          )
        )
        or exists (
          select 1
          from public.feedback_ownership as ownership
          where ownership.feedback_id = feedbacks.id
            and ownership.user_id = (select auth.uid())
        )
        or exists (
          select 1
          from public.projects
          where projects.id = feedbacks.project_id
            and projects.creator_id = (select auth.uid())
        )
      )
    )
    or (
      moderation_status = 'hidden_by_creator'
      and (
        exists (
          select 1
          from public.feedback_ownership as ownership
          where ownership.feedback_id = feedbacks.id
            and ownership.user_id = (select auth.uid())
        )
        or exists (
          select 1
          from public.projects
          where projects.id = feedbacks.project_id
            and projects.creator_id = (select auth.uid())
        )
      )
    )
  );

-- Preserve reports and moderation evidence indefinitely. A service-role purge
-- worker only receives projects with no report history. It must remove the
-- Storage object first, then call finalize_project_purge.
create or replace function public.list_projects_ready_for_purge(
  p_limit integer default 100
)
returns table (
  id uuid,
  image_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select project.id, project.image_url
  from public.projects as project
  where project.deleted_at is not null
    and project.purge_after <= now()
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_reports as report
        on report.feedback_id = feedback.id
      where feedback.project_id = project.id
    )
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_moderation_events as event
        on event.feedback_id = feedback.id
      where feedback.project_id = project.id
    )
  order by project.purge_after
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

create or replace function public.finalize_project_purge(p_project_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.projects as project
  where project.id = p_project_id
    and project.deleted_at is not null
    and project.purge_after <= now()
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_reports as report
        on report.feedback_id = feedback.id
      where feedback.project_id = project.id
    )
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_moderation_events as event
        on event.feedback_id = feedback.id
      where feedback.project_id = project.id
    );

  get diagnostics deleted_count = row_count;
  return deleted_count = 1;
end;
$$;

revoke all on function public.list_projects_ready_for_purge(integer)
  from public, anon, authenticated;
revoke all on function public.finalize_project_purge(uuid)
  from public, anon, authenticated;
grant execute on function public.list_projects_ready_for_purge(integer)
  to service_role;
grant execute on function public.finalize_project_purge(uuid)
  to service_role;

-- Keep the latest browse contract while excluding soft-deleted rows even from
-- an owner's own-project query.
create or replace function public.browse_projects(
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
  created_at timestamptz,
  is_published boolean,
  feedback_count integer,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  relationship text,
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
    project.created_at,
    project.is_published,
    case when locked.is_locked then 0 else (
      select count(feedback.id)::integer
      from public.feedbacks as feedback
      where feedback.project_id = project.id
        and feedback.is_public
        and feedback.moderation_status = 'visible'
    ) end,
    profile.avatar_name,
    profile.avatar_url,
    profile.handle,
    project.relationship,
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
  order by project.created_at desc;
end;
$$;

revoke all on function public.browse_projects(uuid) from public;
grant execute on function public.browse_projects(uuid) to anon, authenticated;

commit;
