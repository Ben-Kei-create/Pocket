begin;

alter table public.profiles
  add column if not exists avatar_name text;

alter table public.profiles
  drop constraint if exists profiles_avatar_name_check;

alter table public.profiles
  add constraint profiles_avatar_name_check check (
    avatar_name is null or avatar_name in (
      'PocoAvatarCat',
      'PocoAvatarPig',
      'PocoAvatarBear',
      'PocoAvatarDog',
      'PocoAvatarLion'
    )
  );

-- Built-in and uploaded avatars are mutually exclusive. Prefer an explicitly
-- selected built-in avatar when upgrading existing development data.
update public.profiles
set avatar_url = null
where avatar_name is not null
  and avatar_url is not null;

alter table public.profiles
  drop constraint if exists profiles_avatar_source_check;

alter table public.profiles
  add constraint profiles_avatar_source_check check (
    avatar_name is null or avatar_url is null
  );

create or replace view public.projects_with_feedback_count
with (security_invoker = true)
as
select
  p.id,
  p.creator_id,
  p.title,
  p.creator_name,
  p.category,
  p.description,
  p.image_url,
  p.created_at,
  p.is_published,
  count(f.id) filter (where f.is_public)::integer as feedback_count,
  pr.avatar_name as creator_avatar_name,
  pr.avatar_url as creator_avatar_url
from public.projects p
join public.profiles pr on pr.id = p.creator_id
left join public.feedbacks f on f.project_id = p.id
group by p.id, pr.avatar_name, pr.avatar_url;

grant select on public.projects_with_feedback_count to anon, authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-avatars',
  'profile-avatars',
  true,
  2097152,
  array['image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Profile avatars are publicly readable" on storage.objects;
create policy "Profile avatars are publicly readable"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'profile-avatars');

drop policy if exists "Registered users upload profile avatars" on storage.objects;
create policy "Registered users upload profile avatars"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered users update profile avatars" on storage.objects;
create policy "Registered users update profile avatars"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered users delete profile avatars" on storage.objects;
create policy "Registered users delete profile avatars"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

commit;
