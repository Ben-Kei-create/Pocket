-- DEVELOPMENT ONLY. Never apply this file to Production.
-- This temporarily lets an unauthenticated app exercise Creator/Storage flows
-- before Sign in with Apple is implemented.

grant insert, update, delete on public.projects to anon;
grant insert on storage.objects to anon;

drop policy if exists "DEV ONLY anonymous project access" on public.projects;
create policy "DEV ONLY anonymous project access"
  on public.projects for all
  to anon
  using (true)
  with check (true);

drop policy if exists "DEV ONLY anonymous image upload" on storage.objects;
create policy "DEV ONLY anonymous image upload"
  on storage.objects for insert
  to anon
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
  );
