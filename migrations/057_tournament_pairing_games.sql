-- ============================================================================
-- 057_tournament_pairing_games.sql
--
-- Stage 2b of tournament-format support: wire a tournament pairing to the
-- real two-sided game the two players log for it, so the pairing's result
-- fills itself in once that game is confirmed -- instead of the organiser
-- re-typing every result (migration 039 deliberately decoupled the two;
-- that predated the two-sided confirm/XP system from 048-050, and a
-- *confirmed* game is now a solid enough record to derive a result from).
--
-- The organiser still starts and ends every round and can override any
-- result by hand (the Stage 2a lifecycle) -- this only feeds the pairing,
-- it never advances a round.
--
--   tournament_pairings.game_id        the confirmed game this pairing was
--                                      played out as (nullable; on delete
--                                      set null so deleting a game doesn't
--                                      orphan the pairing).
--   game_invites.tournament_pairing_id the pairing a Game View session is
--                                      being played for -- set when the
--                                      player starts the game from the
--                                      "play your pairing" CTA, read back
--                                      by whichever side submits the result.
--
-- link_tournament_pairing_game       called by the submitting player right
--                                    after log_game_with_xp: attaches the
--                                    new game to the pairing. SECURITY
--                                    DEFINER because tournament_pairings is
--                                    organiser-write under RLS (039) -- but
--                                    it only lets a player link a pairing
--                                    they're IN to a game they're ON, and
--                                    only when the two sides match.
--   sync_tournament_pairing_for_game  internal helper (revoked from
--                                    public, like apply_game_kill_credits
--                                    in 049): given a game id, find the
--                                    pairing pointing at it and set its
--                                    result from the game's outcome, unless
--                                    the round is already closed. Composed
--                                    into confirm_game_result and
--                                    admin_resolve_game (both re-pasted
--                                    verbatim from 049 plus one line), so
--                                    it runs on every path a game reaches
--                                    'confirmed' -- the staged Game View
--                                    flow and the battle-log confirm button
--                                    alike, no client change to either.
--
-- dispute_game_result is deliberately NOT touched: a disputed game must
-- leave the pairing open for the organiser to resolve.
--
-- Idempotent: safe to re-run. Run after 056.
-- ============================================================================

alter table tournament_pairings
  add column if not exists game_id bigint references games(id) on delete set null;

create index if not exists tournament_pairings_game_id_idx
  on tournament_pairings (game_id) where game_id is not null;

alter table game_invites
  add column if not exists tournament_pairing_id uuid references tournament_pairings(id) on delete set null;

comment on column tournament_pairings.game_id is 'The confirmed two-sided game (games.id) this pairing was played out as. Set via link_tournament_pairing_game; the pairing result is derived from this game''s outcome by sync_tournament_pairing_for_game once it confirms.';
comment on column game_invites.tournament_pairing_id is 'When a player starts a game from the tournament "play your pairing" CTA, the pairing it counts toward. Read by commitLogGameAndReset to link the resulting game.';

