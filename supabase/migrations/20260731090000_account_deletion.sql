begin;

-- This table stores only the minimum operational record needed to prove that
-- an account deletion was requested. Report evidence already lives in the
-- dedicated immutable evidence tables and intentionally has no cascading FK.
create table if not exists public.account_deletion_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  project_count integer not null default 0 check (project_count >= 0),
  feedback_count integer not null default 0 check (feedback_count >= 0),
  reported_feedback_count integer not null default 0
    check (reported_feedback_count >= 0),
  reported_question_count integer not null default 0
    check (reported_question_count >= 0),
  requested_at timestamptz not null default now()
);

alter table public.account_deletion_events enable row level security;
revoke all on public.account_deletion_events from public, anon, authenticated;
grant all on public.account_deletion_events to service_role;

-- The Edge Function calls this after authenticating the caller. It prepares
-- public data for deletion without destroying report evidence. Repeating the
-- call is safe when Storage cleanup or Auth deletion needs to be retried.
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns table (
  project_count integer,
  feedback_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  owned_project_count integer;
  owned_feedback_count integer;
  owned_reported_feedback_count integer;
  related_reported_question_count integer;
begin
  if p_user_id is null then
    raise exception 'User is required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-account-delete:' || p_user_id::text, 0)
  );

  if not exists (
    select 1 from auth.users as account where account.id = p_user_id
  ) then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;

  select count(*)::integer
  into owned_project_count
  from public.projects as project
  where project.creator_id = p_user_id;

  select count(*)::integer
  into owned_feedback_count
  from public.feedback_ownership as ownership
  where ownership.user_id = p_user_id;

  select count(distinct report.id)::integer
  into owned_reported_feedback_count
  from public.feedback_reports as report
  join public.feedback_ownership as ownership
    on ownership.feedback_id = report.feedback_id
  where ownership.user_id = p_user_id;

  select count(distinct report.id)::integer
  into related_reported_question_count
  from public.question_reports as report
  join public.questions as question on question.id = report.question_id
  where question.sender_id = p_user_id
     or question.creator_id = p_user_id;

  insert into public.account_deletion_events (
    user_id,
    project_count,
    feedback_count,
    reported_feedback_count,
    reported_question_count,
    requested_at
  ) values (
    p_user_id,
    owned_project_count,
    owned_feedback_count,
    owned_reported_feedback_count,
    related_reported_question_count,
    now()
  )
  on conflict (user_id) do update
  set project_count = excluded.project_count,
      feedback_count = excluded.feedback_count,
      reported_feedback_count = excluded.reported_feedback_count,
      reported_question_count = excluded.reported_question_count,
      requested_at = excluded.requested_at;

  update public.feedbacks as feedback
  set moderation_status = 'deleted_by_author',
      is_public = false,
      author_profile_id = null,
      nickname = '名無しさん',
      message = '削除された感想です'
  where exists (
    select 1
    from public.feedback_ownership as ownership
    where ownership.feedback_id = feedback.id
      and ownership.user_id = p_user_id
  );

  update public.projects as project
  set is_published = false,
      deleted_at = coalesce(project.deleted_at, now()),
      purge_after = coalesce(project.purge_after, now() + interval '30 days')
  where project.creator_id = p_user_id;

  update public.questions as question
  set message = '削除された質問です',
      answer = null,
      status = 'removed_by_admin',
      answered_at = null,
      withdrawn_at = null
  where question.sender_id = p_user_id
     or question.creator_id = p_user_id;

  return query select owned_project_count, owned_feedback_count;
end;
$$;

revoke all on function public.prepare_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid)
  to service_role;

commit;
