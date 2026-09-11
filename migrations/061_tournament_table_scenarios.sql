-- ============================================================================
-- 061_tournament_table_scenarios.sql
--
-- Lets a round use a different scenario per table instead of one scenario
-- for everyone. tournament_pairings.table_number has existed since
-- migration 039 but was never populated or shown anywhere -- this wires it
-- up: table_number is now assigned (1, 2, 3...) whenever a round's pairings
-- are generated (index.html), and a per-table round's actual scenario lives
-- on the pairing itself rather than the round.
--
--   tournament_rounds.per_table_scenarios  this round's mode. false (default,
--     unchanged behaviour): tournament_rounds.mission_id applies to every
--     table. true: each tournament_pairings.mission_id is what counts.
--   tournament_pairings.mission_id         the table's scenario, read only
--     when its round is in per-table mode.
--
-- No RLS changes -- both columns live on tables organisers already fully
-- manage (039).
--
-- tournaments.round_scenarios (060) keeps staging scenario plans before a
-- round's real rows/pairings exist, now in a richer shape (opaque jsonb,
-- entirely shaped by index.html, not enforced here):
--   { perTable: false, missionId } | { perTable: true, tableMissionIds: [...] }
-- A bare id-or-null entry (060's original shape) is still read as
-- { perTable: false, missionId: <that value> } wherever it's parsed.
--
-- Idempotent: safe to re-run. Run after 060.
-- ============================================================================

alter table tournament_rounds add column if not exists per_table_scenarios boolean not null default false;
comment on column tournament_rounds.per_table_scenarios is 'false: mission_id applies to every table in this round (default). true: each tournament_pairings.mission_id is that table''s scenario instead.';

alter table tournament_pairings add column if not exists mission_id uuid references missions(id) on delete set null;
comment on column tournament_pairings.mission_id is 'This table''s scenario, used only when tournament_rounds.per_table_scenarios is true for its round.';

comment on column tournaments.round_scenarios is 'Staged per-round scenario plan, set before a round''s real tournament_rounds/tournament_pairings rows exist -- index i = round i+1. Shape (061): {perTable:false, missionId} | {perTable:true, tableMissionIds:[...]}; a bare id-or-null is the original (060) same-scenario shape. Applied onto the real rows the moment they''re generated (Lock Entrants / Start Tournament / End Round / Regenerate, in index.html); left untouched by Unlock Entrants so the organiser''s work survives a re-lock.';
