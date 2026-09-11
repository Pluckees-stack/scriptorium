-- ============================================================================
-- 062_tournament_points_limit.sql
--
-- A tournament can now declare a max army points value (e.g. 2000pts).
-- Purely informational at the DB layer -- index.html uses it to flag a
-- submitted muster list that's over, and to auto-check an entrant in the
-- Entrants picker only once they have a list at or under it. Under is fine;
-- over is invalid. null = no limit enforced (any list is treated as fine).
--
-- Idempotent: safe to re-run. Run after 061.
-- ============================================================================

alter table tournaments add column if not exists points_limit integer;
comment on column tournaments.points_limit is 'Max muster list points total for this tournament, e.g. 2000 -- at or under is valid, over is not. null = no limit enforced. index.html-only validation -- flags an over-limit list, doesn''t block logging games.';
