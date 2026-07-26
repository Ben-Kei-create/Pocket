begin;

alter table public.feedbacks replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feedbacks'
  ) then
    alter publication supabase_realtime add table public.feedbacks;
  end if;
end
$$;

commit;
