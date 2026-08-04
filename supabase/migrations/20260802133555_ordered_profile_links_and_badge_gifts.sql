begin;

-- Profile links are an ordered list. Repeating the same service is allowed,
-- while every URL is still validated server-side.
update public.profiles as profile
set social_links = (
  select coalesce(
    jsonb_agg(
      jsonb_build_object('service', service.key, 'url', profile.social_links ->> service.key)
      order by service.position
    ),
    '[]'::jsonb
  )
  from (
    values
      ('x', 1),
      ('instagram', 2),
      ('youtube', 3),
      ('tiktok', 4),
      ('website', 5)
  ) as service(key, position)
  where profile.social_links ? service.key
)
where jsonb_typeof(profile.social_links) = 'object';

alter table public.profiles
  alter column social_links set default '[]'::jsonb;

create or replace function public.is_valid_profile_social_links(value jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    jsonb_typeof(value) = 'array'
    and jsonb_array_length(value) <= 10
    and not exists (
      select 1
      from jsonb_array_elements(value) as link(entry)
      where jsonb_typeof(link.entry) <> 'object'
        or (link.entry - array['service', 'url']::text[]) <> '{}'::jsonb
        or jsonb_typeof(link.entry -> 'service') <> 'string'
        or jsonb_typeof(link.entry -> 'url') <> 'string'
        or link.entry ->> 'service' not in ('x', 'instagram', 'youtube', 'tiktok', 'website')
        or char_length(link.entry ->> 'url') not between 1 and 2048
        or link.entry ->> 'url' ~ '[[:space:]]'
        or link.entry ->> 'url' !~* '^https://[^[:space:]/?#:]+([/?#]|$)'
        or (
          link.entry ->> 'service' = 'x'
          and link.entry ->> 'url' !~* '^https://([a-z0-9-]+\.)*(x\.com|twitter\.com)([/?#]|$)'
        )
        or (
          link.entry ->> 'service' = 'instagram'
          and link.entry ->> 'url' !~* '^https://([a-z0-9-]+\.)*instagram\.com([/?#]|$)'
        )
        or (
          link.entry ->> 'service' = 'youtube'
          and link.entry ->> 'url' !~* '^https://([a-z0-9-]+\.)*(youtube\.com|youtu\.be)([/?#]|$)'
        )
        or (
          link.entry ->> 'service' = 'tiktok'
          and link.entry ->> 'url' !~* '^https://([a-z0-9-]+\.)*tiktok\.com([/?#]|$)'
        )
    );
$$;

revoke all on function public.is_valid_profile_social_links(jsonb)
  from public;
grant execute on function public.is_valid_profile_social_links(jsonb)
  to anon, authenticated;

alter table public.profiles
  drop constraint if exists profiles_social_links_safe_check;
alter table public.profiles
  add constraint profiles_social_links_safe_check
  check (public.is_valid_profile_social_links(social_links));

create or replace function public.enforce_profile_social_link_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed_count integer := 5;
begin
  if exists (
    select 1
    from public.memberships as membership
    where membership.user_id = new.id
      and membership.status in ('active', 'trialing')
      and (
        membership.current_period_end is null
        or membership.current_period_end > now()
      )
  ) then
    allowed_count := 10;
  end if;

  if jsonb_array_length(new.social_links) > allowed_count then
    raise exception 'Profile link limit reached' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_profile_social_link_limit_trigger on public.profiles;
create trigger enforce_profile_social_link_limit_trigger
before insert or update of social_links on public.profiles
for each row execute function public.enforce_profile_social_link_limit();

revoke all on function public.enforce_profile_social_link_limit()
  from public, anon, authenticated;

comment on column public.profiles.social_links is
  'Ordered HTTPS profile links. Free accounts may store 5 and active Poco Pro accounts 10.';

-- A badge SKU can be purchased more than once. Backgrounds remain one-time
-- ownership items even though both use the same compact inventory table.
alter table public.user_owned_items
  add column if not exists quantity integer not null default 1;
alter table public.user_owned_items
  drop constraint if exists user_owned_items_quantity_check;
alter table public.user_owned_items
  add constraint user_owned_items_quantity_check
  check (quantity between 1 and 10000);

alter table public.user_owned_items
  drop constraint if exists user_owned_items_acquired_via_check;
alter table public.user_owned_items
  add constraint user_owned_items_acquired_via_check
  check (acquired_via in ('star_purchase', 'achievement', 'admin_grant', 'gift'));

alter table public.star_coin_spend_transactions
  drop constraint if exists star_coin_spend_transactions_user_id_item_id_key;
alter table public.project_badge_slots
  drop constraint if exists project_badge_slots_project_id_item_id_key;

drop function if exists public.purchase_star_item(text, uuid);
create function public.purchase_star_item(
  p_item_id text,
  p_request_id uuid
)
returns table (
  item_id text,
  star_coin_balance integer,
  charged_coins integer,
  wallet_revision bigint,
  owned_quantity integer,
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
  previous_spend public.star_coin_spend_transactions%rowtype;
  resulting_quantity integer := 0;
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

  select spend.* into previous_spend
  from public.star_coin_spend_transactions as spend
  where spend.user_id = current_user_id
    and spend.request_id = p_request_id;
  if found then
    if previous_spend.item_id <> p_item_id then
      raise exception 'Request id was already used' using errcode = '23505';
    end if;
    select coalesce(owned.quantity, 0) into resulting_quantity
    from (select 1) as seed
    left join public.user_owned_items as owned
      on owned.user_id = current_user_id and owned.item_id = p_item_id;
    return query select
      p_item_id, previous_spend.balance_after, 0,
      previous_spend.wallet_revision, resulting_quantity, false;
    return;
  end if;

  insert into public.member_reward_progress (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  select item.* into target_item
  from public.star_sku_catalog as item
  where item.id = p_item_id and item.is_active;
  if not found then
    raise exception 'Store item not found' using errcode = 'P0002';
  end if;

  if target_item.requires_pro and not exists (
    select 1 from public.memberships as membership
    where membership.user_id = current_user_id
      and membership.status in ('active', 'trialing')
      and (membership.current_period_end is null or membership.current_period_end > now())
  ) then
    raise exception 'Poco Pro is required' using errcode = '42501';
  end if;

  select progress.* into current_progress
  from public.member_reward_progress as progress
  where progress.user_id = current_user_id
  for update;

  select coalesce(owned.quantity, 0) into resulting_quantity
  from (select 1) as seed
  left join public.user_owned_items as owned
    on owned.user_id = current_user_id and owned.item_id = p_item_id;

  if target_item.item_type <> 'profile_badge' and resulting_quantity > 0 then
    return query select
      p_item_id, current_progress.star_coin_balance, 0,
      current_progress.wallet_revision, resulting_quantity, false;
    return;
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

  insert into public.user_owned_items (user_id, item_id, quantity)
  values (current_user_id, p_item_id, 1)
  on conflict (user_id, item_id) do update
  set quantity = public.user_owned_items.quantity + 1;

  select owned.quantity into resulting_quantity
  from public.user_owned_items as owned
  where owned.user_id = current_user_id and owned.item_id = p_item_id;

  return query select
    p_item_id, current_progress.star_coin_balance, target_item.price_coins,
    current_progress.wallet_revision, resulting_quantity, true;
end;
$$;

revoke all on function public.purchase_star_item(text, uuid)
  from public, anon;
grant execute on function public.purchase_star_item(text, uuid)
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
  owned_quantity integer := 0;
  equipped_quantity integer := 0;
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

  perform pg_advisory_xact_lock(
    hashtextextended('poco-badge-inventory:' || current_user_id::text, 0)
  );

  delete from public.project_badge_slots
  where project_id = p_project_id and slot_index = p_slot_index;
  if p_item_id is null then return; end if;

  select owned.quantity into owned_quantity
  from public.user_owned_items as owned
  join public.star_sku_catalog as item on item.id = owned.item_id
  where owned.user_id = current_user_id
    and owned.item_id = p_item_id
    and item.item_type = 'profile_badge'
    and item.is_active;
  if not found then
    raise exception 'Owned badge is required' using errcode = '42501';
  end if;

  select count(*)::integer into equipped_quantity
  from public.project_badge_slots as slot
  join public.projects as project on project.id = slot.project_id
  where project.creator_id = current_user_id and slot.item_id = p_item_id;
  if equipped_quantity >= owned_quantity then
    raise exception 'All owned badges are already equipped' using errcode = 'P0009';
  end if;

  insert into public.project_badge_slots (project_id, slot_index, item_id)
  values (p_project_id, p_slot_index, p_item_id);
end;
$$;

revoke all on function public.equip_project_badge(uuid, smallint, text)
  from public, anon;
grant execute on function public.equip_project_badge(uuid, smallint, text)
  to authenticated;

create table public.badge_gifts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.star_sku_catalog(id),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id),
  unique (sender_id, request_id)
);

create index badge_gifts_recipient_created_idx
  on public.badge_gifts (recipient_id, created_at desc);

alter table public.badge_gifts enable row level security;
create policy "Members read their sent or received badge gifts"
  on public.badge_gifts for select
  to authenticated
  using (
    sender_id = (select auth.uid())
    or recipient_id = (select auth.uid())
  );
grant select on public.badge_gifts to authenticated;
revoke all on public.badge_gifts from anon;
revoke insert, update, delete on public.badge_gifts
  from public, anon, authenticated;

create or replace function public.gift_profile_badge(
  p_recipient_id uuid,
  p_item_id text,
  p_request_id uuid
)
returns table (
  item_id text,
  sender_quantity integer,
  recipient_quantity integer,
  gifted boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  previous_gift public.badge_gifts%rowtype;
  sender_owned integer := 0;
  recipient_owned integer := 0;
  equipped_count integer := 0;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account is required' using errcode = '42501';
  end if;
  if p_request_id is null or p_recipient_id is null then
    raise exception 'Recipient and request id are required' using errcode = '22023';
  end if;
  if p_recipient_id = current_user_id then
    raise exception 'Cannot gift badge to self' using errcode = 'P0015';
  end if;
  if not exists (
    select 1 from auth.users as recipient
    where recipient.id = p_recipient_id
      and not coalesce(recipient.is_anonymous, false)
  ) then
    raise exception 'Registered recipient not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.star_sku_catalog as item
    where item.id = p_item_id and item.item_type = 'profile_badge' and item.is_active
  ) then
    raise exception 'Badge not found' using errcode = 'P0002';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('poco-badge-inventory:' || current_user_id::text, 0)
  );

  select gift.* into previous_gift
  from public.badge_gifts as gift
  where gift.sender_id = current_user_id and gift.request_id = p_request_id;
  if found then
    if previous_gift.recipient_id <> p_recipient_id or previous_gift.item_id <> p_item_id then
      raise exception 'Request id was already used' using errcode = '23505';
    end if;
    select coalesce(owned.quantity, 0) into sender_owned
    from (select 1) as seed left join public.user_owned_items as owned
      on owned.user_id = current_user_id and owned.item_id = p_item_id;
    select coalesce(owned.quantity, 0) into recipient_owned
    from (select 1) as seed left join public.user_owned_items as owned
      on owned.user_id = p_recipient_id and owned.item_id = p_item_id;
    return query select p_item_id, sender_owned, recipient_owned, false;
    return;
  end if;

  select coalesce(owned.quantity, 0) into sender_owned
  from (select 1) as seed left join public.user_owned_items as owned
    on owned.user_id = current_user_id and owned.item_id = p_item_id;
  select count(*)::integer into equipped_count
  from public.project_badge_slots as slot
  join public.projects as project on project.id = slot.project_id
  where project.creator_id = current_user_id and slot.item_id = p_item_id;
  if sender_owned <= equipped_count then
    raise exception 'Insufficient unequipped badge quantity' using errcode = 'P0014';
  end if;

  if sender_owned = 1 then
    delete from public.user_owned_items
    where user_id = current_user_id and item_id = p_item_id;
    sender_owned := 0;
  else
    update public.user_owned_items
    set quantity = quantity - 1
    where user_id = current_user_id and item_id = p_item_id
    returning quantity into sender_owned;
  end if;

  insert into public.user_owned_items (user_id, item_id, acquired_via, quantity)
  values (p_recipient_id, p_item_id, 'gift', 1)
  on conflict (user_id, item_id) do update
  set quantity = public.user_owned_items.quantity + 1
  returning quantity into recipient_owned;

  insert into public.badge_gifts (request_id, sender_id, recipient_id, item_id)
  values (p_request_id, current_user_id, p_recipient_id, p_item_id);

  return query select p_item_id, sender_owned, recipient_owned, true;
end;
$$;

revoke all on function public.gift_profile_badge(uuid, text, uuid)
  from public, anon;
grant execute on function public.gift_profile_badge(uuid, text, uuid)
  to authenticated;

commit;
