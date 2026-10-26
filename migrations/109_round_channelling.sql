-- ============================================================================
-- 109_round_channelling.sql
--
-- Channelling the Winds of Magic for a whole tournament round (Grant,
-- 26 Oct 2026): the organiser switches it on before starting the round,
-- and every battle played from that round's pairings uses Channelling dice,
-- whatever its table's scenario says.
--
-- index.html reads the round with select('*'), so it works before this is
-- run (the switch's save fails with an error, nothing else changes).
-- Organisers already manage tournament_rounds (039's policies).
--
-- Idempotent: safe to re-run. Run after 039.
-- ============================================================================

alter table tournament_rounds add column if not exists channelling boolean not null default false;
