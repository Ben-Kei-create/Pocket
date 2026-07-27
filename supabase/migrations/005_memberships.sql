begin;

-- Membership entitlements are written only by a trusted StoreKit webhook or
-- service-role backend. App clients may read only their own current status.
create table if not exists public.memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'poco_member' check (tier in ('poco_member')),
  status text not null check (status in ('active', 'trialing', 'past_due', 'expired', 'revoked')),
  product_id text,
  original_transaction_id text unique,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.memberships enable row level security;

drop policy if exists "Users read their own membership" on public.memberships;
create policy "Users read their own membership"
  on public.memberships for select
  to authenticated
  using (user_id = (select auth.uid()));

grant select on public.memberships to authenticated;
revoke all on public.memberships from anon;
revoke insert, update, delete on public.memberships from authenticated;

-- A Like's owner can restore their pressed state after relaunch. Individual
-- like rows are not public; the aggregate likes_count remains on feedbacks.
drop policy if exists "Feedback likes are publicly readable" on public.feedback_likes;
drop policy if exists "Users read their own likes" on public.feedback_likes;
create policy "Users read their own likes"
  on public.feedback_likes for select
  to authenticated
  using (user_id = (select auth.uid()));

revoke select on public.feedback_likes from anon;
grant select on public.feedback_likes to authenticated;

-- Anonymous Auth users are Poco guests, not paid Poco members. They still get
-- a profile row so feedback ownership and one-like-per-user work with RLS.
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
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Pocoゲスト'),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

commit;
