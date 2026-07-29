begin;

-- Preserve the original reported content outside the user-editable feedback
-- row. This evidence intentionally has no cascading foreign keys.
create table if not exists public.feedback_report_evidence (
  report_id uuid primary key,
  feedback_id uuid not null,
  project_id uuid not null,
  author_user_id uuid,
  nickname text not null,
  message text not null,
  is_public boolean not null,
  bubble_color text not null,
  feedback_created_at timestamptz not null,
  captured_at timestamptz not null default now()
);

create index if not exists feedback_report_evidence_feedback_idx
  on public.feedback_report_evidence (feedback_id, captured_at desc);

alter table public.feedback_report_evidence enable row level security;
revoke all on public.feedback_report_evidence from public, anon, authenticated;
grant all on public.feedback_report_evidence to service_role;

create or replace function public.capture_feedback_report_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.feedback_report_evidence (
    report_id,
    feedback_id,
    project_id,
    author_user_id,
    nickname,
    message,
    is_public,
    bubble_color,
    feedback_created_at
  )
  select
    new.id,
    feedback.id,
    feedback.project_id,
    ownership.user_id,
    feedback.nickname,
    feedback.message,
    feedback.is_public,
    feedback.bubble_color,
    feedback.created_at
  from public.feedbacks as feedback
  left join public.feedback_ownership as ownership
    on ownership.feedback_id = feedback.id
  where feedback.id = new.feedback_id
  on conflict (report_id) do nothing;

  return new;
end;
$$;

revoke all on function public.capture_feedback_report_evidence()
  from public, anon, authenticated;

drop trigger if exists capture_feedback_report_evidence_after_insert
  on public.feedback_reports;
create trigger capture_feedback_report_evidence_after_insert
after insert on public.feedback_reports
for each row execute function public.capture_feedback_report_evidence();

-- Serialize report counting per account. The unique constraint still makes a
-- repeated report for the same feedback idempotent.
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

  if not exists (
    select 1 from public.feedbacks as feedback
    where feedback.id = p_feedback_id
  ) then
    raise exception 'Feedback not found' using errcode = 'P0002';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-report-rate:' || current_user_id::text, 0)
  );

  if (
    select count(*) from public.feedback_reports as report
    where report.reporter_id = current_user_id
      and report.created_at > now() - interval '1 day'
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

revoke all on function public.report_feedback(uuid, text, text)
  from public, anon;
grant execute on function public.report_feedback(uuid, text, text)
  to authenticated;

-- Moderation transitions are idempotent. Repeating the same RPC no longer
-- creates unbounded audit rows, and reported text remains in evidence above.
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
  current_status text;
begin
  if current_user_id is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select feedback.moderation_status
  into current_status
  from public.feedbacks as feedback
  where feedback.id = p_feedback_id
  for update;

  if not found then
    raise exception 'Feedback not found' using errcode = 'P0002';
  end if;

  if p_action = 'delete_by_author' then
    if not exists (
      select 1 from public.feedback_ownership as ownership
      where ownership.feedback_id = p_feedback_id
        and ownership.user_id = current_user_id
    ) then
      raise exception 'Not feedback owner' using errcode = '42501';
    end if;

    if current_status = 'deleted_by_author' then
      return;
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

    if current_status = 'hidden_by_creator' then
      return;
    end if;
    if current_status <> 'visible' then
      raise exception 'Invalid moderation transition' using errcode = '22023';
    end if;

    update public.feedbacks
      set moderation_status = 'hidden_by_creator',
          moderated_at = now()
      where id = p_feedback_id;
  else
    raise exception 'Invalid moderation action' using errcode = '22023';
  end if;

  insert into public.feedback_moderation_events (feedback_id, actor_id, action)
  values (p_feedback_id, current_user_id, p_action);
end;
$$;

revoke all on function public.moderate_feedback(uuid, text)
  from public, anon;
grant execute on function public.moderate_feedback(uuid, text)
  to authenticated;

create index if not exists feedback_ownership_user_created_idx
  on public.feedback_ownership (user_id, created_at desc);
create index if not exists feedback_likes_user_created_idx
  on public.feedback_likes (user_id, created_at desc);
create index if not exists feedback_reports_reporter_created_idx
  on public.feedback_reports (reporter_id, created_at desc);
create index if not exists feedbacks_public_project_created_idx
  on public.feedbacks (project_id, created_at desc)
  where is_public and moderation_status = 'visible';

-- Apply both the per-project cap and the short-window global submission rate
-- under advisory locks. This trigger is authoritative even under concurrency.
create or replace function public.enforce_feedback_submission_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_project_id uuid;
  target_creator_id uuid;
begin
  select feedback.project_id, project.creator_id
  into target_project_id, target_creator_id
  from public.feedbacks as feedback
  join public.projects as project on project.id = feedback.project_id
  where feedback.id = new.feedback_id;

  if target_project_id is null then
    raise exception 'Feedback is unavailable' using errcode = 'P0002';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-feedback-rate:' || new.user_id::text, 0)
  );

  if (
    select count(*)
    from public.feedback_ownership as ownership
    where ownership.user_id = new.user_id
      and ownership.created_at > now() - interval '5 minutes'
  ) >= 12 then
    raise exception 'Too many feedback submissions' using errcode = 'P0001';
  end if;

  -- A creator's block prevents the blocked account from sending new feedback.
  if exists (
    select 1 from public.user_blocks as block
    where block.blocker_id = target_creator_id
      and block.blocked_profile_id = new.user_id
  ) then
    raise exception 'Interaction is blocked' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(new.user_id::text || ':' || target_project_id::text, 0)
  );

  if (
    select count(*)
    from public.feedback_ownership as ownership
    join public.feedbacks as feedback on feedback.id = ownership.feedback_id
    where ownership.user_id = new.user_id
      and feedback.project_id = target_project_id
      and feedback.moderation_status <> 'deleted_by_author'
  ) >= 3 then
    raise exception 'Feedback submission limit reached' using errcode = 'P0003';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_feedback_submission_limit()
  from public, anon, authenticated;

