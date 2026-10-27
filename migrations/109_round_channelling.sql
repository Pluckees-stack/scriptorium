-- ============================================================================
-- 109_round_channelling.sql
--
-- Channelling the Winds of Magic for a whole tournament round (Grant,
-- 26 Oct 2026): the organiser switches it on before starting the round,
-- and every battle played from that round's pairings uses Channelling dice,
-- whatever its table's scenario says. Any other tournament can have it on
-- for every battle (tournaments.channelling, Edit details); WarCastle uses
-- only the round's.
--
-- index.html reads both with select('*'), so it works before this is
-- run (a round's switch shows the error; Edit details saves the rest).
-- Organisers already manage both tables (039's policies).
--
-- Idempotent: safe to re-run. Run after 039.
-- ============================================================================

alter table tournament_rounds add column if not exists channelling boolean not null default false;
alter table tournaments add column if not exists channelling boolean not null default false;
