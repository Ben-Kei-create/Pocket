begin;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  creator_name text not null check (char_length(creator_name) between 1 and 80),
  category text not null check (category in ('book', 'game', 'manga', 'other')),
  description text not null check (char_length(description) between 1 and 4000),
  image_url text,
  created_at timestamptz not null default now(),
  is_published boolean not null default true
);

create table if not exists public.feedbacks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  nickname text not null check (char_length(nickname) between 1 and 80),
  message text not null check (char_length(message) between 1 and 500),
  is_public boolean not null default true,
  bubble_color text not null check (
    bubble_color in ('coral', 'yellow', 'mint', 'blue', 'lavender', 'pink')
  ),
  likes_count integer not null default 0 check (likes_count >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.feedback_likes (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedbacks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (feedback_id, user_id)
);

create index if not exists projects_creator_id_created_at_idx
  on public.projects (creator_id, created_at desc);
create index if not exists projects_published_created_at_idx
  on public.projects (is_published, created_at desc);
create index if not exists feedbacks_project_id_created_at_idx
  on public.feedbacks (project_id, created_at desc);
create index if not exists feedback_likes_feedback_id_idx
  on public.feedback_likes (feedback_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Pocoメンバー'),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.sync_feedback_likes_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.feedbacks
      set likes_count = likes_count + 1
      where id = new.feedback_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.feedbacks
      set likes_count = greatest(likes_count - 1, 0)
      where id = old.feedback_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists feedback_likes_count_after_insert on public.feedback_likes;
create trigger feedback_likes_count_after_insert
  after insert on public.feedback_likes
  for each row execute procedure public.sync_feedback_likes_count();

drop trigger if exists feedback_likes_count_after_delete on public.feedback_likes;
create trigger feedback_likes_count_after_delete
  after delete on public.feedback_likes
  for each row execute procedure public.sync_feedback_likes_count();

create or replace view public.projects_with_feedback_count
with (security_invoker = true)
as
select
  p.id,
  p.creator_id,
  p.title,
  p.creator_name,
  p.category,
  p.description,
  p.image_url,
  p.created_at,
  p.is_published,
  count(f.id) filter (where f.is_public)::integer as feedback_count
from public.projects p
left join public.feedbacks f on f.project_id = p.id
group by p.id;

grant usage on schema public to anon, authenticated;
grant select on public.profiles, public.projects, public.feedbacks,
  public.feedback_likes, public.projects_with_feedback_count to anon, authenticated;
grant insert on public.feedbacks to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update, delete on public.projects to authenticated;
grant update, delete on public.feedbacks to authenticated;
grant insert, delete on public.feedback_likes to authenticated;

commit;
