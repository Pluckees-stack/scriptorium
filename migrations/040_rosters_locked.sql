-- ============================================================================
-- 040_rosters_locked.sql
--
-- Gates the Membership roster browser (added in the previous migration-less
-- change): nobody should be able to browse another player's muster list
-- until an organiser explicitly locks lists in for the round, matching
-- real tournament list-lock semantics (submissions close, then everyone's
-- list becomes visible at once) rather than lists leaking out piecemeal.
--
-- No new RLS policy needed -- campaigns UPDATE is already organiser/platform-
-- admin-only (the same policy narrative_enabled/path_to_glory_enabled already
-- go through, see 001/026/027), and SELECT is already open to campaign
-- members, so this column just rides along with the existing policies.
--
-- Idempotent: safe to re-run. Run after 039.
-- ============================================================================

alter table campaigns add column if not exists rosters_locked boolean not null default false;
