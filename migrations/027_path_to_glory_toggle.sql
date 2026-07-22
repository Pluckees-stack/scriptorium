-- ============================================================================
-- 027_path_to_glory_toggle.sql
--
-- campaigns.path_to_glory_enabled -- organiser on/off switch for the Path to
-- Glory mechanic (XP, Veteran Abilities/Seasoned Commander, Battlefield
-- Losses/Death & Dishonour). Same shape as narrative_enabled
-- (026_narrative_updates.sql), but defaults to true: unlike narrative
-- updates (a brand new, opt-in feature), Path to Glory already exists and
-- every campaign currently uses it, so no existing campaign should silently
-- lose functionality when this migration runs.
--
-- Existing unit_advances/experience/status data is untouched either way --
-- turning this off just hides the UI, it doesn't delete anything, so it can
-- be safely toggled back on later.
--
-- No RLS change needed -- same reasoning as 026: 010_rls_policies_all_tables.sql's
-- "organisers and admins update their campaign" policy is row-level, not
-- column-restricted.
--
-- Idempotent: safe to re-run. Run after 026.
-- ============================================================================

alter table campaigns add column if not exists path_to_glory_enabled boolean not null default true;

comment on column campaigns.path_to_glory_enabled is 'Organiser toggle -- shows/hides the Path to Glory mechanic (XP, veteran/Seasoned Commander abilities, Battlefield Losses) for players. Defaults true: existing campaigns keep using it unless an organiser turns it off. Existing unit_advances/experience/status data is preserved when off.';
