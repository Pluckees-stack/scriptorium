-- ============================================================================
-- 031_platform_admin_games_read.sql
--
-- Extends games' SELECT policy to platform admins/superadmins, read-only.
-- 010_rls_policies_all_tables.sql deliberately left platform admins off
-- player-owned tables entirely ("admins don't get something organisers
-- themselves don't have") -- this narrows that, rather than reversing it:
-- organisers still get nothing extra here, and admins still can't write a
-- game that isn't theirs (INSERT/UPDATE/DELETE are untouched -- UPDATE for
-- organisers specifically comes from 028, scoped to their own campaign only,
-- not this policy). This is purely so the platform admin player list
-- (index.html) can show a real "last battle" date across campaigns instead
-- of nothing -- confirmed with Grant 2026-07-22 as a narrower ask than 028's
-- write override.
--
-- Idempotent: safe to re-run.
-- ============================================================================

drop policy if exists "campaign members can read games" on games;
create policy "campaign members can read games" on games
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());
