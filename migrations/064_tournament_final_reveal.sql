-- ============================================================================
-- 064_tournament_final_reveal.sql
--
-- Lets an organiser hold back a tournament's final-round result/standings
-- from players until they're ready to reveal it -- e.g. an in-person prize
-- ceremony, where the organiser wants to do something dramatic before
-- everyone finds out who won. Every tournament's final round works this way
-- automatically; there's no per-tournament opt-out.
--
-- tournaments.final_results_revealed_at  null = the last round's own result
--   (and the standings/bracket outcome it decides) is withheld from players
--   -- UI-level only (index.html), not RLS: this is a "don't spoil it"
--   feature for an honest room, not a security boundary. The organiser
--   always sees everything in Tournament Admin regardless, and sets this
--   from there once they're ready.
--
-- Idempotent: safe to re-run. Run after 063.
-- ============================================================================

alter table tournaments add column if not exists final_results_revealed_at timestamptz;
comment on column tournaments.final_results_revealed_at is 'null = the final round''s result/standings are hidden from players (UI-level only, index.html) until the organiser reveals them from Tournament Admin. Every tournament works this way automatically.';
