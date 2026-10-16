-- ============================================================================
-- 082_scenario_terrain.sql
--
-- Random terrain for a scenario: missions.terrain says which terrain
-- generator the battle uses (the Wasteland or Shadowlands tables from
-- Arcane Journal: Dawn of the Storm Dragon), and whether the scenario uses
-- scattered terrain placement:
--   {"generator": "wasteland" | "shadowlands", "scattered": true | false}
-- Empty ({}) means players choose terrain as normal. In Game view players
-- roll each feature on the table, or pick it themselves.
--
-- Run before merging the terrain generator index.html.
--
-- To undo:
--   alter table missions drop column if exists terrain;
-- ============================================================================

alter table missions add column if not exists terrain jsonb not null default '{}'::jsonb;
