-- ============================================================================
-- 065_unit_archived_flag.sql
--
-- Lets a unit be retired/archived without deleting it -- the row and its
-- XP/kill/wound history stay forever (unit_advances.unit_id and every
-- games.kill_credits/opponent_kill_credits jsonb reference to it keep
-- resolving), it just stops being offered as a live pick in Game View. Set
-- either directly by the player (a small "Archive this unit" toggle) or via
-- roster-reconciliation on a merge-import when a unit doesn't appear in the
-- new file and the player confirms it's genuinely gone.
--
-- No RLS change needed -- "players manage their own units" already covers
-- UPDATE on any column of an owned, campaign-scoped unit row (same
-- precedent as migrations/017's nickname column).
--
-- Idempotent: safe to re-run. Run after 064.
-- ============================================================================

alter table units add column if not exists archived_at timestamptz;
comment on column units.archived_at is 'null = in normal use. Set when a player marks a unit retired/no-longer-fielded (directly, or via roster-reconciliation on merge-import) -- the row and its XP/kill history are kept forever, it just stops being offered as a live pick.';
