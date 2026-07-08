-- ============================================================================
-- 018_add_mission_scenario_fields.sql
--
-- Adds structured scenario fields to missions, backing the Mission Admin
-- form's new Scenario preset picker, Map selector, and Common/Secondary
-- objective checklists (the deployment maps and objectives themselves are
-- a fixed reference list in index.html, same treatment as FACTION_ACCENTS --
-- no new lookup table needed).
--
-- No new `map` column -- the existing `deployment_type` text column already
-- means exactly this (a named deployment layout); the client's Map <select>
-- just writes/reads that column instead of free text.
--
-- No RLS changes needed: missions' existing row-level policies
-- (010_rls_policies_all_tables.sql) already cover whatever columns exist on
-- the row, official or campaign-custom.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table missions add column if not exists random_length boolean not null default false;
alter table missions add column if not exists common_objectives text[] not null default array['king-is-dead','trophies-of-war','breaking-the-enemy']::text[];
alter table missions add column if not exists secondary_objectives jsonb not null default '[]'::jsonb;

comment on column missions.random_length is 'True if this scenario uses a randomly-determined game length instead of a fixed turn_limit (e.g. Chance Encounter). turn_limit is ignored/null when this is true.';
comment on column missions.common_objectives is 'Which of the fixed common-objective keys (king-is-dead, trophies-of-war, breaking-the-enemy) are active for this mission -- all three by default, toggleable per mission.';
comment on column missions.secondary_objectives is 'Array of {key, count?} for the fixed secondary-objective keys (baggage-trains, special-feature, domination, strategic-locations) active for this mission. strategic-locations carries a marker count.';