-- ---------------------------------------------------------------------------
-- sync_tournament_pairing_for_game -- internal; see file header
-- ---------------------------------------------------------------------------
create or replace function sync_tournament_pairing_for_game(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pairing_id   uuid;
  v_a            uuid;
  v_b            uuid;
  v_round_status text;
  v_result       game_result;
  v_status       text;
  v_player_id    uuid;
  v_opponent_id  uuid;
  v_mapped       text;
begin
  select tp.id, tp.player_a_id, tp.player_b_id, tr.status
    into v_pairing_id, v_a, v_b, v_round_status
    from tournament_pairings tp
    join tournament_rounds tr on tr.id = tp.round_id
   where tp.game_id = p_game_id;

  if v_pairing_id is null then return; end if;
  if v_round_status = 'completed' then return; end if;

  select result, confirmation_status, player_id, opponent_id
    into v_result, v_status, v_player_id, v_opponent_id
    from games where id = p_game_id;

  if v_status not in ('confirmed', 'legacy') then return; end if;

  -- defensive: the game's two sides must be the pairing's two players
  if not ((v_player_id = v_a and v_opponent_id = v_b)
       or (v_player_id = v_b and v_opponent_id = v_a)) then
    return;
  end if;

  if v_player_id = v_a then
    v_mapped := case v_result when 'win' then 'a_win' when 'loss' then 'b_win' else 'draw' end;
  else
    v_mapped := case v_result when 'win' then 'b_win' when 'loss' then 'a_win' else 'draw' end;
  end if;

  update tournament_pairings set result = v_mapped where id = v_pairing_id;
end;
$$;

revoke all on function sync_tournament_pairing_for_game(bigint) from public;

-- ---------------------------------------------------------------------------
-- link_tournament_pairing_game -- player-callable; see file header
-- ---------------------------------------------------------------------------
create or replace function link_tournament_pairing_game(p_pairing_id uuid, p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a          uuid;
  v_b          uuid;
  v_existing   bigint;
  v_player_id  uuid;
  v_opponent_id uuid;
begin
  if not exists (select 1 from tournament_pairings where id = p_pairing_id) then
    raise exception 'Pairing not found.';
  end if;
  select player_a_id, player_b_id, game_id into v_a, v_b, v_existing
    from tournament_pairings where id = p_pairing_id;

  if auth.uid() is distinct from v_a and auth.uid() is distinct from v_b then
    raise exception 'You are not in that pairing.';
  end if;

  select player_id, opponent_id into v_player_id, v_opponent_id
    from games where id = p_game_id;
  if v_player_id is null then raise exception 'Game not found.'; end if;

  if auth.uid() <> v_player_id and auth.uid() <> v_opponent_id then
    raise exception 'You are not on that game.';
  end if;

  if not ((v_player_id = v_a and v_opponent_id = v_b)
       or (v_player_id = v_b and v_opponent_id = v_a)) then
    raise exception 'That game is between different players than the pairing.';
  end if;

  if v_existing is not null then
    if v_existing = p_game_id then return; end if; -- idempotent
    raise exception 'That pairing is already linked to a different game.';
  end if;

  update tournament_pairings set game_id = p_game_id where id = p_pairing_id;
  perform sync_tournament_pairing_for_game(p_game_id);
end;
$$;

revoke all on function link_tournament_pairing_game(uuid, bigint) from public;
grant execute on function link_tournament_pairing_game(uuid, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- confirm_game_result -- verbatim from 049, plus the pairing sync
-- ---------------------------------------------------------------------------
create or replace function confirm_game_result(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_opponent_id uuid;
begin
  select confirmation_status, opponent_id into v_status, v_opponent_id from games where id = p_game_id;
  if v_opponent_id is null then raise exception 'Game not found.'; end if;
  if auth.uid() <> v_opponent_id then raise exception 'Only the opponent on this battle can confirm it.'; end if;
  if v_status <> 'pending' then raise exception 'This battle isn''t awaiting confirmation.'; end if;

  update games set confirmation_status = 'confirmed', confirmed_at = now() where id = p_game_id;
  perform apply_game_kill_credits(p_game_id);
  perform sync_tournament_pairing_for_game(p_game_id);
end;
$$;

revoke all on function confirm_game_result(bigint) from public;
grant execute on function confirm_game_result(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- admin_resolve_game -- verbatim from 049, plus the pairing sync on the
-- same transition into 'confirmed' that grants XP
-- ---------------------------------------------------------------------------
create or replace function admin_resolve_game(p_game_id bigint, p_overrides jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_old_status text;
  v_new_status text;
begin
  select campaign_id, confirmation_status into v_campaign_id, v_old_status from games where id = p_game_id;
  if v_campaign_id is null then raise exception 'Game not found.'; end if;
  if not (is_campaign_organiser(v_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can resolve this battle.';
  end if;

  update games set
    result = coalesce((p_overrides->>'result')::game_result, result),
    campaign_points = coalesce((p_overrides->>'campaign_points')::integer, campaign_points),
    opponent_campaign_points = coalesce((p_overrides->>'opponent_campaign_points')::integer, opponent_campaign_points),
    played_on = coalesce((p_overrides->>'played_on')::date, played_on),
    notes = case when p_overrides ? 'notes' then nullif(p_overrides->>'notes', '') else notes end,
    confirmation_status = coalesce(p_overrides->>'confirmation_status', confirmation_status)
  where id = p_game_id;

  select confirmation_status into v_new_status from games where id = p_game_id;

  -- Only grant XP on the transition INTO confirmed from a state that never
  -- had it applied -- calling this again on an already-confirmed/legacy
  -- game must never re-credit XP a second time.
  if v_new_status = 'confirmed' and v_old_status in ('pending', 'disputed') then
    perform apply_game_kill_credits(p_game_id);
  end if;

  -- Keep any linked tournament pairing in step whenever this leaves the
  -- game confirmed (covers an organiser flipping a disputed result to
  -- confirmed, or just re-confirming with a corrected result).
  if v_new_status in ('confirmed', 'legacy') then
    perform sync_tournament_pairing_for_game(p_game_id);
  end if;
end;
$$;

revoke all on function admin_resolve_game(bigint, jsonb) from public;
grant execute on function admin_resolve_game(bigint, jsonb) to authenticated;
