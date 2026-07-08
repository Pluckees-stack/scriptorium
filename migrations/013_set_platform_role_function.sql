-- ============================================================================
-- 013_set_platform_role_function.sql
--
-- Phase 2, part 5.
--
-- Gap found while writing the Phase 2 test plan, not requested directly:
-- 002_platform_admin_tier.sql correctly revoked UPDATE(platform_role) on
-- players from `authenticated`, closing off self-promotion -- but that
-- also means a superadmin has had no client-facing way to promote someone
-- to admin since then, only direct dashboard SQL access. The Admin Console
-- (Phase 5) needs an actual function to call for this, the same way
-- 011_campaign_membership_admin_functions.sql gave organisers/admins a
-- privileged path around the campaign_members column REVOKE.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function set_platform_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_superadmin() then
    raise exception 'Only a superadmin can change platform roles.';
  end if;
  if p_role not in ('player', 'admin', 'superadmin') then
    raise exception 'platform_role must be player, admin, or superadmin.';
  end if;

  update players set platform_role = p_role where id = p_user_id;

  if not found then
    raise exception 'That user does not exist.';
  end if;
end;
$$;

comment on function set_platform_role(uuid, text) is 'Superadmin-only. The sole path to changing a player''s platform_role now that the column is revoked from authenticated -- see 002_platform_admin_tier.sql.';

revoke all on function set_platform_role(uuid, text) from public;
grant execute on function set_platform_role(uuid, text) to authenticated;
