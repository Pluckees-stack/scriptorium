-- ============================================================================
-- 009_rls_helper_functions.sql
--
-- Phase 2 (RLS rewrite), part 1.
--
-- Four SECURITY DEFINER helper functions used inside every policy that
-- follows in this phase. SECURITY DEFINER is required here, not just
-- convenient: is_campaign_member()/is_campaign_organiser() query
-- campaign_members, and campaign_members' own SELECT policy (see
-- 010_rls_policies_all_tables.sql) calls is_campaign_member() to decide
-- what a user can see in THAT same table. A SECURITY INVOKER version would
-- be subject to the caller's own RLS on the very table it's trying to
-- check membership against. SECURITY DEFINER sidesteps that by running as
-- the function owner, which bypasses RLS on tables it owns -- the normal
-- Postgres behaviour for table/function owners.
--
-- search_path is pinned on all four -- standard hardening for SECURITY
-- DEFINER functions, closing off the classic "attacker creates a
-- same-named object earlier in search_path" privilege-escalation trick.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function is_campaign_member(p_campaign_id uuid)
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
  );
$$;

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
  );
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
  );
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
  );
$$;

comment on function is_campaign_member(uuid) is 'True if the calling user is any kind of member (player or organiser) of the given campaign.';
comment on function is_campaign_organiser(uuid) is 'True if the calling user is specifically an organiser of the given campaign. Does not include platform admins/superadmins -- pair with is_platform_admin() where "organiser OR admin" is intended.';
comment on function is_superadmin() is 'True if the calling user holds the platform-wide superadmin rank.';
comment on function is_platform_admin() is 'True if the calling user holds the platform-wide admin OR superadmin rank. Most "admin can do X" policies should use this, not is_superadmin() alone.';

revoke all on function is_campaign_member(uuid) from public;
revoke all on function is_campaign_organiser(uuid) from public;
revoke all on function is_superadmin() from public;
revoke all on function is_platform_admin() from public;
grant execute on function is_campaign_member(uuid) to authenticated;
grant execute on function is_campaign_organiser(uuid) to authenticated;
grant execute on function is_superadmin() to authenticated;
grant execute on function is_platform_admin() to authenticated;
