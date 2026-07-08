-- ============================================================================
-- 002_platform_admin_tier.sql
--
-- Phase 1, part 2 of 7.
--
-- Adds a platform-wide "admin" tier below superadmin. Confirmed shape (see
-- conversation, not guessed):
--   - Platform-wide, not per-campaign: an admin can act on ANY campaign, not
--     just ones they personally run. It's an account rank, like
--     superadmin -- not a campaign_members grant, so no change needed to
--     that table. An admin can also separately hold an ordinary
--     campaign_members row with role = 'organiser' for specific campaigns
--     (nothing stops that), but most organisers will just be organisers,
--     not admins -- the two are independent.
--   - Admins can assign/change the 'organiser' role in campaign_members for
--     any campaign, and can create/edit missions and trait_objectives at
--     BOTH the official (campaign_id NULL) and campaign-custom level, for
--     any campaign -- all Phase 2 policy work, nothing to do here except
--     give Phase 2 a column to check.
--   - Minting new admins is superadmin-only. An admin cannot promote anyone
--     (including themselves) to admin or superadmin.
--
-- This replaces the `players.is_superadmin` boolean added in
-- 001_campaigns_and_membership.sql with a single ranked column,
-- `platform_role`, rather than adding a second overlapping boolean --
-- "is_admin AND is_superadmin" style combinations aren't meaningful here,
-- there's just a rank: player < admin < superadmin.
--
-- "Pair players" (mentioned alongside assigning organisers and setting up
-- missions/objectives) isn't addressed in this file -- nothing in the
-- current schema models tournament-style pairing/matchmaking, and it's not
-- clear yet whether that needs a new table (e.g. a round/bracket concept)
-- or is just an Admin Console UI convenience over the existing games table.
-- Deferred until that's scoped properly, rather than guessed at here.
--
-- Run after 001_campaigns_and_membership.sql. Idempotent: safe to re-run.
-- ============================================================================

alter table players add column if not exists platform_role text not null default 'player'
  check (platform_role in ('player', 'admin', 'superadmin'));

comment on column players.platform_role is 'Platform-wide rank: player < admin < superadmin. Admins can assign organisers and manage missions/objectives (official or campaign-custom) for ANY campaign; only a superadmin can create campaigns or promote someone to admin/superadmin. Campaign-level organiser status is separate -- see campaign_members.role.';

-- carry over whoever was already flagged in 001
update players set platform_role = 'superadmin' where is_superadmin = true;

-- same reasoning as the is_superadmin REVOKE in 001: the existing
-- owner-write policy on `players` is row-scoped, not column-scoped, so
-- without this a player could set their own platform_role to 'admin' (or
-- 'superadmin') via a raw API call. Dropping is_superadmin below removes
-- its own privilege grant automatically; this is the equivalent guard for
-- the column that replaces it.
revoke update (platform_role) on players from authenticated;

alter table players drop column if exists is_superadmin;
