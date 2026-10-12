-- ============================================================================
-- 072_admin_requires_two_factor.sql
--
-- Admin powers need two-factor login. Every organiser and platform-admin
-- permission in the database -- RLS policies and the admin RPCs alike --
-- goes through three helpers from 009: is_campaign_organiser(),
-- is_platform_admin() and is_superadmin(). Each now also requires the
-- caller's session to be aal2, which Supabase Auth only issues after a code
-- from an authenticator app has been checked (index.html's two-factor setup
-- in Account settings, and the code prompt at sign-in).
--
-- An organiser or admin without two-factor login keeps everything a normal
-- campaign member has; they just can't use admin powers until they set it
-- up. Nobody gets locked out: setting it up is open to every account.
--
-- RUN ONLY AFTER the two-factor index.html is live and you've set it up on
-- your own account (signed out and back in with a code) -- otherwise the
-- admin tools stop working for you too.
--
-- The admin-reset-password Edge Function checks players.platform_role
-- itself, so it carries its own aal2 check; redeploy it to pick that up.
--
-- To undo: re-run the three functions from 009_rls_helper_functions.sql.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function is_campaign_organiser(p_campaign_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (
       select 1 from campaign_members
        where campaign_id = p_campaign_id
          and user_id = auth.uid()
          and role = 'organiser'
     );
$$;

create or replace function is_superadmin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (
       select 1 from players
        where id = auth.uid()
          and platform_role = 'superadmin'
     );
$$;

create or replace function is_platform_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (
       select 1 from players
        where id = auth.uid()
          and platform_role in ('admin', 'superadmin')
     );
$$;
