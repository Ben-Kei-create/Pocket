begin;

-- Permanent free-plan capacity. Pro temporarily raises the effective limit to
-- 30, but these purchased slots remain available after Pro expires.
create table public.user_project_slot_entitlements (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  extra_slots smallint not null default 0 check (extra_slots between 0 and 2),
  updated_at timestamptz not null default now()
);

-- Immutable idempotency and spend audit for the two deterministic upgrades.
create table public.project_slot_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  slot_number smallint not null check (slot_number in (4, 5)),
  amount integer not null check (
    (slot_number = 4 and amount = 200)
    or (slot_number = 5 and amount = 400)
  ),
  balance_after integer not null check (balance_after >= 0),
  wallet_revision bigint not null check (wallet_revision > 0),
  created_at timestamptz not null default now(),
  unique (user_id, request_id),
  unique (user_id, slot_number)
);

create index project_slot_redemptions_user_created_idx
  on public.project_slot_redemptions (user_id, created_at desc);

alter table public.user_project_slot_entitlements enable row level security;
alter table public.project_slot_redemptions enable row level security;

create policy "Members read own project slot entitlement"
  on public.user_project_slot_entitlements for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Members read own project slot redemptions"
  on public.project_slot_redemptions for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.user_project_slot_entitlements,
  public.project_slot_redemptions to authenticated;
revoke insert, update, delete on public.user_project_slot_entitlements,
  public.project_slot_redemptions from anon, authenticated;

