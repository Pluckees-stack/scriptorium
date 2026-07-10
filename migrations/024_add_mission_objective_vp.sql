-- ============================================================================
-- 024_add_mission_objective_vp.sql
--
-- Adds missions.objective_vp jsonb -- per-mission overrides of the VP value
-- awarded for each common/secondary objective (King is Dead, Trophies of
-- War, Breaking the Enemy, Special Feature, Baggage Trains, Domination,
-- Strategic Locations). The client merges this over a DEFAULT_OBJECTIVE_VP
-- constant that mirrors the values that were previously hardcoded directly
-- into the End Game VP calculators, so a mission with objective_vp = '{}'
-- (every mission that predates this migration) scores identically to
-- before -- opt-in, same convention as campaign_phases' empty-config
-- default from 020/021.
--
-- Not stored as individual columns (one per objective) since this mirrors
-- common_objectives/secondary_objectives' existing jsonb shape rather than
-- introducing a new pattern for the same kind of per-mission config.
--
-- Idempotent: safe to re-run. Run after 023.
-- ============================================================================

alter table missions add column if not exists objective_vp jsonb not null default '{}';

comment on column missions.objective_vp is 'Per-mission overrides of DEFAULT_OBJECTIVE_VP (index.html) -- e.g. {"king-is-dead": 150}. Missing keys fall back to the default value. Saved as a full snapshot by the Mission Admin form, not a sparse diff, so a mission''s scoring stays frozen even if the defaults change later.';
