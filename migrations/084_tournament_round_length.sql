-- ============================================================================
-- 084_tournament_round_length.sql
--
-- How long each tournament round lasts, in minutes, for the round timer:
-- organisers set it in the tournament's Details step, and a running round
-- counts down from tournament_rounds.activated_at for the organiser and on
-- each player's tournament banner. Null means no timer.
--
-- No new policies: the existing "organisers manage tournaments" and
-- "members read tournaments" policies (039) already cover the whole row.
--
-- Run before merging the tournament builder index.html. Until it's run,
-- everything else works and the round length field just won't save.
--
-- To undo:
--   alter table tournaments drop column if exists round_minutes;
-- ============================================================================

alter table tournaments add column if not exists round_minutes integer
  check (round_minutes is null or round_minutes between 10 and 600);
