begin;

-- Universal Links must resolve a single project without requiring the client
-- to download the entire Home feed. The existing browse RPC remains the
-- canonical visibility and mature-content sanitizer.
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
language sql
stable
security definer
set search_path = ''
as $$
  select project.*
  from public.browse_projects(null::uuid) as project
  where project.id = p_project_id
  limit 1;
$$;

revoke all on function public.get_project(uuid) from public;
grant execute on function public.get_project(uuid) to anon, authenticated;

commit;
