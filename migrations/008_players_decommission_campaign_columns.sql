-- ============================================================================
-- 008_players_decommission_campaign_columns.sql
--
-- Phase 1, part 8 of 8 -- run LAST.
--
-- This is the one genuinely destructive statement in Phase 1; everything in
-- 001-007 was additive. Since the brief confirmed the database holds only
-- test data, this is a straight DROP rather than a staged deprecation.
--
-- STOP -- one thing to check before running this:
--
-- Confirm every player was actually copied into campaign_members by
-- 001_campaigns_and_membership.sql. This should return zero rows:
--
--   select p.id, p.display_name
--     from players p
--    where not exists (
--      select 1 from campaign_members cm where cm.user_id = p.id
--    );
--
-- If it doesn't, 001 didn't run (or didn't cover every player) -- stop and
-- fix that first. Running this file anyway would silently lose whichever
-- players' faction_id/alliance_id/tier/onboarded weren't copied across,
-- with nothing left afterwards to recover them from.
--
-- The other precondition -- player_standings and alliance_standings both
-- referenced players.faction_id/alliance_id/tier, confirmed by pulling
-- their actual pg_get_viewdef() -- is handled by 007_rewrite_standings_views.sql,
-- which must run before this file. Run it first if you haven't. This file
-- deliberately does not use CASCADE, so if 007 hasn't run yet, this will
-- fail loudly ("cannot drop column ... other objects depend on it") rather
-- than silently breaking either view.
-- ============================================================================

alter table players
  drop column if exists faction_id,
  drop column if exists alliance_id,
  drop column if exists tier,
  drop column if exists onboarded;