-- Direct Like writes stay RLS-protected, while this trigger validates the
-- target state and caps high-speed automation for one account.
create or replace function public.validate_feedback_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or new.user_id is distinct from auth.uid() then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-like-rate:' || new.user_id::text, 0)
  );

  if (
    select count(*) from public.feedback_likes as feedback_like
    where feedback_like.user_id = new.user_id
      and feedback_like.created_at > now() - interval '1 hour'
  ) >= 120 then
    raise exception 'Too many likes' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.feedbacks as feedback
    join public.projects as project on project.id = feedback.project_id
    where feedback.id = new.feedback_id
      and feedback.is_public
      and feedback.moderation_status = 'visible'
      and project.is_published
      and project.deleted_at is null
  ) then
    raise exception 'Feedback is unavailable' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.feedbacks as feedback
    join public.user_blocks as block
      on block.blocked_profile_id = feedback.author_profile_id
    where feedback.id = new.feedback_id
      and block.blocker_id = new.user_id
  ) or exists (
    select 1
    from public.user_blocks as block
    where block.blocker_id = (
      select feedback.author_profile_id
      from public.feedbacks as feedback
      where feedback.id = new.feedback_id
    )
      and block.blocked_profile_id = new.user_id
  ) then
    raise exception 'Interaction is blocked' using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_feedback_like()
  from public, anon, authenticated;

drop trigger if exists validate_feedback_like_before_insert
  on public.feedback_likes;
create trigger validate_feedback_like_before_insert
before insert on public.feedback_likes
for each row execute function public.validate_feedback_like();

drop policy if exists "Users add their own likes" on public.feedback_likes;
create policy "Users add their own likes"
  on public.feedback_likes for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.feedbacks as feedback
      join public.projects as project on project.id = feedback.project_id
      where feedback.id = feedback_likes.feedback_id
        and feedback.is_public
        and feedback.moderation_status = 'visible'
        and project.is_published
        and project.deleted_at is null
    )
  );

-- Coins may gain economic utility later. Anonymous identities must never be
-- able to mint ledger rows simply by recycling guest accounts.
create or replace function public.reject_anonymous_coin_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() in ('anon', 'authenticated')
     and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.reject_anonymous_coin_transaction()
  from public, anon, authenticated;

drop trigger if exists reject_anonymous_coin_transaction_before_insert
  on public.star_coin_transactions;
create trigger reject_anonymous_coin_transaction_before_insert
before insert on public.star_coin_transactions
for each row execute function public.reject_anonymous_coin_transaction();

commit;
