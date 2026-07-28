begin;

alter table public.profiles
  add column if not exists handle text;

update public.profiles
set handle = 'poco_' || lower(substr(replace(id::text, '-', ''), 1, 12))
where handle is null or btrim(handle) = '';

create or replace function public.normalize_profile_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.handle is null or btrim(new.handle) = '' then
    new.handle := 'poco_' || lower(substr(replace(new.id::text, '-', ''), 1, 12));
  else
    new.handle := lower(trim(leading '@' from btrim(new.handle)));
  end if;

  if new.handle !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Invalid creator handle' using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function public.normalize_profile_handle()
  from public, anon, authenticated;

drop trigger if exists normalize_profile_handle_before_write on public.profiles;
create trigger normalize_profile_handle_before_write
  before insert or update of handle on public.profiles
  for each row execute procedure public.normalize_profile_handle();

alter table public.profiles
  alter column handle set not null;

create unique index if not exists profiles_handle_unique_idx
  on public.profiles (handle);

alter table public.profiles
  drop constraint if exists profiles_handle_check;
alter table public.profiles
  add constraint profiles_handle_check check (handle ~ '^[a-z0-9_]{3,24}$');

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
  profile.avatar_url as creator_avatar_url,
  profile.handle as creator_handle
from public.projects as project
join public.profiles as profile on profile.id = project.creator_id
left join public.feedbacks as feedback on feedback.project_id = project.id
group by project.id, profile.avatar_name, profile.avatar_url, profile.handle;

grant select on public.projects_with_feedback_count to anon, authenticated;

commit;
