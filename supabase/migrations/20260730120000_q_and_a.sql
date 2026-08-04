begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  message text not null check (
    char_length(trim(message)) between 1 and 500
  ),
  answer text check (
    answer is null or char_length(trim(answer)) between 1 and 1000
  ),
  status text not null default 'pending' check (
    status in ('pending', 'answered', 'expired', 'withdrawn', 'removed_by_admin')
  ),
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  withdrawn_at timestamptz,
  check (sender_id <> creator_id),
  check ((status = 'answered') = (answer is not null and answered_at is not null)),
  check ((status = 'withdrawn') = (withdrawn_at is not null))
);

create index if not exists questions_sender_creator_created_idx
  on public.questions (sender_id, creator_id, created_at desc);
create index if not exists questions_creator_status_created_idx
  on public.questions (creator_id, status, created_at desc);
create index if not exists questions_project_created_idx
  on public.questions (project_id, created_at desc)
  where project_id is not null;

create table if not exists public.question_reports (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (
    reason in (
      'harassment', 'spam', 'personal_information',
      'sexual_or_violent', 'copyright', 'other'
    )
  ),
  details text check (details is null or char_length(details) <= 500),
  status text not null default 'open' check (
    status in ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  unique (question_id, reporter_id)
);

create index if not exists question_reports_status_created_idx
  on public.question_reports (status, created_at desc);
create index if not exists question_reports_reporter_created_idx
  on public.question_reports (reporter_id, created_at desc);

create table if not exists public.question_report_evidence (
  report_id uuid primary key,
  question_id uuid not null,
  sender_id uuid not null,
  creator_id uuid not null,
  project_id uuid,
  message text not null,
  answer text,
  question_created_at timestamptz not null,
  captured_at timestamptz not null default now()
);

alter table public.questions enable row level security;
alter table public.question_reports enable row level security;
alter table public.question_report_evidence enable row level security;

drop policy if exists "Question participants can read" on public.questions;
create policy "Question participants can read"
  on public.questions for select
  to authenticated
  using (
    (select auth.uid()) = sender_id
    or (select auth.uid()) = creator_id
  );

drop policy if exists "Question reporters read their reports" on public.question_reports;
create policy "Question reporters read their reports"
  on public.question_reports for select
  to authenticated
  using ((select auth.uid()) = reporter_id);

revoke all on public.questions from public, anon, authenticated;
grant select on public.questions to authenticated;
revoke all on public.question_reports from public, anon, authenticated;
grant select on public.question_reports to authenticated;
revoke all on public.question_report_evidence from public, anon, authenticated;
grant all on public.questions, public.question_reports, public.question_report_evidence
  to service_role;

create or replace function private.question_details(p_question_id uuid default null)
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    question.id,
    question.project_id,
    project.title,
    question.sender_id,
    sender.display_name,
    sender.avatar_name,
    sender.avatar_url,
    sender.handle,
    question.creator_id,
    creator.display_name,
    creator.avatar_name,
    creator.avatar_url,
    creator.handle,
    question.message,
    question.answer,
    case
      when question.status = 'pending'
        and question.created_at <= now() - interval '30 days'
      then 'expired'
      else question.status
    end,
    question.created_at,
    question.answered_at,
    question.withdrawn_at
  from public.questions as question
  join public.profiles as sender on sender.id = question.sender_id
  join public.profiles as creator on creator.id = question.creator_id
  left join public.projects as project on project.id = question.project_id
  where p_question_id is null or question.id = p_question_id;
$$;

revoke all on function private.question_details(uuid)
  from public, anon, authenticated;

create or replace function public.my_questions()
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;

  update public.questions as question
  set status = 'expired'
  where question.status = 'pending'
    and question.created_at <= now() - interval '30 days'
    and (question.sender_id = current_user_id or question.creator_id = current_user_id);

  return query
  select detail.*
  from private.question_details(null) as detail
  where detail.sender_id = current_user_id
     or detail.creator_id = current_user_id
  order by detail.created_at desc
  limit 500;
end;
$$;

create or replace function public.send_question(
  p_creator_id uuid,
  p_message text,
  p_project_id uuid default null
)
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_message text := trim(p_message);
  inserted_id uuid;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;
  if p_creator_id is null or p_creator_id = current_user_id
     or char_length(normalized_message) not between 1 and 500 then
    raise exception 'Invalid question' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.profiles as profile
    where profile.id = p_creator_id and profile.is_public_profile
  ) then
    raise exception 'Creator not found' using errcode = 'P0002';
  end if;
  if p_project_id is not null and not exists (
    select 1 from public.projects as project
    where project.id = p_project_id
      and project.creator_id = p_creator_id
      and project.deleted_at is null
      and project.is_published
  ) then
    raise exception 'Project not found' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.user_blocks as block
    where (block.blocker_id = current_user_id and block.blocked_profile_id = p_creator_id)
       or (block.blocker_id = p_creator_id and block.blocked_profile_id = current_user_id)
  ) then
    raise exception 'Interaction blocked' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      'poco-question:' || current_user_id::text || ':' || p_creator_id::text,
      0
    )
  );

  update public.questions as question
  set status = 'expired'
  where question.sender_id = current_user_id
    and question.creator_id = p_creator_id
    and question.status = 'pending'
    and question.created_at <= now() - interval '30 days';

  if (
    select count(*) from public.questions as question
    where question.sender_id = current_user_id
      and question.creator_id = p_creator_id
      and question.created_at > now() - interval '24 hours'
  ) >= 3 then
    raise exception 'Daily question limit reached' using errcode = 'P0011';
  end if;

  if (
    select count(*) from public.questions as question
    where question.sender_id = current_user_id
      and question.creator_id = p_creator_id
      and question.status = 'pending'
  ) >= 3 then
    raise exception 'Pending question limit reached' using errcode = 'P0012';
  end if;

  insert into public.questions as inserted (
    sender_id, creator_id, project_id, message
  ) values (
    current_user_id, p_creator_id, p_project_id, normalized_message
  ) returning inserted.id into inserted_id;

  return query select detail.* from private.question_details(inserted_id) as detail;
