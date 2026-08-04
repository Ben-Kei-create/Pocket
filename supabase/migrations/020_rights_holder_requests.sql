begin;

-- Add the event/distribution classification promised by the publishing flow.
-- It describes the page's use without claiming that the page is official.
alter table public.projects
  drop constraint if exists projects_relationship_check;
alter table public.projects
  add constraint projects_relationship_check check (
    relationship in ('creator', 'authorized', 'fan', 'event')
  );

-- Rights-holder requests contain private contact information. App clients may
-- only create a validated request through the RPC below; only service_role can
-- review the stored rows.
create table if not exists public.rights_holder_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id) on delete set null,
  requester_id uuid references auth.users(id) on delete set null,
  project_title text not null,
  project_creator_name text not null,
  project_relationship text not null,
  requester_name text not null check (char_length(requester_name) between 1 and 80),
  requester_email text not null check (char_length(requester_email) between 3 and 254),
  requester_relationship text not null check (
    requester_relationship in (
      'rights_holder',
      'authorized_representative',
      'creator',
      'other'
    )
  ),
  details text not null check (char_length(details) between 1 and 1000),
  status text not null default 'open' check (
    status in ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists rights_holder_requests_status_created_idx
  on public.rights_holder_requests (status, created_at desc);
create index if not exists rights_holder_requests_project_idx
  on public.rights_holder_requests (project_id, created_at desc);
create index if not exists rights_holder_requests_requester_idx
  on public.rights_holder_requests (requester_id, created_at desc);

create unique index if not exists rights_holder_requests_one_active_per_requester_project
  on public.rights_holder_requests (requester_id, project_id)
  where requester_id is not null
    and project_id is not null
    and status in ('open', 'reviewing');

alter table public.rights_holder_requests enable row level security;
revoke all on public.rights_holder_requests from public, anon, authenticated;
grant all on public.rights_holder_requests to service_role;

create or replace function public.submit_rights_holder_request(
  p_project_id uuid,
  p_requester_name text,
  p_requester_email text,
  p_relationship text,
  p_details text
)
returns table (request_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_name text := trim(p_requester_name);
  normalized_email text := lower(trim(p_requester_email));
  normalized_details text := trim(p_details);
  target_project public.projects%rowtype;
  generated_id uuid := gen_random_uuid();
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('rights-holder-request:' || current_user_id::text, 0)
  );

  if char_length(normalized_name) not between 1 and 80
     or char_length(normalized_email) not between 3 and 254
     or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     or p_relationship not in (
       'rights_holder', 'authorized_representative', 'creator', 'other'
     )
     or char_length(normalized_details) not between 1 and 1000 then
    raise exception 'Invalid rights-holder request' using errcode = '22023';
  end if;

  select project.*
  into target_project
  from public.projects as project
  where project.id = p_project_id
    and project.deleted_at is null
  for share;

  if not found then
    raise exception 'Project not found' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.rights_holder_requests as request
    where request.requester_id = current_user_id
      and request.project_id = p_project_id
      and request.status in ('open', 'reviewing')
  ) then
    raise exception 'Active request already exists' using errcode = 'P0006';
  end if;

  if (
    select count(*)
    from public.rights_holder_requests as request
    where request.requester_id = current_user_id
      and request.created_at > now() - interval '1 day'
  ) >= 5 then
    raise exception 'Daily request limit reached' using errcode = 'P0007';
  end if;

  insert into public.rights_holder_requests (
    id,
    project_id,
    requester_id,
    project_title,
    project_creator_name,
    project_relationship,
    requester_name,
    requester_email,
    requester_relationship,
    details
  ) values (
    generated_id,
    target_project.id,
    current_user_id,
    target_project.title,
    target_project.creator_name,
    target_project.relationship,
    normalized_name,
    normalized_email,
    p_relationship,
    normalized_details
  );

  return query select generated_id;
exception
  when unique_violation then
    raise exception 'Active request already exists' using errcode = 'P0006';
end;
$$;

revoke all on function public.submit_rights_holder_request(
  uuid, text, text, text, text
) from public, anon;
grant execute on function public.submit_rights_holder_request(
  uuid, text, text, text, text
) to authenticated;

commit;
