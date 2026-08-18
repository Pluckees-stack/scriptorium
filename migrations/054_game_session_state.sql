-- ============================================================================
-- 054_game_session_state.sql
--
-- Extends game_invites (052) again, same pattern as 053's from_ready_at/
-- to_ready_at: the accepted invite row keeps carrying more facts about
-- the live game it coordinates, rather than a new table.
--
-- Adds: who went first, a shared round counter + whose turn is active
-- (Strategic Locations can only be scored on your own turn), each side's
-- running Strategic Locations VP (kept separate so it's still correctly
-- attributed regardless of who ends up submitting), who's submitting the
-- result, and a staging area for that result so it can be reviewed and
-- confirmed/disputed by the other player BEFORE any games row exists --
-- see index.html's doLog()/gameStageReviewTally for why this is staged
-- rather than just calling log_game_with_xp directly and confirming
-- after the fact.
--
-- staged_result/staged_by are only ever written by the submitter;
-- staged_response/staged_dispute_reason only ever by the other player;
-- staged_game_id only by the submitter (once created). Kept as separate
-- scalar columns rather than one jsonb blob so neither side's write can
-- race the other's on the same key.
--
-- No RLS changes needed -- 052's existing "sender can update their own
-- invite" / "recipient can respond to their invite" policies already
-- permit updating any column on a party's own row.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table game_invites add column if not exists first_player_id uuid references players(id);
alter table game_invites add column if not exists current_round int not null default 1;
alter table game_invites add column if not exists active_slot text not null default 'first' check (active_slot in ('first','second'));
alter table game_invites add column if not exists strategic_vp_from_user numeric not null default 0;
alter table game_invites add column if not exists strategic_vp_to_user numeric not null default 0;
alter table game_invites add column if not exists submitter_id uuid references players(id);
alter table game_invites add column if not exists staged_result jsonb;
alter table game_invites add column if not exists staged_by uuid references players(id);
alter table game_invites add column if not exists staged_response text check (staged_response in ('confirmed','disputed'));
alter table game_invites add column if not exists staged_dispute_reason text;
alter table game_invites add column if not exists staged_game_id bigint references games(id);

comment on column game_invites.active_slot is 'Whose turn is active this round: ''first'' or ''second'', relative to first_player_id.';
comment on column game_invites.strategic_vp_from_user is 'Strategic Locations VP earned during from_user_id''s turns, kept separate from to_user_id''s so attribution is correct regardless of who submits.';
comment on column game_invites.staged_result is 'The exact payload doLog() would pass to log_game_with_xp, staged for the other player to review before any games row is created.';
