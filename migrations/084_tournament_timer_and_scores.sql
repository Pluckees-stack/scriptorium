-- ============================================================================
-- 084_tournament_timer_and_scores.sql
--
-- Tournament round timer, and organisers amending scores (as Best Coast
-- Pairings allows):
--
-- tournaments.round_minutes: how long each round lasts. A running round
--   counts down from tournament_rounds.activated_at for the organiser and on
--   each player's tournament banner. Null means no timer.
--
-- tournament_pairings.vp_a / vp_b: Victory Points the organiser entered for
--   player A / B, used in place of the VP from the pairing's logged battle
--   (or where no battle was logged). Null means use the battle's.
--
-- tournament_entrants.score_adjust / vp_adjust / adjust_note: a bonus or
--   penalty the organiser gives a player (e.g. -1 for a late list, +1 for
--   best painted), added to their tournament score and VP, with the reason
--   shown to players beside the standings.
--
-- No new policies: the existing "organisers manage ..." and "members read
-- ..." policies on these tables (039) already cover the new columns.
--
-- Run before merging the tournament builder index.html. Until it's run,
-- the rest of the tournament page works; saving a round length, VP or an
-- adjustment reports that it needs this migration.
--
-- To undo:
--   alter table tournaments drop column if exists round_minutes;
--   alter table tournament_pairings drop column if exists vp_a, drop column if exists vp_b;
--   alter table tournament_entrants drop column if exists score_adjust,
--     drop column if exists vp_adjust, drop column if exists adjust_note;
-- ============================================================================

alter table tournaments add column if not exists round_minutes integer
  check (round_minutes is null or round_minutes between 10 and 600);

alter table tournament_pairings add column if not exists vp_a integer check (vp_a is null or vp_a >= 0);
alter table tournament_pairings add column if not exists vp_b integer check (vp_b is null or vp_b >= 0);

alter table tournament_entrants add column if not exists score_adjust numeric(4,1) not null default 0;
alter table tournament_entrants add column if not exists vp_adjust integer not null default 0;
alter table tournament_entrants add column if not exists adjust_note text check (adjust_note is null or length(adjust_note) <= 200);
