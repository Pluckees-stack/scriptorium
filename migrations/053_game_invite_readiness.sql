-- ============================================================================
-- 053_game_invite_readiness.sql
--
-- migrations/052 got B a say in whether a game starts at all (accept/
-- decline), but once accepted, B had no further part to play -- only A
-- went through spell-picking before Playing began. This adds a two-sided
-- "ready" handshake on top of the same invite row: both the sender and
-- the accepter mark themselves ready (after picking their own wizards'
-- spells, or immediately if they have none to pick) before the game
-- actually begins on A's side.
--
-- Plain nullable timestamps, not a new table -- this is the same
-- accepted invite row, just carrying two more facts about it. No RLS
-- changes needed: the existing "sender can update their own invite" /
-- "recipient can respond to their invite" policies (052) already permit
-- updating any column on a party's own row, not just status.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table game_invites add column if not exists from_ready_at timestamptz;
alter table game_invites add column if not exists to_ready_at timestamptz;

comment on column game_invites.from_ready_at is 'Set when the inviting player finishes picking spells (or has none to pick) and confirms ready to begin.';
comment on column game_invites.to_ready_at is 'Set when the accepting player finishes picking spells (or has none to pick) and confirms ready to begin.';
