begin;

create table if not exists public.app_announcements (
    id uuid primary key default gen_random_uuid(),
    kind text not null check (kind in ('news', 'update', 'maintenance')),
    title text not null check (char_length(title) between 1 and 120),
    message text not null check (char_length(message) between 1 and 4000),
    is_published boolean not null default false,
    published_at timestamptz not null default now(),
    expires_at timestamptz,
    created_at timestamptz not null default now(),
    check (expires_at is null or expires_at > published_at)
);

create index if not exists app_announcements_published_at_idx
    on public.app_announcements (published_at desc)
    where is_published = true;

alter table public.app_announcements enable row level security;

drop policy if exists "Public can read active announcements"
    on public.app_announcements;

create policy "Public can read active announcements"
    on public.app_announcements
    for select
    to anon, authenticated
    using (
        is_published = true
        and published_at <= now()
        and (expires_at is null or expires_at > now())
    );

revoke all on table public.app_announcements from anon, authenticated;
grant select on table public.app_announcements to anon, authenticated;
grant all on table public.app_announcements to service_role;

comment on table public.app_announcements is
    'Operator-authored news and release notices. Client roles have read-only access to active rows.';

commit;
