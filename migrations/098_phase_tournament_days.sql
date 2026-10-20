-- ============================================================================
-- 098_phase_tournament_days.sql
--
-- A campaign or league can hold a one-day tournament as one of its phases
-- (or seasons). Rather than squeezing pairings into a phase, the phase gets
-- a tournament of its own, run in the same tournament editor a tournament
-- event uses: tournaments.phase_id says which phase it's the day for.
--
-- One tournament per phase. Deleting the phase keeps the tournament (and its
-- results), no longer tied to a phase. No new policies: organisers already
-- manage tournaments (039), and the column is theirs to set.
--
-- To undo:
--   drop index if exists tournaments_phase_id_key;
--   alter table tournaments drop column if exists phase_id;
-- ============================================================================

alter table tournaments add column if not exists phase_id uuid references campaign_phases(id) on delete set null;
create unique index if not exists tournaments_phase_id_key on tournaments (phase_id) where phase_id is not null;
comment on column tournaments.phase_id is 'The campaign phase this tournament is the tournament day for, if any (098).';
