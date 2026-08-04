-- Poco Pro project galleries: the first image remains the card cover while
-- up to three HTTPS images can be browsed in the project gallery.

alter table public.projects
  add column if not exists image_urls text[] not null default '{}'::text[];

update public.projects
set image_urls = array[image_url]
where image_url is not null
  and cardinality(image_urls) = 0;

create or replace function public.project_image_urls_are_safe(p_urls text[])
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  image_url text;
begin
  if cardinality(p_urls) > 3 then
    return false;
  end if;

  foreach image_url in array p_urls loop
    if image_url is null
       or length(image_url) > 2048
       or image_url !~ '^https://[^[:space:]]+$' then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

revoke all on function public.project_image_urls_are_safe(text[])
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'projects_image_urls_safe'
      and conrelid = 'public.projects'::regclass
  ) then
    alter table public.projects
      add constraint projects_image_urls_safe
      check (public.project_image_urls_are_safe(image_urls));
  end if;
end;
$$;

comment on column public.projects.image_urls is
  'Ordered project gallery. The first item is also mirrored in image_url for backward compatibility.';

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
  image_urls text[],
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
    case when locked.is_locked then '{}'::text[] else project.image_urls end,
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
  image_urls text[],
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
