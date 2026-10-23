-- ============================================================================
-- 105_manual_game_breakdowns.sql
--
-- The organiser's "Add a battle" enters a head-to-head battle's score on
-- the same Victory points card players fill in at the end of a battle
-- (Grant, 23 Oct: every result form the same). admin_log_manual_game (068)
-- only kept each player's total; this keeps their breakdown too, as
-- log_game_with_xp has since 099: player_breakdown / opponent_breakdown,
-- [{key, label, vp, detail?, entries?}], from each participant's
-- 'breakdown'. So a battle added by hand opens in the amend and edit forms
-- just as it was entered.
--
-- index.html works before this is run: the breakdowns it sends are ignored
-- and only the totals are kept, as before.
--
-- Same function as 068 otherwise. Run after 099. Idempotent: safe to re-run.
--
-- To undo: re-run 068_admin_manual_game.sql.
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
      player_vp, opponent_vp, player_breakdown, opponent_breakdown,
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
      nullif(v_a -> 'breakdown', 'null'::jsonb),
      nullif(v_b -> 'breakdown', 'null'::jsonb),
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
        campaign_points, player_vp, player_breakdown, scenario, mission_id, phase_id, played_on, notes,
        confirmation_status, confirmed_at
      ) values (
        p_campaign_id,
        (v_entry ->> 'player_id')::uuid,
        null,
        coalesce(v_label, 'Multi-player game'),
        (v_entry ->> 'result')::game_result,
        coalesce((v_entry ->> 'campaign_points')::integer, 0),
        coalesce((v_entry ->> 'vp')::integer, 0),
        nullif(v_entry -> 'breakdown', 'null'::jsonb),
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

comment on function admin_log_manual_game(uuid, jsonb) is 'Organiser-only: records a battle nobody logged through Game View. 2 players = one linked row; 1 or 3+ = one row per player against a freeform label (see game_credits, migrations/050, for why that credits each player exactly once). Each participant''s breakdown (their VP element by element, with what was entered) is kept as on a logged battle (105). Written as confirmed, with no unit XP, and audit-logged per row.';

revoke all on function admin_log_manual_game(uuid, jsonb) from public;
grant execute on function admin_log_manual_game(uuid, jsonb) to authenticated;
