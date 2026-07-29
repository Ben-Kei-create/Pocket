begin;

-- A monotonic revision makes wallet responses safe when multiple devices or
-- out-of-order network requests update the same balance.
alter table public.member_reward_progress
  add column if not exists wallet_revision bigint not null default 0;
alter table public.member_reward_progress
  add column if not exists lifetime_activity_coins integer not null default 0
    check (lifetime_activity_coins >= 0);

alter table public.star_coin_transactions
  add column if not exists base_amount integer;
update public.star_coin_transactions
set base_amount = amount
where base_amount is null;
alter table public.star_coin_transactions
  alter column base_amount set not null;
alter table public.star_coin_transactions
  drop constraint if exists star_coin_transactions_base_amount_check;
alter table public.star_coin_transactions
  add constraint star_coin_transactions_base_amount_check
  check (base_amount between 1 and 15);

update public.member_reward_progress as progress
set lifetime_activity_coins = earned.total
from (
  select transaction.user_id, coalesce(sum(transaction.amount), 0)::integer as total
  from public.star_coin_transactions as transaction
  where transaction.event_type in (
    'feedback_delivered',
    'companion_tap',
    'rare_companion_birth',
    'rare_companion_tap'
  )
  group by transaction.user_id
) as earned
where earned.user_id = progress.user_id
  and progress.lifetime_activity_coins = 0;

create table public.star_sku_catalog (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9_]{2,63}$'),
  item_type text not null check (
    item_type in ('bubble_color', 'project_background', 'profile_badge')
  ),
  title text not null check (char_length(title) between 1 and 40),
  summary text not null check (char_length(summary) between 1 and 120),
  price_coins integer not null check (price_coins between 1 and 10000),
  asset_name text check (asset_name is null or char_length(asset_name) between 1 and 100),
  appearance_value text check (
    appearance_value is null or appearance_value ~ '^#[0-9A-Fa-f]{6}$'
  ),
  requires_pro boolean not null default false,
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_owned_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.star_sku_catalog(id),
  acquired_via text not null default 'star_purchase' check (
    acquired_via in ('star_purchase', 'achievement', 'admin_grant')
  ),
  acquired_at timestamptz not null default now(),
  unique (user_id, item_id)
);

create table public.star_coin_spend_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  item_id text not null references public.star_sku_catalog(id),
  amount integer not null check (amount between 1 and 10000),
  balance_after integer not null check (balance_after >= 0),
  wallet_revision bigint not null check (wallet_revision > 0),
  created_at timestamptz not null default now(),
  unique (user_id, request_id),
  unique (user_id, item_id)
);

create table public.project_customizations (
  project_id uuid primary key references public.projects(id) on delete cascade,
  background_item_id text not null references public.star_sku_catalog(id),
  updated_at timestamptz not null default now()
);

create table public.project_badge_slots (
  project_id uuid not null references public.projects(id) on delete cascade,
  slot_index smallint not null check (slot_index between 0 and 2),
  item_id text not null references public.star_sku_catalog(id),
  equipped_at timestamptz not null default now(),
  primary key (project_id, slot_index),
  unique (project_id, item_id)
);

create index user_owned_items_user_acquired_idx
  on public.user_owned_items (user_id, acquired_at desc);
create index project_badge_slots_item_idx
  on public.project_badge_slots (item_id);

alter table public.star_sku_catalog enable row level security;
alter table public.user_owned_items enable row level security;
alter table public.star_coin_spend_transactions enable row level security;
alter table public.project_customizations enable row level security;
alter table public.project_badge_slots enable row level security;

create policy "Active star catalog is readable"
  on public.star_sku_catalog for select
  to anon, authenticated
  using (is_active);

create policy "Members read own purchased items"
  on public.user_owned_items for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Members read own star spending"
  on public.star_coin_spend_transactions for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Visible project customizations are readable"
  on public.project_customizations for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.projects as project
      where project.id = project_customizations.project_id
        and (
          (project.is_published and project.deleted_at is null)
          or project.creator_id = (select auth.uid())
        )
    )
  );

