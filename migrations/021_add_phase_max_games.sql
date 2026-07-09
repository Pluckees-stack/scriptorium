-- ============================================================================
-- 021_add_phase_max_games.sql
--
-- Adds campaign_phases.max_games -- an organiser-set cap (1-5, or NULL for
-- "Uncapped") on how many scoring games a player may submit within that
-- phase, independent of how many missions are in its pool. Lets a phase
-- offer a wider pool of mission choices than the number of games actually
-- required/allowed that round (e.g. a 5-mission pool with max_games = 3:
-- each player picks any 3 of the 5, the other 2 simply going unused for
-- them). Uncapped (NULL) reproduces 020's original behaviour exactly: the
-- only limit is the one-mission-per-phase-per-player index, i.e. a player
-- can work through the whole pool.
--
-- No new index for this cap -- unlike one_game_per_phase_mission_per_player
-- (a plain dedup, cheap as a unique index), "at most N rows per (phase_id,
-- player_id)" needs a count, which isn't expressible as a plain index/check
-- constraint. Enforced client-side only in Game view, consistent with how
-- this app already trusts client + RLS ownership for a friendly campaign
-- rather than layering in triggers for every gameplay rule.
--
-- Idempotent: safe to re-run. Run after 020.
-- ============================================================================

alter table campaign_phases add column if not exists max_games integer;

alter table campaign_phases drop constraint if exists campaign_phases_max_games_check;
alter table campaign_phases add constraint campaign_phases_max_games_check check (max_games is null or max_games > 0);

comment on column campaign_phases.max_games is 'Cap on scoring games a player may submit in this phase (NULL = uncapped, i.e. limited only by the mission pool itself). Set via a 1-5/Uncapped dropdown in Phase Admin, but not constrained to that range at the DB level.';
