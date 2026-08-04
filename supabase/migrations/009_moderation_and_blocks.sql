begin;

alter table public.feedbacks
  add column if not exists moderation_status text not null default 'visible';
alter table public.feedbacks
  add column if not exists moderated_at timestamptz;

alter table public.feedbacks
  drop constraint if exists feedbacks_moderation_status_check;
alter table public.feedbacks
  add constraint feedbacks_moderation_status_check check (
    moderation_status in (
      'visible',
      'hidden_by_creator',
      'deleted_by_author',
      'removed_by_admin'
    )
  );

create table if not exists public.feedback_reports (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedbacks(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (
    reason in (
      'harassment',
      'spam',
      'personal_information',
      'sexual_or_violent',
      'copyright',
      'other'
    )
  ),
  details text check (details is null or char_length(details) <= 500),
  status text not null default 'open' check (
    status in ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  unique (feedback_id, reporter_id)
);

create table if not exists public.feedback_moderation_events (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedbacks(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (
    action in ('hide_by_creator', 'delete_by_author', 'remove_by_admin', 'restore')
  ),
  created_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_profile_id),
  check (blocker_id <> blocked_profile_id)
);

create index if not exists feedback_reports_status_created_at_idx
  on public.feedback_reports (status, created_at desc);
create index if not exists feedback_moderation_events_feedback_id_idx
  on public.feedback_moderation_events (feedback_id, created_at desc);
create index if not exists user_blocks_blocker_id_idx
  on public.user_blocks (blocker_id);

alter table public.feedback_reports enable row level security;
alter table public.feedback_moderation_events enable row level security;
alter table public.user_blocks enable row level security;

drop policy if exists "Users read their own reports" on public.feedback_reports;
create policy "Users read their own reports"
  on public.feedback_reports for select
  to authenticated
  using (reporter_id = (select auth.uid()));

drop policy if exists "Users manage their own blocks" on public.user_blocks;
create policy "Users manage their own blocks"
  on public.user_blocks for all
  to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));

revoke all on public.feedback_reports from anon;
revoke insert, update, delete on public.feedback_reports from authenticated;
grant select on public.feedback_reports to authenticated;
revoke all on public.feedback_moderation_events from anon, authenticated;
revoke all on public.user_blocks from anon;
grant select, insert, delete on public.user_blocks to authenticated;

drop policy if exists "Visible feedback is readable" on public.feedbacks;
create policy "Visible feedback is readable"
  on public.feedbacks for select
  to anon, authenticated
  using (
    (
      moderation_status = 'visible'
      and (
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
      )
    )
    or (
      moderation_status = 'hidden_by_creator'
      and (
        exists (
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
      )
    )
  );

create or replace function public.report_feedback(
  p_feedback_id uuid,
  p_reason text,
  p_details text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_details text := nullif(trim(p_details), '');
begin
  if current_user_id is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;
  if p_reason not in (
    'harassment', 'spam', 'personal_information',
    'sexual_or_violent', 'copyright', 'other'
  ) or char_length(coalesce(normalized_details, '')) > 500 then
    raise exception 'Invalid report' using errcode = '22023';
  end if;
  if not exists (select 1 from public.feedbacks where id = p_feedback_id) then
    raise exception 'Feedback not found' using errcode = 'P0002';
  end if;
  if (
    select count(*) from public.feedback_reports
    where reporter_id = current_user_id
      and created_at > now() - interval '1 day'
  ) >= 20 then
    raise exception 'Too many reports' using errcode = 'P0001';
  end if;

  insert into public.feedback_reports (
    feedback_id, reporter_id, reason, details
  ) values (
    p_feedback_id, current_user_id, p_reason, normalized_details
  ) on conflict (feedback_id, reporter_id) do nothing;
end;
$$;

create or replace function public.moderate_feedback(
  p_feedback_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if p_action = 'delete_by_author' then
    if not exists (
      select 1 from public.feedback_ownership
      where feedback_id = p_feedback_id and user_id = current_user_id
    ) then
      raise exception 'Not feedback owner' using errcode = '42501';
    end if;

    delete from public.feedback_likes where feedback_id = p_feedback_id;
    delete from public.feedback_creator_receipts where feedback_id = p_feedback_id;
    update public.feedbacks
      set moderation_status = 'deleted_by_author',
          moderated_at = now(),
          is_public = false,
          author_profile_id = null,
          nickname = '削除済み',
          message = '削除された感想'
      where id = p_feedback_id;

  elsif p_action = 'hide_by_creator' then
    if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
       or not exists (
         select 1
         from public.feedbacks as feedback
         join public.projects as project on project.id = feedback.project_id
         where feedback.id = p_feedback_id
           and project.creator_id = current_user_id
       ) then
      raise exception 'Not project creator' using errcode = '42501';
    end if;

    update public.feedbacks
      set moderation_status = 'hidden_by_creator',
          moderated_at = now()
      where id = p_feedback_id
        and moderation_status = 'visible';
  else
    raise exception 'Invalid moderation action' using errcode = '22023';
  end if;

  insert into public.feedback_moderation_events (feedback_id, actor_id, action)
  values (p_feedback_id, current_user_id, p_action);
end;
$$;

revoke all on function public.report_feedback(uuid, text, text) from public, anon;
grant execute on function public.report_feedback(uuid, text, text) to authenticated;
revoke all on function public.moderate_feedback(uuid, text) from public, anon;
grant execute on function public.moderate_feedback(uuid, text) to authenticated;

create or replace view public.projects_with_feedback_count
with (security_invoker = true)
as
select
  project.id,
  project.creator_id,
  project.title,
  project.creator_name,
  project.category,
  project.description,
  project.image_url,
  project.created_at,
  project.is_published,
  count(feedback.id) filter (
    where feedback.is_public and feedback.moderation_status = 'visible'
  )::integer as feedback_count,
  profile.avatar_name as creator_avatar_name,
  profile.avatar_url as creator_avatar_url
from public.projects as project
join public.profiles as profile on profile.id = project.creator_id
left join public.feedbacks as feedback on feedback.project_id = project.id
group by project.id, profile.avatar_name, profile.avatar_url;

grant select on public.projects_with_feedback_count to anon, authenticated;

commit;
