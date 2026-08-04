begin;

-- My Page activity is scoped to the current Auth user. SECURITY DEFINER is
-- required so owners can also retrieve their own non-public feedback without
-- widening the public feedback RLS policy.
create or replace function public.my_feedbacks()
returns setof public.feedbacks
language sql
stable
security definer
set search_path = ''
as $$
  select feedback.*
  from public.feedback_ownership as ownership
  join public.feedbacks as feedback on feedback.id = ownership.feedback_id
  where ownership.user_id = auth.uid()
    and feedback.moderation_status <> 'deleted_by_author'
  order by feedback.created_at desc;
$$;

revoke all on function public.my_feedbacks() from public, anon;
grant execute on function public.my_feedbacks() to authenticated;

create or replace function public.my_liked_feedbacks()
returns setof public.feedbacks
language sql
stable
security definer
set search_path = ''
as $$
  select feedback.*
  from public.feedback_likes as feedback_like
  join public.feedbacks as feedback on feedback.id = feedback_like.feedback_id
  where feedback_like.user_id = auth.uid()
    and feedback.is_public
    and feedback.moderation_status = 'visible'
  order by feedback_like.created_at desc;
$$;

revoke all on function public.my_liked_feedbacks() from public, anon;
grant execute on function public.my_liked_feedbacks() to authenticated;

-- RLS already checks the plan limit, but two simultaneous inserts could both
-- observe the same count. This trigger serializes creation per creator and is
-- the final authority for the free 3 / Pro 30 project limits.
create or replace function public.enforce_project_creation_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  project_limit integer;
  current_project_count integer;
begin
  -- Trusted service-role maintenance remains possible. App clients must be a
  -- registered, non-anonymous owner of the new project.
  if auth.role() not in ('anon', 'authenticated') then
    return new;
  end if;

  if current_user_id is null
     or new.creator_id is distinct from current_user_id
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered creator authentication is required'
      using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-project-limit:' || current_user_id::text, 0)
  );

  project_limit := case
    when exists (
      select 1
      from public.memberships as membership
      where membership.user_id = current_user_id
        and membership.status in ('active', 'trialing')
        and (
          membership.current_period_end is null
          or membership.current_period_end > now()
        )
    ) then 30
    else 3
  end;

  select count(*)::integer
  into current_project_count
  from public.projects as project
  where project.creator_id = current_user_id;

  if current_project_count >= project_limit then
    raise exception 'Project creation limit reached' using errcode = 'P0004';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_project_creation_limit()
  from public, anon, authenticated;

drop trigger if exists enforce_project_creation_limit_before_insert
  on public.projects;
create trigger enforce_project_creation_limit_before_insert
  before insert on public.projects
  for each row execute function public.enforce_project_creation_limit();

commit;
