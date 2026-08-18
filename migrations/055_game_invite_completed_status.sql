-- ============================================================================
-- 055_game_invite_completed_status.sql
--
-- Adds 'completed' to game_invites.status (052). Needed so a player who
-- reloads/times out mid-game has something to rejoin: index.html can now
-- offer "Rejoin game in progress" for any of their own invites still
-- sitting at status = 'accepted' -- but without a terminal marker, an
-- invite that finished playing out days ago would look identical to one
-- still genuinely in progress, since none of the live-session columns
-- (052/053/054) are ever cleared afterward.
--
-- 'completed' is set once the submitter's result is actually logged
-- (commitLogGameAndReset, index.html) -- whether that happened via a live
-- mutual confirm/dispute or a bypass, the invite's coordinating job is
-- done at that point either way.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table game_invites drop constraint if exists game_invites_status_check;
alter table game_invites add constraint game_invites_status_check
  check (status in ('pending','accepted','declined','cancelled','completed'));
