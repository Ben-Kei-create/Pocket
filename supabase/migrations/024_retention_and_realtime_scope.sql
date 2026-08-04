begin;

-- Scope Creator receipt Realtime by project instead of broadcasting every
-- receipt in the database to every open work page.
alter table public.feedback_creator_receipts
  add column if not exists project_id uuid references public.projects(id) on delete cascade;

update public.feedback_creator_receipts as receipt
set project_id = feedback.project_id
from public.feedbacks as feedback
where feedback.id = receipt.feedback_id
  and receipt.project_id is null;

alter table public.feedback_creator_receipts
  alter column project_id set not null;

create index if not exists feedback_creator_receipts_project_created_idx
  on public.feedback_creator_receipts (project_id, created_at desc);

create or replace function public.set_creator_receipt_project_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select feedback.project_id
  into new.project_id
  from public.feedbacks as feedback
  where feedback.id = new.feedback_id;

  if new.project_id is null then
    raise exception 'Feedback not found' using errcode = 'P0002';
  end if;
  return new;
end;
$$;

revoke all on function public.set_creator_receipt_project_id()
  from public, anon, authenticated;

drop trigger if exists set_creator_receipt_project_before_insert
  on public.feedback_creator_receipts;
create trigger set_creator_receipt_project_before_insert
before insert on public.feedback_creator_receipts
for each row execute function public.set_creator_receipt_project_id();

drop policy if exists "Creator receipts are publicly readable"
  on public.feedback_creator_receipts;
create policy "Visible creator receipts are readable"
  on public.feedback_creator_receipts for select
  to anon, authenticated
  using (
    public.can_view_project_content(project_id)
    or exists (
      select 1
      from public.feedback_ownership as ownership
      where ownership.feedback_id = feedback_creator_receipts.feedback_id
        and ownership.user_id = (select auth.uid())
    )
    or creator_id = (select auth.uid())
  );

-- A report only holds a deleted project while it is actively being reviewed.
-- Immutable evidence survives the eventual purge. An unresolved rights-holder
-- request is also an explicit legal/moderation hold.
create or replace function public.list_projects_ready_for_purge(
  p_limit integer default 100
)
returns table (
  id uuid,
  image_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select project.id, project.image_url
  from public.projects as project
  where project.deleted_at is not null
    and project.purge_after <= now()
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_reports as report
        on report.feedback_id = feedback.id
      where feedback.project_id = project.id
        and report.status in ('open', 'reviewing')
    )
    and not exists (
      select 1
      from public.rights_holder_requests as request
      where request.project_id = project.id
        and request.status in ('open', 'reviewing')
    )
  order by project.purge_after
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

create or replace function public.finalize_project_purge(p_project_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.projects as project
  where project.id = p_project_id
    and project.deleted_at is not null
    and project.purge_after <= now()
    and not exists (
      select 1
      from public.feedbacks as feedback
      join public.feedback_reports as report
        on report.feedback_id = feedback.id
      where feedback.project_id = project.id
        and report.status in ('open', 'reviewing')
    )
    and not exists (
      select 1
      from public.rights_holder_requests as request
      where request.project_id = project.id
        and request.status in ('open', 'reviewing')
    );

  get diagnostics deleted_count = row_count;
  return deleted_count = 1;
end;
$$;

revoke all on function public.list_projects_ready_for_purge(integer)
  from public, anon, authenticated;
revoke all on function public.finalize_project_purge(uuid)
  from public, anon, authenticated;
grant execute on function public.list_projects_ready_for_purge(integer)
  to service_role;
grant execute on function public.finalize_project_purge(uuid)
  to service_role;

commit;
