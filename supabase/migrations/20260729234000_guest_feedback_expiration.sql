begin;

alter table public.feedbacks
  add column if not exists expires_at timestamptz;

create index if not exists feedbacks_active_project_created_idx
  on public.feedbacks (project_id, created_at desc)
  where is_public = true and moderation_status = 'visible';

-- Existing anonymous posts follow the same lifetime as new guest posts. The
-- row remains for moderation/audit, but client roles cannot read it afterward.
update public.feedbacks as feedback
set expires_at = feedback.created_at + interval '24 hours'
where feedback.expires_at is null
  and feedback.author_profile_id is null
  and exists (
    select 1
    from public.feedback_ownership as ownership
    join auth.users as account on account.id = ownership.user_id
    where ownership.feedback_id = feedback.id
      and coalesce(account.is_anonymous, false) = true
  );

-- A creator's ordinary Like is the permanent "creator heart" signal. Promote
-- an ephemeral guest feedback in the same transaction so a received message
-- and its creator reaction never disappear independently.
create or replace function public.add_creator_heart_for_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.feedbacks as feedback
  set expires_at = null
  from public.projects as project
  where feedback.id = new.feedback_id
    and project.id = feedback.project_id
    and project.creator_id = new.user_id
    and feedback.expires_at is not null;

  insert into public.feedback_creator_receipts (feedback_id, creator_id, created_at)
  select feedback.id, new.user_id, new.created_at
  from public.feedbacks as feedback
  join public.projects as project on project.id = feedback.project_id
  where feedback.id = new.feedback_id
    and project.creator_id = new.user_id
  on conflict (feedback_id) do nothing;
  return new;
end;
$$;

revoke all on function public.add_creator_heart_for_like()
  from public, anon, authenticated;

-- Preserve already-received guest feedbacks when this migration is applied to
-- a database that has creator Likes from earlier app versions.
update public.feedbacks as feedback
set expires_at = null
from public.projects as project
where project.id = feedback.project_id
  and feedback.expires_at is not null
  and exists (
    select 1
    from public.feedback_likes as feedback_like
    where feedback_like.feedback_id = feedback.id
      and feedback_like.user_id = project.creator_id
  );

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
    stored_nickname := '名無しさん';
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

drop policy if exists "Visible feedback is readable" on public.feedbacks;
create policy "Visible feedback is readable"
  on public.feedbacks for select
  to anon, authenticated
  using (
    (expires_at is null or expires_at > now())
    and (
      (
        moderation_status = 'visible'
        and (
          (
            is_public
            and public.can_view_project_content(project_id)
            and not exists (
              select 1
              from public.user_blocks as block
              where block.blocker_id = (select auth.uid())
                and block.blocked_profile_id = feedbacks.author_profile_id
            )
          )
          or exists (
            select 1
            from public.feedback_ownership as ownership
            where ownership.feedback_id = feedbacks.id
              and ownership.user_id = (select auth.uid())
          )
          or exists (
            select 1
            from public.projects as project
            where project.id = feedbacks.project_id
              and project.creator_id = (select auth.uid())
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
            from public.projects as project
            where project.id = feedbacks.project_id
              and project.creator_id = (select auth.uid())
          )
        )
      )
    )
  );

create or replace function public.browse_projects(
  p_creator_id uuid default null
)
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
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  can_view_mature boolean := false;
begin
  if current_user_id is not null
     and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    select coalesce((
      select preference.show_mature_content
      from public.user_content_preferences as preference
      where preference.user_id = current_user_id
    ), false)
    into can_view_mature;
  end if;

  return query
  select
    project.id,
    project.creator_id,
    case when locked.is_locked then '年齢制限のある作品' else project.title end,
    project.creator_name,
    project.category,
    case when locked.is_locked
      then 'この作品は現在非表示です。'
      else project.description
    end,
    case when locked.is_locked then null else project.image_url end,
    project.created_at,
    project.is_published,
    case when locked.is_locked then 0 else (
      select count(feedback.id)::integer
      from public.feedbacks as feedback
      where feedback.project_id = project.id
        and feedback.is_public
        and feedback.moderation_status = 'visible'
        and (feedback.expires_at is null or feedback.expires_at > now())
    ) end,
    profile.avatar_name,
    profile.avatar_url,
    profile.handle,
    project.relationship,
    project.verification_status,
    project.content_rating,
    locked.is_locked
  from public.projects as project
  join public.profiles as profile on profile.id = project.creator_id
  cross join lateral (
    select (
      project.content_rating = 'mature'
      and project.creator_id is distinct from current_user_id
      and not can_view_mature
    ) as is_locked
  ) as locked
  where project.deleted_at is null
    and (
      (p_creator_id is null and project.is_published)
      or (
        p_creator_id is not null
        and project.creator_id = p_creator_id
        and (project.is_published or project.creator_id = current_user_id)
      )
    )
  order by project.created_at desc
  limit case when p_creator_id is null then 200 else 50 end;
end;
$$;

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
    and (feedback.expires_at is null or feedback.expires_at > now())
  order by feedback.created_at desc
  limit 500;
$$;

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
    and (feedback.expires_at is null or feedback.expires_at > now())
  order by feedback_like.created_at desc
  limit 500;
$$;

-- A creator's inbox must not keep exposing the preview after an ephemeral
-- guest feedback has disappeared. Non-feedback system notices are unaffected.
drop policy if exists "Registered recipients read notifications"
  on public.notifications;
create policy "Registered recipients read notifications"
  on public.notifications for select
  to authenticated
  using (
    recipient_id = (select auth.uid())
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, true) = false
    and (
      feedback_id is null
      or exists (
        select 1
        from public.feedbacks as feedback
        where feedback.id = notifications.feedback_id
          and (feedback.expires_at is null or feedback.expires_at > now())
      )
    )
  );

comment on column public.feedbacks.expires_at is
  'Guest feedback is hidden after this time unless a creator Like permanently promotes it by clearing the value.';

commit;