create policy "Visible project badge slots are readable"
  on public.project_badge_slots for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.projects as project
      where project.id = project_badge_slots.project_id
        and (
          (project.is_published and project.deleted_at is null)
          or project.creator_id = (select auth.uid())
        )
    )
  );

grant select on public.star_sku_catalog to anon, authenticated;
grant select on public.project_customizations, public.project_badge_slots
  to anon, authenticated;
grant select on public.user_owned_items, public.star_coin_spend_transactions
  to authenticated;
revoke insert, update, delete on public.star_sku_catalog
  from public, anon, authenticated;
revoke insert, update, delete on public.user_owned_items
  from public, anon, authenticated;
revoke insert, update, delete on public.star_coin_spend_transactions
  from public, anon, authenticated;
revoke insert, update, delete on public.project_customizations
  from public, anon, authenticated;
revoke insert, update, delete on public.project_badge_slots
  from public, anon, authenticated;

-- The first catalog is intentionally deterministic. Badge artwork can replace
-- the sf:* placeholders later without changing IDs, ownership, or QR links.
insert into public.star_sku_catalog (
  id, item_type, title, summary, price_coins,
  asset_name, appearance_value, is_active, sort_order
) values
  ('background_sakura', 'project_background', 'さくらミルク',
   'やさしい桜色で、ことばをふんわり包む背景です。', 80,
   null, '#FFF2F4', true, 10),
  ('background_lemon', 'project_background', 'レモンクリーム',
   'あたたかな光を感じる、淡い黄色の背景です。', 80,
   null, '#FFF9E8', true, 20),
  ('background_sky', 'project_background', 'ソーダスカイ',
   '晴れた空のように、ことばが軽やかに見える背景です。', 80,
   null, '#EEF8FF', true, 30),
  ('background_mint', 'project_background', 'ミスティミント',
   '静かで落ち着いた、淡いミント色の背景です。', 80,
   null, '#EFFAF5', true, 40),
  ('background_lavender', 'project_background', 'ライラックミスト',
   '少し特別な余韻を添える、淡い紫色の背景です。', 80,
   null, '#F5F0FF', true, 50),
  ('badge_first_light', 'profile_badge', 'はじめの灯り',
   '最初の一歩をそっと照らすバッジです。', 120,
   'sf:sparkles', null, true, 110),
  ('badge_word_bouquet', 'profile_badge', 'ことばの花束',
   '届けたことばを花束のように飾るバッジです。', 180,
   'sf:camera.macro', null, true, 120),
  ('badge_poco_heart', 'profile_badge', 'Pocoハート',
   '作品とことばを大切にする気持ちのバッジです。', 250,
   'sf:heart.fill', null, true, 130)
on conflict (id) do update set
  item_type = excluded.item_type,
  title = excluded.title,
  summary = excluded.summary,
  price_coins = excluded.price_coins,
  asset_name = excluded.asset_name,
  appearance_value = excluded.appearance_value,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = now();

