begin;

-- Anonymous Auth users use the authenticated Postgres role, so creator
-- policies must also inspect the is_anonymous JWT claim.
drop policy if exists "Creators insert their own projects" on public.projects;
create policy "Registered creators insert their own projects"
  on public.projects for insert
  to authenticated
  with check (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Creators update their own projects" on public.projects;
create policy "Registered creators update their own projects"
  on public.projects for update
  to authenticated
  using (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Creators delete their own projects" on public.projects;
create policy "Registered creators delete their own projects"
  on public.projects for delete
  to authenticated
  using (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Creators upload project images" on storage.objects;
create policy "Registered creators upload project images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Creators update project images" on storage.objects;
create policy "Registered creators update project images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  )
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

drop policy if exists "Creators delete project images" on storage.objects;
create policy "Registered creators delete project images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
  );

commit;
