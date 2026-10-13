-- ============================================================================
-- 074_remember_trusted_devices.sql
--
-- "Remember this device for 14 days" for two-factor login.
--
-- Admin powers need a two-factor session (072). Supabase only issues one
-- (aal2) after a code is checked, and it lasts until you sign out -- so the
-- code comes back on every new sign-in. This lets a player who has just
-- entered a code mark that browser as trusted for 14 days: the server hands
-- it a random device key (only its SHA-256 hash is stored), the app sends
-- it with every request as the x-device-token header, and the admin
-- helpers accept a valid, unexpired key in place of a fresh code. It still
-- only works for a signed-in user, i.e. alongside their password.
--
-- 1. trusted_devices: one row per remembered browser. Players can see and
--    delete their own rows ("Forget remembered devices"); rows are only
--    created through trust_this_device().
-- 2. trust_this_device(label): needs a real two-factor session (aal2).
--    Returns the device key once; it can't be read back.
-- 3. device_trusted(): true if this request carries a valid key for the
--    caller. index.html asks this at sign-in to decide whether to skip the
--    code prompt.
-- 4. is_campaign_organiser(), is_superadmin(), is_platform_admin() (072)
--    now accept aal2 OR a trusted device. The device lookup only runs for
--    someone who already has the role, so it costs nothing for players.
--
-- Not covered: the admin-reset-password Edge Function still needs a fresh
-- code (aal2). Resetting other people's passwords is rare and sensitive.
--
-- Run before merging the remember-device index.html (its sign-in calls
-- device_trusted()). Safe to run before: without a device key nothing
-- changes.
--
-- To undo: re-run 072_admin_requires_two_factor.sql, then
--   drop function if exists trust_this_device(text), device_trusted(), mfa_satisfied();
--   drop table if exists trusted_devices;
--
-- Idempotent: safe to re-run.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists trusted_devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  token_hash  text not null unique,
  label       text,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
);
create index if not exists trusted_devices_user_id_idx on trusted_devices (user_id);
alter table trusted_devices enable row level security;

drop policy if exists "players see their own trusted devices" on trusted_devices;
create policy "players see their own trusted devices" on trusted_devices
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "players forget their own trusted devices" on trusted_devices;
create policy "players forget their own trusted devices" on trusted_devices
  for delete to authenticated using (user_id = (select auth.uid()));

create or replace function trust_this_device(p_label text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'Enter a code from your authenticator app first.';
  end if;
  delete from trusted_devices where user_id = auth.uid() and expires_at <= now();
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into trusted_devices (user_id, token_hash, label, expires_at)
  values (auth.uid(), encode(extensions.digest(v_token, 'sha256'), 'hex'), left(p_label, 120), now() + interval '14 days');
  return v_token;
end;
$$;
revoke all on function trust_this_device(text) from public, anon;
grant execute on function trust_this_device(text) to authenticated;

create or replace function device_trusted()
returns boolean
language sql
security definer
stable
set search_path = public, extensions
as $$
  select exists (
    select 1 from trusted_devices
     where user_id = auth.uid()
       and expires_at > now()
       and token_hash = encode(extensions.digest(
             coalesce(nullif(current_setting('request.headers', true), '')::json ->> 'x-device-token', ''), 'sha256'), 'hex')
  );
$$;
revoke all on function device_trusted() from public, anon;
grant execute on function device_trusted() to authenticated;

create or replace function mfa_satisfied()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2' or device_trusted();
$$;
revoke all on function mfa_satisfied() from public, anon;
grant execute on function mfa_satisfied() to authenticated;

create or replace function is_campaign_organiser(p_campaign_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
           select 1 from campaign_members
            where campaign_id = p_campaign_id
              and user_id = auth.uid()
              and role = 'organiser'
         )
     and mfa_satisfied();
$$;

create or replace function is_superadmin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
           select 1 from players
            where id = auth.uid()
              and platform_role = 'superadmin'
         )
     and mfa_satisfied();
$$;

create or replace function is_platform_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
           select 1 from players
            where id = auth.uid()
              and platform_role in ('admin', 'superadmin')
         )
     and mfa_satisfied();
$$;
