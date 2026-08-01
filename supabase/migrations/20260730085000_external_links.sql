-- Optional HTTPS links for projects and public registered profiles.
-- Existing row-level policies continue to govern who may edit each row.

alter table public.projects
  add column if not exists external_url text;

alter table public.projects
  drop constraint if exists projects_external_url_safe_check;
alter table public.projects
  add constraint projects_external_url_safe_check check (
    external_url is null
    or (
      char_length(external_url) between 1 and 2048
      and external_url ~* '^https://[^[:space:]/?#:]+([/?#]|$)'
      and external_url !~ '[[:space:]]'
    )
  );

alter table public.profiles
  add column if not exists social_links jsonb not null default '{}'::jsonb;

alter table public.profiles
  drop constraint if exists profiles_social_links_safe_check;
alter table public.profiles
  add constraint profiles_social_links_safe_check check (
    jsonb_typeof(social_links) = 'object'
    and (social_links - array['x', 'instagram', 'youtube', 'tiktok', 'website']::text[])
      = '{}'::jsonb
    and (
      social_links -> 'x' is null
      or (
        jsonb_typeof(social_links -> 'x') = 'string'
        and char_length(social_links ->> 'x') between 1 and 2048
        and social_links ->> 'x' !~ '[[:space:]]'
        and social_links ->> 'x' ~* '^https://([a-z0-9-]+\.)*(x\.com|twitter\.com)([/?#]|$)'
      )
    )
    and (
      social_links -> 'instagram' is null
      or (
        jsonb_typeof(social_links -> 'instagram') = 'string'
        and char_length(social_links ->> 'instagram') between 1 and 2048
        and social_links ->> 'instagram' !~ '[[:space:]]'
        and social_links ->> 'instagram' ~* '^https://([a-z0-9-]+\.)*instagram\.com([/?#]|$)'
      )
    )
    and (
      social_links -> 'youtube' is null
      or (
        jsonb_typeof(social_links -> 'youtube') = 'string'
        and char_length(social_links ->> 'youtube') between 1 and 2048
        and social_links ->> 'youtube' !~ '[[:space:]]'
        and social_links ->> 'youtube' ~* '^https://([a-z0-9-]+\.)*(youtube\.com|youtu\.be)([/?#]|$)'
      )
    )
    and (
      social_links -> 'tiktok' is null
      or (
        jsonb_typeof(social_links -> 'tiktok') = 'string'
        and char_length(social_links ->> 'tiktok') between 1 and 2048
        and social_links ->> 'tiktok' !~ '[[:space:]]'
        and social_links ->> 'tiktok' ~* '^https://([a-z0-9-]+\.)*tiktok\.com([/?#]|$)'
      )
    )
    and (
      social_links -> 'website' is null
      or (
        jsonb_typeof(social_links -> 'website') = 'string'
        and char_length(social_links ->> 'website') between 1 and 2048
        and social_links ->> 'website' !~ '[[:space:]]'
        and social_links ->> 'website' ~* '^https://[^[:space:]/?#:]+([/?#]|$)'
      )
    )
  );

comment on column public.projects.external_url is
  'Optional HTTPS page for the work, such as an official or sales page.';
comment on column public.profiles.social_links is
  'Bounded public HTTPS links keyed by supported profile service.';
