-- Keep the public guest identity consistent with the iOS client.
-- Anonymous users cannot choose a public nickname; the server remains the
-- source of truth and ignores p_nickname for those sessions.
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
  stored_nickname text;
  feedback_expiration timestamptz;
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
    where id = p_project_id and is_published and deleted_at is null
  ) then
    raise exception 'Project is unavailable' using errcode = 'P0002';
  end if;

  if char_length(trim(p_message)) not between 1 and 500
     or p_bubble_color not in ('coral', 'yellow', 'mint', 'blue', 'lavender', 'pink') then
    raise exception 'Invalid feedback' using errcode = '22023';
  end if;

  if (
    select count(*)
    from public.feedback_ownership as ownership
    join public.feedbacks as feedback on feedback.id = ownership.feedback_id
    where ownership.user_id = current_user_id
      and feedback.created_at > now() - interval '5 minutes'
  ) >= 12 then
    raise exception 'Too many feedback submissions' using errcode = 'P0001';
  end if;

  if is_anonymous then
    stored_nickname := '名無し';
    feedback_expiration := now() + interval '24 hours';
  else
    if char_length(trim(p_nickname)) not between 1 and 80 then
      raise exception 'Invalid nickname' using errcode = '22023';
    end if;
    stored_nickname := trim(p_nickname);
    feedback_expiration := null;
    if p_publishes_profile then
      public_profile_id := current_user_id;
    end if;
  end if;

  insert into public.feedbacks (
    id,
    project_id,
    author_profile_id,
    nickname,
    message,
    is_public,
    bubble_color,
    likes_count,
    expires_at
  ) values (
    p_feedback_id,
    p_project_id,
    public_profile_id,
    stored_nickname,
    trim(p_message),
    p_is_public,
    p_bubble_color,
    0,
    feedback_expiration
  );

  insert into public.feedback_ownership (feedback_id, user_id)
  values (p_feedback_id, current_user_id);
end;
$$;

revoke all on function public.submit_feedback(uuid, uuid, text, text, boolean, text, boolean)
  from public, anon;
grant execute on function public.submit_feedback(uuid, uuid, text, text, boolean, text, boolean)
  to authenticated;
