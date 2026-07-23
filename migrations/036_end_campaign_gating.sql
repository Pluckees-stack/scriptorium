-- ============================================================================
-- 036_end_campaign_gating.sql
--
-- "Archive campaign" is being relabelled "End campaign" in the UI, and
-- Grant wants it to actually mean something rather than just a cosmetic
-- status flag: while ended, no new players can join and no new battles can
-- be logged. Existing data stays fully intact and readable, and an
-- organiser can flip it back to active at any time (unchanged from before).
--
-- Deliberately NOT gated here: organiser game-log overrides (migrations/028,
-- admin_delete_game/direct games update-in-place) and admin_audit_log writes
-- -- an organiser should still be able to fix a mis-entered historical
-- result after the campaign has wrapped up. Only *new* player-submitted
-- battles and *new* sign-ups are blocked.
--
-- Idempotent: safe to re-run. Run after 025 (campaign_members join policy
-- this replaces) and 035 (log_game_with_xp version this replaces).
-- ============================================================================

drop policy if exists "users can join a campaign as a player" on campaign_members;
create policy "users can join a campaign as a player" on campaign_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'player'
    and alliance_id is null
    and exists (select 1 from campaigns c where c.id = campaign_id and c.status = 'active')
  );

create or replace function log_game_with_xp(p_game jsonb)
returns bigint
language plpgsql
security invoker
as $function$
declare
  new_game_id bigint;
  credit jsonb;
  v_campaign_id uuid;
begin
  v_campaign_id := nullif(p_game->>'campaign_id', '')::uuid;

  if v_campaign_id is null then
    raise exception 'campaign_id is required to log a battle.';
  end if;

  if not is_campaign_member(v_campaign_id) then
    raise exception 'You are not a member of that campaign.';
  end if;

  if exists (select 1 from campaigns c where c.id = v_campaign_id and c.status = 'archived') then
    raise exception 'This campaign has ended and is no longer accepting new battles.';
  end if;

  insert into games (
    campaign_id, player_id, opponent_id, opponent_name, result, campaign_points,
    scenario, mission_id, phase_id, trait_objective_id, trait_objective_met, played_on, notes,
    opponent_unit_outcomes, kill_credits, models_removed, models_slain, models_fled,
    baggage_destroyed, baggage_survived, standards_captured
  )
  values (
    v_campaign_id,
    auth.uid(),
    nullif(p_game->>'opponent_id', '')::uuid,
    nullif(p_game->>'opponent_name', ''),
    (p_game->>'result')::game_result,
    coalesce((p_game->>'campaign_points')::integer, 0),
    nullif(p_game->>'scenario', ''),
    nullif(p_game->>'mission_id', '')::uuid,
    nullif(p_game->>'phase_id', '')::uuid,
    nullif(p_game->>'trait_objective_id', '')::bigint,
    coalesce((p_game->>'trait_objective_met')::boolean, false),
    coalesce(nullif(p_game->>'played_on', '')::date, current_date),
    nullif(p_game->>'notes', ''),
    case when jsonb_typeof(p_game->'opponent_unit_outcomes') = 'array'
         then p_game->'opponent_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'kill_credits') = 'array'
         then p_game->'kill_credits' else null end,
    coalesce((p_game->>'models_removed')::integer, 0),
    coalesce((p_game->>'models_slain')::integer, 0),
    coalesce((p_game->>'models_fled')::integer, 0),
    coalesce((p_game->>'baggage_destroyed')::boolean, false),
    coalesce((p_game->>'baggage_survived')::boolean, false),
    coalesce((p_game->>'standards_captured')::integer, 0)
  )
  returning id into new_game_id;

  -- 1 XP per credited kill, applied to the logger's own units. Row level
  -- security means an update against anyone else's unit simply matches
  -- nothing -- it cannot award XP across players.
  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_game->'kill_credits') = 'array'
           then p_game->'kill_credits' else '[]'::jsonb end)
  loop
    update units
       set experience = experience + coalesce((credit->>'amount')::integer, 0),
           updated_at = now()
     where id = (credit->>'unitId')::bigint;
  end loop;

  return new_game_id;
end;
$function$;
