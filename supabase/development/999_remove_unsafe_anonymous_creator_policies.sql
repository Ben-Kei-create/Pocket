-- Run this after development testing and before promoting a Supabase project.
-- It removes every permission introduced by
-- 001_unsafe_anonymous_creator_policies.sql.

begin;

drop policy if exists "DEV ONLY anonymous project access" on public.projects;
drop policy if exists "DEV ONLY anonymous image upload" on storage.objects;

revoke insert, update, delete on public.projects from anon;
revoke insert on storage.objects from anon;

commit;
