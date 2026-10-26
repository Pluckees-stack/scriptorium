-- ============================================================================
-- 107_free_play_results.sql
--
-- Free play with no opponent on Scriptorium can now be tracked to the end:
-- the player marks how each of their own units ended (which scores the
-- opponent's Units destroyed) and enters their own objectives; with no
-- enemy army, their own Units destroyed and the rest of the opponent's side
-- aren't tracked. It's kept with the free play battle. free_play_log
-- (020) only held a date; these columns hold the rest, all optional, so a
-- free play battle with an opponent (or one logged before this) is still
-- just the marker.
--
-- Still never scored: free play doesn't touch campaign points, standings,
-- XP or Path to Glory. RLS is unchanged (020/045): the player inserts their
-- own rows, campaign members read them, the player deletes their own.
--
-- index.html works before this is run: it tries to save the score, and
-- if these columns aren't there yet, saves the marker alone as before.
--
-- Idempotent: safe to re-run. Run after 020.
--
-- To undo:
--   alter table free_play_log drop column if exists player_vp,
--     drop column if exists player_breakdown, drop column if exists opponent_vp,
--     drop column if exists opponent_breakdown, drop column if exists scenario,
--     drop column if exists notes;
-- ============================================================================

alter table free_play_log add column if not exists player_vp integer check (player_vp >= 0);
alter table free_play_log add column if not exists player_breakdown jsonb;
alter table free_play_log add column if not exists opponent_vp integer check (opponent_vp >= 0);
alter table free_play_log add column if not exists opponent_breakdown jsonb;
alter table free_play_log add column if not exists scenario text;
alter table free_play_log add column if not exists notes text;

comment on column free_play_log.player_vp is 'Free play with no opponent on Scriptorium, tracked to the end (107): the player''s own Victory Points. Never scored.';
comment on column free_play_log.player_breakdown is 'The player''s Victory Points element by element, as games.player_breakdown.';
comment on column free_play_log.opponent_breakdown is 'The opponent''s Units destroyed, from the player''s own units as marked (their whole army, each unit as it ended, in the units line''s entries).';