end;
$$;

create or replace function public.answer_question(
  p_question_id uuid,
  p_answer text
)
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_answer text := trim(p_answer);
  target public.questions%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;
  if char_length(normalized_answer) not between 1 and 1000 then
    raise exception 'Invalid answer' using errcode = '22023';
  end if;

  select question.* into target
  from public.questions as question
  where question.id = p_question_id
  for update;

  if not found then
    raise exception 'Question not found' using errcode = 'P0002';
  end if;
  if target.creator_id <> current_user_id then
    raise exception 'Not question creator' using errcode = '42501';
  end if;
  if target.status <> 'pending'
     or target.created_at <= now() - interval '30 days' then
    if target.status = 'pending' then
      update public.questions set status = 'expired' where questions.id = p_question_id;
    end if;
    raise exception 'Question unavailable' using errcode = 'P0013';
  end if;

  update public.questions
  set answer = normalized_answer,
      status = 'answered',
      answered_at = now()
  where questions.id = p_question_id;

  return query select detail.* from private.question_details(p_question_id) as detail;
end;
$$;

create or replace function public.withdraw_question(p_question_id uuid)
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target public.questions%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;

  select question.* into target
  from public.questions as question
  where question.id = p_question_id
  for update;

  if not found then
    raise exception 'Question not found' using errcode = 'P0002';
  end if;
  if target.sender_id <> current_user_id then
    raise exception 'Not question sender' using errcode = '42501';
  end if;
  if target.status <> 'pending'
     or target.created_at <= now() - interval '30 days' then
    if target.status = 'pending' then
      update public.questions set status = 'expired' where questions.id = p_question_id;
    end if;
    raise exception 'Question unavailable' using errcode = 'P0013';
  end if;

  update public.questions
  set status = 'withdrawn', withdrawn_at = now()
  where questions.id = p_question_id;

  return query select detail.* from private.question_details(p_question_id) as detail;
end;
$$;

create or replace function public.report_question(
  p_question_id uuid,
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
  report_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_reason not in (
    'harassment', 'spam', 'personal_information',
    'sexual_or_violent', 'copyright', 'other'
  ) or char_length(coalesce(normalized_details, '')) > 500 then
    raise exception 'Invalid report' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.questions as question
    where question.id = p_question_id
      and (question.sender_id = current_user_id or question.creator_id = current_user_id)
  ) then
    raise exception 'Question not found' using errcode = 'P0002';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-question-report:' || current_user_id::text, 0)
  );
  if (
    select count(*) from public.question_reports as report
    where report.reporter_id = current_user_id
      and report.created_at > now() - interval '24 hours'
  ) >= 20 then
    raise exception 'Too many reports' using errcode = 'P0007';
  end if;

  insert into public.question_reports (
    question_id, reporter_id, reason, details
  ) values (
    p_question_id, current_user_id, p_reason, normalized_details
  )
  on conflict (question_id, reporter_id) do nothing
  returning id into report_id;

  if report_id is not null then
    insert into public.question_report_evidence (
      report_id, question_id, sender_id, creator_id, project_id,
      message, answer, question_created_at
    )
    select
      report_id, question.id, question.sender_id, question.creator_id,
      question.project_id, question.message, question.answer, question.created_at
    from public.questions as question
    where question.id = p_question_id;
  end if;
end;
$$;

revoke all on function public.my_questions() from public, anon;
revoke all on function public.send_question(uuid, text, uuid) from public, anon;
revoke all on function public.answer_question(uuid, text) from public, anon;
revoke all on function public.withdraw_question(uuid) from public, anon;
revoke all on function public.report_question(uuid, text, text) from public, anon;
grant execute on function public.my_questions() to authenticated;
grant execute on function public.send_question(uuid, text, uuid) to authenticated;
grant execute on function public.answer_question(uuid, text) to authenticated;
grant execute on function public.withdraw_question(uuid) to authenticated;
grant execute on function public.report_question(uuid, text, text) to authenticated;

commit;