create function public.get_project_slot_status()
returns table (
  free_project_limit integer,
  extra_slots integer,
  next_slot_number integer,
  next_slot_cost integer,
  star_coin_balance integer,
  wallet_revision bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_extra_slots integer;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
     or not exists (
       select 1 from public.profiles as profile
       where profile.id = current_user_id
     ) then
    raise exception 'Registered creator authentication is required'
      using errcode = '42501';
  end if;

  select coalesce(entitlement.extra_slots, 0)::integer
  into current_extra_slots
  from (select 1) as seed
  left join public.user_project_slot_entitlements as entitlement
    on entitlement.user_id = current_user_id;

  return query
  select
    3 + current_extra_slots,
    current_extra_slots,
    case current_extra_slots when 0 then 4 when 1 then 5 else null end,
    case current_extra_slots when 0 then 200 when 1 then 400 else null end,
    coalesce(progress.star_coin_balance, 0),
    coalesce(progress.wallet_revision, 0)
  from (select 1) as seed
  left join public.member_reward_progress as progress
    on progress.user_id = current_user_id;
end;
$$;

revoke all on function public.get_project_slot_status()
  from public, anon;
grant execute on function public.get_project_slot_status()
  to authenticated;

create function public.redeem_project_slot(p_request_id uuid)
returns table (
  free_project_limit integer,
  extra_slots integer,
  next_slot_number integer,
  next_slot_cost integer,
  star_coin_balance integer,
  charged_coins integer,
  wallet_revision bigint,
  redeemed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_extra_slots integer;
  target_slot integer;
  target_cost integer;
  current_progress public.member_reward_progress%rowtype;
  previous_redemption public.project_slot_redemptions%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
     or not exists (
       select 1 from public.profiles as profile
       where profile.id = current_user_id
     ) then
    raise exception 'Registered creator authentication is required'
      using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request id is required' using errcode = '22023';
  end if;

  -- Pro already has 30 slots. Reject before touching the wallet so a stale or
  -- modified client cannot waste stars on a currently useless entitlement.
  if exists (
    select 1 from public.memberships as membership
    where membership.user_id = current_user_id
      and membership.status in ('active', 'trialing')
      and (
        membership.current_period_end is null
        or membership.current_period_end > now()
      )
  ) then
    raise exception 'Project slot redemption is unavailable during Poco Pro'
      using errcode = 'P0010';
  end if;

  -- Keep lock order stable for every operation that changes both capacity and
  -- the wallet. The creation trigger uses the first lock; all wallet spends
  -- use the second lock.
  perform pg_advisory_xact_lock(
    hashtextextended('poco-project-limit:' || current_user_id::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended('poco-star-wallet:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id;

  select redemption.* into previous_redemption
  from public.project_slot_redemptions as redemption
  where redemption.user_id = current_user_id
    and redemption.request_id = p_request_id;

  select coalesce(entitlement.extra_slots, 0)::integer
  into current_extra_slots
  from (select 1) as seed
  left join public.user_project_slot_entitlements as entitlement
    on entitlement.user_id = current_user_id;

  if previous_redemption.id is not null then
    return query select
      3 + current_extra_slots,
      current_extra_slots,
      case current_extra_slots when 0 then 4 when 1 then 5 else null end,
      case current_extra_slots when 0 then 200 when 1 then 400 else null end,
      current_progress.star_coin_balance,
      0,
      current_progress.wallet_revision,
      false;
    return;
  end if;

  if current_extra_slots >= 2 then
    return query select
      5, 2, null::integer, null::integer,
      current_progress.star_coin_balance, 0,
      current_progress.wallet_revision, false;
    return;
  end if;

  target_slot := 4 + current_extra_slots;
  target_cost := case target_slot when 4 then 200 else 400 end;

  if current_progress.star_coin_balance < target_cost then
    raise exception 'Insufficient star coins' using errcode = 'P0008';
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance - target_cost,
      wallet_revision = progress.wallet_revision + 1,
      updated_at = now()
  where progress.user_id = current_user_id
  returning progress.* into current_progress;

  insert into public.user_project_slot_entitlements (
    user_id, extra_slots, updated_at
  ) values (
    current_user_id, (current_extra_slots + 1)::smallint, now()
  )
  on conflict (user_id) do update
  set extra_slots = excluded.extra_slots,
      updated_at = excluded.updated_at;

  insert into public.project_slot_redemptions (
    user_id, request_id, slot_number, amount,
    balance_after, wallet_revision
  ) values (
    current_user_id, p_request_id, target_slot::smallint, target_cost,
    current_progress.star_coin_balance, current_progress.wallet_revision
  );

  current_extra_slots := current_extra_slots + 1;
  return query select
    3 + current_extra_slots,
    current_extra_slots,
    case current_extra_slots when 0 then 4 when 1 then 5 else null end,
    case current_extra_slots when 0 then 200 when 1 then 400 else null end,
    current_progress.star_coin_balance,
    target_cost,
    current_progress.wallet_revision,
    true;
end;
$$;

revoke all on function public.redeem_project_slot(uuid)
  from public, anon;
grant execute on function public.redeem_project_slot(uuid)
  to authenticated;

-- Replace the fixed free limit with the permanent 3 + purchased entitlement.
create or replace function public.enforce_project_creation_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  caller_role text := coalesce(auth.jwt() ->> 'role', '');
  project_limit integer;
  current_project_count integer;
begin
  -- Direct database maintenance has no request JWT. Public API callers must
  -- always pass the ownership and registered-account checks below.
  if caller_role not in ('anon', 'authenticated') then
    return new;
  end if;

  if current_user_id is null
     or new.creator_id is distinct from current_user_id
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered creator authentication is required'
      using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-project-limit:' || current_user_id::text, 0)
  );

  project_limit := case
    when exists (
      select 1
      from public.memberships as membership
      where membership.user_id = current_user_id
        and membership.status in ('active', 'trialing')
        and (
          membership.current_period_end is null
          or membership.current_period_end > now()
        )
    ) then 30
    else 3 + coalesce((
      select entitlement.extra_slots
      from public.user_project_slot_entitlements as entitlement
      where entitlement.user_id = current_user_id
    ), 0)
  end;

  select count(*)::integer
  into current_project_count
  from public.projects as project
  where project.creator_id = current_user_id
    and project.deleted_at is null;

  if current_project_count >= project_limit then
    raise exception 'Project creation limit reached' using errcode = 'P0004';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_project_creation_limit()
  from public, anon, authenticated;

comment on table public.user_project_slot_entitlements is
  'Permanent free-plan project slots purchased with deterministic star costs.';
comment on table public.project_slot_redemptions is
  'Immutable idempotency and wallet audit for free-plan project slot upgrades.';

commit;
