-- ============================================================================
-- 060_tournament_round_scenarios_preset.sql
--
-- 059 gated round-scenario assignment behind "Lock entrants" (the step that
-- creates the tournament_rounds rows the scenario picker writes to). Grant
-- wants to plan scenarios the other way round -- set every round's scenario
-- first, then lock entrants and go -- so this lets the organiser stage them
-- on the tournament itself before any round row exists.
--
-- tournaments.round_scenarios is a plain jsonb array, index i = round i+1's
-- mission id (or null) -- purely client-side staging, handed off to the real
-- tournament_rounds.mission_id the moment those rows are created at Lock
-- Entrants (index.html). No RLS change: tournaments UPDATE is already
-- organiser-only (039).
--
-- Idempotent: safe to re-run. Run after 059.
-- ============================================================================

alter table tournaments add column if not exists round_scenarios jsonb not null default '[]'::jsonb;
comment on column tournaments.round_scenarios is 'Staged per-round scenario picks, set before entrants are locked -- index i = round i+1''s missions.id (or null). Copied onto each tournament_rounds.mission_id as those rows are created at Lock Entrants; left untouched by Unlock Entrants so the organiser''s work survives a re-lock.';
