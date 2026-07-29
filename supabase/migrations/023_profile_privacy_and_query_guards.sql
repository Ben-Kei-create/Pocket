begin;

-- Anonymous Auth rows support ownership and one-like-per-account, but they are
-- not public Poco profiles and must not be enumerable as members.
alter table public.profiles
  add column if not exists is_public_profile boolean not null default false;

update public.profiles as profile
set is_public_profile = not coalesce(account.is_anonymous, false)
from auth.users as account
where account.id = profile.id;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  safe_display_name text;
begin
  safe_display_name := left(
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      case when coalesce(new.is_anonymous, false)
        then 'Pocoゲスト'
        else 'Pocoメンバー'
      end),
    80
  );

  insert into public.profiles (
    id, display_name, avatar_url, is_public_profile
  ) values (
    new.id, safe_display_name, null, not coalesce(new.is_anonymous, false)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.sync_profile_registration_visibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set is_public_profile = not coalesce(new.is_anonymous, false)
  where id = new.id;
  return new;
end;
$$;

revoke all on function public.sync_profile_registration_visibility()
  from public, anon, authenticated;

drop trigger if exists sync_profile_registration_visibility_on_auth_user
  on auth.users;
create trigger sync_profile_registration_visibility_on_auth_user
after update of is_anonymous on auth.users
for each row
when (old.is_anonymous is distinct from new.is_anonymous)
execute function public.sync_profile_registration_visibility();

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Public profiles or own identity are readable"
  on public.profiles for select
  to anon, authenticated
  using (
    is_public_profile
    or id = (select auth.uid())
  );

-- Home is a bounded discovery query. Cursor pagination should replace this
-- guard when the catalog exceeds the MVP window; until then it prevents an
-- anonymous request from forcing an unbounded response.
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
  order by project.created_at desc
  limit case when p_creator_id is null then 200 else 50 end;
end;
$$;

revoke all on function public.browse_projects(uuid) from public;
grant execute on function public.browse_projects(uuid) to anon, authenticated;

-- Resolve one deep link through the creator-scoped bounded query rather than
-- scanning the entire Home catalog first.
create or replace function public.get_project(p_project_id uuid)
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

create or replace function public.my_feedbacks()
returns setof public.feedbacks
language sql
stable
security definer
set search_path = ''
as $$
  select feedback.*
  from public.feedback_ownership as ownership
  join public.feedbacks as feedback on feedback.id = ownership.feedback_id
  where ownership.user_id = auth.uid()
    and feedback.moderation_status <> 'deleted_by_author'
  order by feedback.created_at desc
  limit 500;
$$;

revoke all on function public.my_feedbacks() from public, anon;
grant execute on function public.my_feedbacks() to authenticated;

create or replace function public.my_liked_feedbacks()
returns setof public.feedbacks
language sql
stable
security definer
set search_path = ''
as $$
  select feedback.*
  from public.feedback_likes as feedback_like
  join public.feedbacks as feedback on feedback.id = feedback_like.feedback_id
  where feedback_like.user_id = auth.uid()
    and feedback.is_public
    and feedback.moderation_status = 'visible'
  order by feedback_like.created_at desc
  limit 500;
$$;

revoke all on function public.my_liked_feedbacks() from public, anon;
grant execute on function public.my_liked_feedbacks() to authenticated;

commit;
