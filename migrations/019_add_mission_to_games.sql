-- ============================================================================
-- 019_add_mission_to_games.sql
--
-- Records which mission was played on a logged battle -- selection only,
-- not wired into scoring yet (applying a mission's own XP/glory reward and
-- objectives to the VP tally is separate future work, once the
-- mission-objectives model itself has bedded in from 018).
--
-- mission_id is a proper FK for future joins back to the full mission
-- record. games.scenario already existed (added whenever games was first
-- created, referenced but never populated by any UI until now) and becomes
-- a name snapshot taken at logging time -- same twin-column pattern as
-- opponent_id/opponent_name: a stable historical label even if the mission
-- is later renamed or deleted (ON DELETE SET NULL on mission_id, but
-- scenario keeps the name regardless).
--
-- log_game_with_xp is re-created (014's exact body, +mission_id in the
-- insert) rather than a fresh ALTER FUNCTION, matching how this function is
-- already handled -- see 014_rewrite_xp_functions.sql.
--
-- Idempotent: safe to re-run. Run after 018 (needs missions.random_length
-- etc. to exist so the client can display what it's referencing, though
-- this file itself doesn't touch those columns).
-- ============================================================================

alter table games add column if not exists mission_id uuid references missions(id) on delete set null;

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

  insert into games (
    campaign_id, player_id, opponent_id, opponent_name, result, glory_points,
    scenario, mission_id, trait_objective_id, trait_objective_met, played_on, notes,
    opponent_unit_outcomes, kill_credits
  )
  values (
    v_campaign_id,
    auth.uid(),
    nullif(p_game->>'opponent_id', '')::uuid,
    nullif(p_game->>'opponent_name', ''),
    (p_game->>'result')::game_result,
    coalesce((p_game->>'glory_points')::integer, 0),
    nullif(p_game->>'scenario', ''),
    nullif(p_game->>'mission_id', '')::uuid,
    nullif(p_game->>'trait_objective_id', '')::bigint,
    coalesce((p_game->>'trait_objective_met')::boolean, false),
    coalesce(nullif(p_game->>'played_on', '')::date, current_date),
    nullif(p_game->>'notes', ''),
    case when jsonb_typeof(p_game->'opponent_unit_outcomes') = 'array'
         then p_game->'opponent_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'kill_credits') = 'array'
         then p_game->'kill_credits' else null end
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
