begin;

-- Centralize the mature-content decision so direct Feedback access and
-- Realtime use the same server-side rule as Project browsing.
create or replace function public.can_view_project_content(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.is_published
      and project.deleted_at is null
      and (
        project.content_rating = 'general'
        or project.creator_id = auth.uid()
        or (
          auth.uid() is not null
          and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
          and exists (
            select 1
            from public.user_content_preferences as preference
            where preference.user_id = auth.uid()
              and preference.show_mature_content
          )
        )
      )
  );
$$;

revoke all on function public.can_view_project_content(uuid) from public;
grant execute on function public.can_view_project_content(uuid)
  to anon, authenticated;

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
          and public.can_view_project_content(project_id)
          and not exists (
            select 1
            from public.user_blocks as block
            where block.blocker_id = (select auth.uid())
              and block.blocked_profile_id = feedbacks.author_profile_id
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
          from public.projects as project
          where project.id = feedbacks.project_id
            and project.creator_id = (select auth.uid())
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
          from public.projects as project
          where project.id = feedbacks.project_id
            and project.creator_id = (select auth.uid())
        )
      )
    )
  );

drop policy if exists "Users add their own likes" on public.feedback_likes;
create policy "Users add their own likes"
  on public.feedback_likes for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.feedbacks as feedback
      where feedback.id = feedback_likes.feedback_id
        and feedback.is_public
        and feedback.moderation_status = 'visible'
        and public.can_view_project_content(feedback.project_id)
    )
  );

-- Anonymous Auth identities are not public profiles and cannot be edited into
-- convincing creator accounts. Registered users retain their current UI flow.
drop policy if exists "Users update their own profile" on public.profiles;
create policy "Registered users update their own profile"
  on public.profiles for update
  to authenticated
  using (
    (select auth.uid()) = id
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    (select auth.uid()) = id
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

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

  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, safe_display_name, null)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Bound future URL values and reject non-TLS schemes. The client additionally
-- enforces the exact Supabase Storage host and bucket path.
alter table public.profiles
  drop constraint if exists profiles_avatar_url_safe_check;
alter table public.profiles
  add constraint profiles_avatar_url_safe_check check (
    avatar_url is null
    or (
      char_length(avatar_url) <= 2048
      and avatar_url ~ '^https://'
    )
  ) not valid;

alter table public.projects
  drop constraint if exists projects_image_url_safe_check;
alter table public.projects
  add constraint projects_image_url_safe_check check (
    image_url is null
    or (
      char_length(image_url) <= 2048
      and image_url ~ '^https://'
    )
  ) not valid;

create or replace function public.owns_active_project(
  p_project_id text,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects as project
    where project.id::text = lower(p_project_id)
      and project.creator_id = p_user_id
      and project.deleted_at is null
  );
$$;

revoke all on function public.owns_active_project(text, uuid) from public;
grant execute on function public.owns_active_project(text, uuid)
  to authenticated;

-- Public buckets serve immutable public URLs without a storage.objects SELECT
-- policy. Removing the global policies prevents anonymous object listing.
drop policy if exists "Project images are publicly readable" on storage.objects;
drop policy if exists "Profile avatars are publicly readable" on storage.objects;

drop policy if exists "Project image owners read own objects" on storage.objects;
create policy "Project image owners read own objects"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered creators upload project images" on storage.objects;
create policy "Registered creators upload project covers"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (storage.foldername(name))[3]
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and storage.filename(name) = 'cover.jpg'
    and public.owns_active_project(
      (storage.foldername(name))[3],
      (select auth.uid())
    )
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered creators update project images" on storage.objects;
create policy "Registered creators update project covers"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (storage.foldername(name))[3]
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and storage.filename(name) = 'cover.jpg'
    and public.owns_active_project(
      (storage.foldername(name))[3],
      (select auth.uid())
    )
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (storage.foldername(name))[3]
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and storage.filename(name) = 'cover.jpg'
    and public.owns_active_project(
      (storage.foldername(name))[3],
      (select auth.uid())
    )
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered creators delete project images" on storage.objects;
create policy "Registered creators delete project covers"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and storage.filename(name) = 'cover.jpg'
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Profile avatar owners read own objects" on storage.objects;
create policy "Profile avatar owners read own objects"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered users upload profile avatars" on storage.objects;
create policy "Registered users upload one profile avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and storage.filename(name) = 'avatar.jpg'
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered users update profile avatars" on storage.objects;
create policy "Registered users update one profile avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and storage.filename(name) = 'avatar.jpg'
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and storage.filename(name) = 'avatar.jpg'
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Registered users delete profile avatars" on storage.objects;
create policy "Registered users delete one profile avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and storage.filename(name) = 'avatar.jpg'
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

commit;
