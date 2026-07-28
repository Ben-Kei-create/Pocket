begin;

-- Feedback ownership is private application state. Public attribution is a
-- separate nullable profile reference, so an anonymous Auth ID never becomes
-- a tappable public profile by accident.
alter table public.feedbacks
  add column if not exists author_profile_id uuid
    references public.profiles(id) on delete set null;

create table if not exists public.feedback_ownership (
  feedback_id uuid primary key references public.feedbacks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

insert into public.feedback_ownership (feedback_id, user_id)
select id, sender_id
from public.feedbacks
where sender_id is not null
on conflict (feedback_id) do nothing;

update public.feedbacks as feedback
set author_profile_id = feedback.sender_id
from auth.users as account
where account.id = feedback.sender_id
  and coalesce(account.is_anonymous, false) = false
  and feedback.author_profile_id is null;

drop policy if exists "Visible feedback is readable" on public.feedbacks;
drop policy if exists "Guests and users submit feedback" on public.feedbacks;
drop policy if exists "Users update their own feedback" on public.feedbacks;
drop policy if exists "Users delete their own feedback" on public.feedbacks;

alter table public.feedbacks drop column if exists sender_id;

alter table public.feedback_ownership enable row level security;

drop policy if exists "Users read their own feedback ownership" on public.feedback_ownership;
create policy "Users read their own feedback ownership"
  on public.feedback_ownership for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Visible feedback is readable"
  on public.feedbacks for select
  to anon, authenticated
  using (
    is_public
    or exists (
      select 1
      from public.feedback_ownership as ownership
      where ownership.feedback_id = feedbacks.id
        and ownership.user_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.projects
      where projects.id = feedbacks.project_id
        and projects.creator_id = (select auth.uid())
    )
  );

revoke insert, update, delete on public.feedbacks from anon, authenticated;
revoke all on public.feedback_ownership from anon;
revoke insert, update, delete on public.feedback_ownership from authenticated;
-- The anon role needs table-level SELECT permission for the ownership
-- subquery in the feedback RLS policy. With RLS enabled and no anon policy it
-- still receives zero ownership rows.
grant select on public.feedback_ownership to anon, authenticated;

create or replace function public.submit_feedback(
  p_feedback_id uuid,
  p_project_id uuid,
  p_nickname text,
  p_message text,
  p_is_public boolean,
  p_bubble_color text,
  p_publishes_profile boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  is_anonymous boolean := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true);
  public_profile_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if exists (select 1 from public.feedbacks where id = p_feedback_id) then
    if exists (
      select 1 from public.feedback_ownership
      where feedback_id = p_feedback_id and user_id = current_user_id
    ) then
      return;
    end if;
    raise exception 'Feedback ID is already in use' using errcode = '23505';
  end if;

  if not exists (
    select 1 from public.projects
    where id = p_project_id and is_published
  ) then
    raise exception 'Project is unavailable' using errcode = 'P0002';
  end if;

  if char_length(trim(p_nickname)) not between 1 and 80
     or char_length(trim(p_message)) not between 1 and 500
     or p_bubble_color not in ('coral', 'yellow', 'mint', 'blue', 'lavender', 'pink') then
    raise exception 'Invalid feedback' using errcode = '22023';
  end if;

  -- Baseline abuse protection. Production should additionally apply an edge
  -- rate limiter keyed by user and network signals.
  if (
    select count(*)
    from public.feedback_ownership as ownership
    join public.feedbacks as feedback on feedback.id = ownership.feedback_id
    where ownership.user_id = current_user_id
      and feedback.created_at > now() - interval '5 minutes'
  ) >= 12 then
    raise exception 'Too many feedback submissions' using errcode = 'P0001';
  end if;

  if p_publishes_profile and not is_anonymous then
    public_profile_id := current_user_id;
  end if;

  insert into public.feedbacks (
    id,
    project_id,
    author_profile_id,
    nickname,
    message,
    is_public,
    bubble_color,
    likes_count
  ) values (
    p_feedback_id,
    p_project_id,
    public_profile_id,
    trim(p_nickname),
    trim(p_message),
    p_is_public,
    p_bubble_color,
    0
  );

  insert into public.feedback_ownership (feedback_id, user_id)
  values (p_feedback_id, current_user_id);
end;
$$;

revoke all on function public.submit_feedback(uuid, uuid, text, text, boolean, text, boolean)
  from public, anon;
grant execute on function public.submit_feedback(uuid, uuid, text, text, boolean, text, boolean)
  to authenticated;

-- A creator receipt is intentionally separate from normal Likes. Only the
-- owner of the feedback's project can create it, and everyone may see it.
create table if not exists public.feedback_creator_receipts (
  feedback_id uuid primary key references public.feedbacks(id) on delete cascade,
  creator_id uuid not null default auth.uid()
    references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.feedback_creator_receipts enable row level security;

drop policy if exists "Creator receipts are publicly readable"
  on public.feedback_creator_receipts;
create policy "Creator receipts are publicly readable"
  on public.feedback_creator_receipts for select
  to anon, authenticated
  using (true);

drop policy if exists "Project creators add receipts"
  on public.feedback_creator_receipts;
create policy "Project creators add receipts"
  on public.feedback_creator_receipts for insert
  to authenticated
  with check (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
    and exists (
      select 1
      from public.feedbacks as feedback
      join public.projects as project on project.id = feedback.project_id
      where feedback.id = feedback_creator_receipts.feedback_id
        and project.creator_id = (select auth.uid())
    )
  );

grant select on public.feedback_creator_receipts to anon, authenticated;
grant insert on public.feedback_creator_receipts to authenticated;
revoke update, delete on public.feedback_creator_receipts from anon, authenticated;

alter publication supabase_realtime add table public.feedback_creator_receipts;

-- Keep the client Capability and database project limits aligned. Existing
-- projects are retained when Pro expires; only creation above the free limit
-- is blocked.
drop policy if exists "Registered creators insert their own projects" on public.projects;
create policy "Registered creators insert projects within plan limit"
  on public.projects for insert
  to authenticated
  with check (
    creator_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
    and (
      select count(*)
      from public.projects as existing_project
      where existing_project.creator_id = (select auth.uid())
    ) < case
      when exists (
        select 1
        from public.memberships as membership
        where membership.user_id = (select auth.uid())
          and membership.status in ('active', 'trialing')
          and (
            membership.current_period_end is null
            or membership.current_period_end > now()
          )
      then 30
      else 3
    end
  );

commit;
