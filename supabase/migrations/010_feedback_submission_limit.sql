begin;

-- A user can actively own at most three feedbacks per project. The trigger is
-- the final authority, including simultaneous submissions from two devices.
create or replace function public.enforce_feedback_submission_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_project_id uuid;
begin
  select feedback.project_id
  into target_project_id
  from public.feedbacks as feedback
  where feedback.id = new.feedback_id;

  if target_project_id is null then
    raise exception 'Feedback is unavailable' using errcode = 'P0002';
  end if;

  -- Serialize submissions for the same user and project so concurrent clients
  -- cannot both pass the count check.
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

drop trigger if exists enforce_feedback_submission_limit
  on public.feedback_ownership;
create trigger enforce_feedback_submission_limit
before insert on public.feedback_ownership
for each row execute function public.enforce_feedback_submission_limit();

create or replace function public.feedback_submission_count(p_project_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.feedback_ownership as ownership
  join public.feedbacks as feedback on feedback.id = ownership.feedback_id
  where ownership.user_id = auth.uid()
    and feedback.project_id = p_project_id
    and feedback.moderation_status <> 'deleted_by_author';
$$;

revoke all on function public.feedback_submission_count(uuid)
  from public, anon;
grant execute on function public.feedback_submission_count(uuid)
  to authenticated;

commit;
