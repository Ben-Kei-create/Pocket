begin;

alter table public.projects
  drop constraint if exists projects_category_check;

alter table public.projects
  add constraint projects_category_check
  check (category in ('book', 'game', 'manga', 'anime', 'other'));

commit;
