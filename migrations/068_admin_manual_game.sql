-- ============================================================================
-- 068_admin_manual_game.sql
--
-- Lets an organiser record a battle that nobody logged through Game View --
-- a game that just never got entered, or a 3+ player game, which the
-- two-sided Game View flow can't represent at all. Every games row until now
-- came from log_game_with_xp (049), which hardcodes auth.uid() as the
-- player, so there was no way to enter a result on someone else's behalf.
--
-- Row shape depends on how many players are in it:
--   1 player   one row, opponent_id null, opponent_name = the label
--              (played someone outside the campaign).
--   2 players  one row linking both -- exactly like a normally-logged game,
--              so both sides are credited off the single row.
--   3+ players one row per player, opponent_id null, opponent_name = the
--              shared label. No invented head-to-heads: each player just
--              carries their own result and points.
--
-- That last shape works because of how game_credits (050) is defined: the
-- player side of a game is always credited, the opponent side only when
-- opponent_id is not null. So per-player rows credit each player exactly
-- once -- no double-counting, and standings need no changes.
--
-- Each participant carries their own victory points as well as their result
-- and campaign points -- organisers collect objective tallies off the
-- players, so that's worth keeping rather than throwing away. On a 3+ player
-- row opponent_vp stays 0: with no single opponent there's nothing for it to
-- mean.
--
-- Entries are written as 'confirmed' (an organiser entering it IS the
-- confirmation, and it's what makes the points count). No kill_credits or
-- unit outcomes are set, so no unit XP is granted -- correct, since a manual
-- entry carries no unit-level detail to grant it from.
--
-- Unlike log_game_with_xp this does NOT refuse an archived campaign: that
-- gate exists to stop players logging new battles, and back-filling a
-- finished season is exactly what this is for.
--
-- Each created row also gets an admin_audit_log entry -- the audit_games
-- trigger (029) only covers update/delete, and this function can create
-- campaign points out of nothing, so it needs a trail of its own (same
-- reasoning migrations/043 used for keeping an adjustments ledger).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function admin_log_manual_game(p_campaign_id uuid, p_game jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participants jsonb;
  v_count        integer;
  v_label        text;
  v_played_on    date;
  v_scenario     text;
  v_mission_id   uuid;
  v_phase_id     uuid;
  v_notes        text;
  v_entry        jsonb;
  v_player       uuid;
  v_a            jsonb;
  v_b            jsonb;
  v_game_id      bigint;
  v_created      integer := 0;
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can add a battle manually.';
  end if;

  v_participants := coalesce(p_game -> 'participants', '[]'::jsonb);
  if jsonb_typeof(v_participants) <> 'array' then
    raise exception 'participants must be an array.';
  end if;
  v_count := jsonb_array_length(v_participants);
  if v_count < 1 then
    raise exception 'Add at least one player to this battle.';
  end if;

  v_label      := nullif(btrim(coalesce(p_game ->> 'opponent_label', '')), '');
  v_played_on  := coalesce(nullif(p_game ->> 'played_on', '')::date, current_date);
  v_scenario   := nullif(p_game ->> 'scenario', '');
  v_mission_id := nullif(p_game ->> 'mission_id', '')::uuid;
  v_phase_id   := nullif(p_game ->> 'phase_id', '')::uuid;
  v_notes      := nullif(p_game ->> 'notes', '');

  -- Validate everything before writing anything, so a bad entry can't leave
  -- half a multi-player game behind.
  for v_entry in select value from jsonb_array_elements(v_participants) loop
    v_player := nullif(v_entry ->> 'player_id', '')::uuid;
    if v_player is null then
      raise exception 'Every entry needs a player.';
    end if;
    if not exists (
      select 1 from campaign_members m
       where m.campaign_id = p_campaign_id and m.user_id = v_player
    ) then
      raise exception 'One of those players is not a member of this campaign.';
    end if;
    if coalesce(v_entry ->> 'result', '') not in ('win', 'draw', 'loss') then
      raise exception 'Every entry needs a result of win, draw or loss.';
    end if;
  end loop;

  if v_count = 2 then
    v_a := v_participants -> 0;
    v_b := v_participants -> 1;
    if not (
      ((v_a ->> 'result') = 'win'  and (v_b ->> 'result') = 'loss') or
      ((v_a ->> 'result') = 'loss' and (v_b ->> 'result') = 'win')  or
      ((v_a ->> 'result') = 'draw' and (v_b ->> 'result') = 'draw')
    ) then
      raise exception 'Those two results don''t match up -- one player''s win has to be the other''s loss (or both a draw).';
    end if;
    if (v_a ->> 'player_id') = (v_b ->> 'player_id') then
      raise exception 'A player can''t fight themselves -- pick two different players.';
    end if;

    insert into games (
      campaign_id, player_id, opponent_id, result,
      campaign_points, opponent_campaign_points,
      player_vp, opponent_vp,
      scenario, mission_id, phase_id, played_on, notes,
      confirmation_status, confirmed_at
    ) values (
      p_campaign_id,
      (v_a ->> 'player_id')::uuid,
      (v_b ->> 'player_id')::uuid,
      (v_a ->> 'result')::game_result,
      coalesce((v_a ->> 'campaign_points')::integer, 0),
      coalesce((v_b ->> 'campaign_points')::integer, 0),
      coalesce((v_a ->> 'vp')::integer, 0),
      coalesce((v_b ->> 'vp')::integer, 0),
      v_scenario, v_mission_id, v_phase_id, v_played_on, v_notes,
      'confirmed', now()
    )
    returning id into v_game_id;

    insert into admin_audit_log (campaign_id, table_name, action, row_id, actor_id, new_data)
    select p_campaign_id, 'games', 'INSERT', v_game_id::text, auth.uid(), to_jsonb(g)
      from games g where g.id = v_game_id;

    v_created := 1;
  else
    for v_entry in select value from jsonb_array_elements(v_participants) loop
      -- opponent_vp stays 0 here: with no single opponent on the row there's
      -- nothing for it to mean. Each player's own score lives in player_vp.
      insert into games (
        campaign_id, player_id, opponent_id, opponent_name, result,
        campaign_points, player_vp, scenario, mission_id, phase_id, played_on, notes,
        confirmation_status, confirmed_at
      ) values (
        p_campaign_id,
        (v_entry ->> 'player_id')::uuid,
        null,
        coalesce(v_label, 'Multi-player game'),
        (v_entry ->> 'result')::game_result,
        coalesce((v_entry ->> 'campaign_points')::integer, 0),
        coalesce((v_entry ->> 'vp')::integer, 0),
        v_scenario, v_mission_id, v_phase_id, v_played_on, v_notes,
        'confirmed', now()
      )
      returning id into v_game_id;

      insert into admin_audit_log (campaign_id, table_name, action, row_id, actor_id, new_data)
      select p_campaign_id, 'games', 'INSERT', v_game_id::text, auth.uid(), to_jsonb(g)
        from games g where g.id = v_game_id;

      v_created := v_created + 1;
    end loop;
  end if;

  return v_created;
end;
$$;

comment on function admin_log_manual_game(uuid, jsonb) is 'Organiser-only: records a battle nobody logged through Game View. 2 players = one linked row; 1 or 3+ = one row per player against a freeform label (see game_credits, migrations/050, for why that credits each player exactly once). Written as confirmed, with no unit XP, and audit-logged per row.';

revoke all on function admin_log_manual_game(uuid, jsonb) from public;
grant execute on function admin_log_manual_game(uuid, jsonb) to authenticated;
