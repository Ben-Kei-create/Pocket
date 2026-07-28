begin;

-- Clearly distinguish creator-owned, authorized, and unofficial fan boxes.
alter table public.projects
  add column if not exists relationship text not null default 'creator',
  add column if not exists verification_status text not null default 'unverified',
  add column if not exists publishing_rules_version integer,
  add column if not exists publishing_rules_accepted_at timestamptz;

alter table public.projects
  drop constraint if exists projects_relationship_check;
alter table public.projects
  add constraint projects_relationship_check check (
    relationship in ('creator', 'authorized', 'fan')
  );

alter table public.projects
  drop constraint if exists projects_verification_status_check;
alter table public.projects
  add constraint projects_verification_status_check check (
    verification_status in ('unverified', 'pending', 'verified')
  );

-- App users cannot self-assert a verified state. A future trusted moderation
-- service can set it with the service role. Changing relationship resets it.
create or replace function public.enforce_project_verification_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      if new.publishing_rules_version is distinct from 1
         or new.publishing_rules_accepted_at is null then
        raise exception 'Publishing rules agreement is required'
          using errcode = '22023';
      end if;
      new.verification_status := 'unverified';
    elsif new.relationship is distinct from old.relationship then
      new.verification_status := 'unverified';
    else
      new.verification_status := old.verification_status;
    end if;
    if tg_op = 'UPDATE' then
      new.publishing_rules_version := old.publishing_rules_version;
      new.publishing_rules_accepted_at := old.publishing_rules_accepted_at;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_project_verification_status()
  from public, anon, authenticated;

drop trigger if exists enforce_project_verification_status_before_write
  on public.projects;
create trigger enforce_project_verification_status_before_write
  before insert or update on public.projects
  for each row execute procedure public.enforce_project_verification_status();

-- A creator heart is not a separate reaction. Inserting the creator's normal
-- Like creates the visible heart receipt in the same transaction.
create or replace function public.add_creator_heart_for_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

drop trigger if exists creator_heart_after_feedback_like on public.feedback_likes;
create trigger creator_heart_after_feedback_like
  after insert on public.feedback_likes
  for each row execute procedure public.add_creator_heart_for_like();

-- Preserve historical "received" reactions by turning them into a normal
-- creator Like. The existing Like trigger safely increments likes_count.
insert into public.feedback_likes (id, feedback_id, user_id, created_at)
select gen_random_uuid(), receipt.feedback_id, receipt.creator_id, receipt.created_at
from public.feedback_creator_receipts as receipt
join public.feedbacks as feedback on feedback.id = receipt.feedback_id
join public.projects as project on project.id = feedback.project_id
where project.creator_id = receipt.creator_id
on conflict (feedback_id, user_id) do nothing;

-- Also restore a heart for creator Likes that predate this migration.
insert into public.feedback_creator_receipts (feedback_id, creator_id, created_at)
select feedback_like.feedback_id, feedback_like.user_id, feedback_like.created_at
from public.feedback_likes as feedback_like
join public.feedbacks as feedback on feedback.id = feedback_like.feedback_id
join public.projects as project on project.id = feedback.project_id
where project.creator_id = feedback_like.user_id
on conflict (feedback_id) do nothing;

-- Clients may only create creator hearts through the normal Like table.
drop policy if exists "Project creators add receipts"
  on public.feedback_creator_receipts;
revoke insert on public.feedback_creator_receipts from anon, authenticated;

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
  project.relationship,
  project.verification_status,
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
