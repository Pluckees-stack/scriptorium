-- ============================================================================
-- 033_games_battle_stats.sql
--
-- Three new columns on games, captured at log time, for the Admin Overview's
-- campaign-wide "fun stats" (total models killed/fled, baggage carts
-- destroyed) -- confirmed with Grant 2026-07-22 that these only need to
-- count forward from whenever this ships, not backfill history that was
-- never captured.
--
-- Why these didn't already exist:
--   - baggage_destroyed/baggage_survived: manualObjectiveState.baggageDestroyed/
--     baggageSurvived (index.html) was only ever used to compute that game's
--     campaign_points total, then discarded -- never written to the games row.
--   - models_removed: games.opponent_unit_outcomes looks like it should cover
--     this, but it's filtered hard for the Battlefield Losses mechanic --
--     only characters/veteran-eligible troop types are recorded, and it's
--     `[]` entirely for any game logged while that campaign had Path to
--     Glory switched off. Computing "models killed/fled" from it would
--     silently undercount. models_removed is instead a single integer,
--     computed client-side from the FULL (unfiltered) opponentUnitState at
--     log time -- sum of `size` for every opponent unit ending the game
--     dead or fled, PtG on or off.
--
-- Idempotent: safe to re-run. Run after 023 (games.campaign_points).
-- ============================================================================

alter table games add column if not exists models_removed integer not null default 0;
alter table games add column if not exists baggage_destroyed boolean not null default false;
alter table games add column if not exists baggage_survived boolean not null default false;

comment on column games.models_removed is 'Sum of unit size for every OPPONENT unit that ended this battle dead or fled -- the full count, not opponent_unit_outcomes'' PtG-filtered subset. 0 for games logged before this column existed, not "no models removed".';
comment on column games.baggage_destroyed is 'Snapshot of manualObjectiveState.baggageDestroyed at log time (opponent''s baggage train destroyed). False for games logged before this column existed, not "not destroyed".';
comment on column games.baggage_survived is 'Snapshot of manualObjectiveState.baggageSurvived at log time (your own baggage train survived). False for games logged before this column existed, not "did not survive".';

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
    campaign_id, player_id, opponent_id, opponent_name, result, campaign_points,
    scenario, mission_id, phase_id, trait_objective_id, trait_objective_met, played_on, notes,
    opponent_unit_outcomes, kill_credits, models_removed, baggage_destroyed, baggage_survived
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
    coalesce((p_game->>'baggage_destroyed')::boolean, false),
    coalesce((p_game->>'baggage_survived')::boolean, false)
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