create or replace function public.purchase_star_item(
  p_item_id text,
  p_request_id uuid
)
returns table (
  item_id text,
  star_coin_balance integer,
  charged_coins integer,
  wallet_revision bigint,
  purchased boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_item public.star_sku_catalog%rowtype;
  current_progress public.member_reward_progress%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request id is required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-star-wallet:' || current_user_id::text, 0)
  );

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select item.* into target_item
  from public.star_sku_catalog as item
  where item.id = p_item_id
    and item.is_active;

  if not found then
    raise exception 'Store item not found' using errcode = 'P0002';
  end if;

  if target_item.requires_pro and not exists (
    select 1 from public.memberships as membership
    where membership.user_id = current_user_id
      and membership.status in ('active', 'trialing')
      and (
        membership.current_period_end is null
        or membership.current_period_end > now()
      )
  ) then
    raise exception 'Poco Pro is required' using errcode = '42501';
  end if;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id
  for update;

  if exists (
    select 1 from public.user_owned_items as owned
    where owned.user_id = current_user_id
      and owned.item_id = p_item_id
  ) then
    return query select
      p_item_id, current_progress.star_coin_balance, 0,
      current_progress.wallet_revision, false;
    return;
  end if;

  if exists (
    select 1 from public.star_coin_spend_transactions as spend
    where spend.user_id = current_user_id
      and spend.request_id = p_request_id
      and spend.item_id <> p_item_id
  ) then
    raise exception 'Request id was already used' using errcode = '23505';
  end if;

  if current_progress.star_coin_balance < target_item.price_coins then
    raise exception 'Insufficient star coins' using errcode = 'P0008';
  end if;

  update public.member_reward_progress as progress
  set star_coin_balance = progress.star_coin_balance - target_item.price_coins,
      wallet_revision = progress.wallet_revision + 1,
      updated_at = now()
  where progress.user_id = current_user_id
  returning progress.* into current_progress;

  insert into public.star_coin_spend_transactions (
    user_id, request_id, item_id, amount, balance_after, wallet_revision
  ) values (
    current_user_id, p_request_id, p_item_id, target_item.price_coins,
    current_progress.star_coin_balance, current_progress.wallet_revision
  );

  insert into public.user_owned_items (user_id, item_id)
  values (current_user_id, p_item_id);

  return query select
    p_item_id, current_progress.star_coin_balance, target_item.price_coins,
    current_progress.wallet_revision, true;
end;
$$;

revoke all on function public.purchase_star_item(text, uuid)
  from public, anon;
grant execute on function public.purchase_star_item(text, uuid)
  to authenticated;

create or replace function public.equip_project_background(
  p_project_id uuid,
  p_item_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
     or not exists (
       select 1 from public.projects as project
       where project.id = p_project_id
         and project.creator_id = current_user_id
         and project.deleted_at is null
     ) then
    raise exception 'Project owner is required' using errcode = '42501';
  end if;

  if p_item_id is null then
    delete from public.project_customizations
    where project_id = p_project_id;
    return;
  end if;

  if not exists (
    select 1
    from public.user_owned_items as owned
    join public.star_sku_catalog as item on item.id = owned.item_id
    where owned.user_id = current_user_id
      and owned.item_id = p_item_id
      and item.item_type = 'project_background'
      and item.is_active
  ) then
    raise exception 'Owned background is required' using errcode = '42501';
  end if;

  insert into public.project_customizations (
    project_id, background_item_id, updated_at
  ) values (
    p_project_id, p_item_id, now()
  ) on conflict (project_id) do update set
    background_item_id = excluded.background_item_id,
    updated_at = now();
end;
$$;

revoke all on function public.equip_project_background(uuid, text)
  from public, anon;
grant execute on function public.equip_project_background(uuid, text)
  to authenticated;

create or replace function public.equip_project_badge(
  p_project_id uuid,
  p_slot_index smallint,
  p_item_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if p_slot_index not between 0 and 2 then
    raise exception 'Badge slot must be between 0 and 2' using errcode = '22023';
  end if;

  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true)
     or not exists (
       select 1 from public.projects as project
       where project.id = p_project_id
         and project.creator_id = current_user_id
         and project.deleted_at is null
     ) then
    raise exception 'Project owner is required' using errcode = '42501';
  end if;

  delete from public.project_badge_slots
  where project_id = p_project_id
    and slot_index = p_slot_index;

  if p_item_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.user_owned_items as owned
    join public.star_sku_catalog as item on item.id = owned.item_id
    where owned.user_id = current_user_id
      and owned.item_id = p_item_id
      and item.item_type = 'profile_badge'
      and item.is_active
  ) then
    raise exception 'Owned badge is required' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.project_badge_slots as slot
    where slot.project_id = p_project_id
      and slot.item_id = p_item_id
  ) then
    raise exception 'Badge is already equipped' using errcode = 'P0009';
  end if;

  insert into public.project_badge_slots (project_id, slot_index, item_id)
  values (p_project_id, p_slot_index, p_item_id);
end;
$$;

revoke all on function public.equip_project_badge(uuid, smallint, text)
  from public, anon;
grant execute on function public.equip_project_badge(uuid, smallint, text)
  to authenticated;

commit;
