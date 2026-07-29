begin;

alter table public.projects
  add column if not exists content_rating text not null default 'general';

alter table public.projects
  drop constraint if exists projects_content_rating_check;
alter table public.projects
  add constraint projects_content_rating_check check (
    content_rating in ('general', 'mature')
  );

create index if not exists projects_content_rating_published_idx
  on public.projects (content_rating, created_at desc)
  where is_published;

-- This preference is deliberately separate from the publicly readable profile.
-- The iOS app has no write privilege. A future authenticated web setting must
-- update it through a service-role Edge Function after policy checks.
create table if not exists public.user_content_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  show_mature_content boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.user_content_preferences enable row level security;

revoke all on public.user_content_preferences from public, anon, authenticated;
grant select, insert, update, delete on public.user_content_preferences to service_role;

-- Browsing is only exposed through this sanitizing server-authoritative query.
-- Locked rows reveal that a page exists, but never expose its title, description,
-- image URL or feedback count to a client that cannot view mature content.
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
    case when locked.is_locked
      then '年齢制限のある作品'
      else project.title
    end,
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
  where (
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

-- Prevent direct REST/select access from bypassing sanitization. Project writes
-- remain governed by the existing creator-only RLS policies and grants.
revoke select on public.projects from anon, authenticated;
revoke select on public.projects_with_feedback_count from anon, authenticated;

commit;
