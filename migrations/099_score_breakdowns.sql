-- ============================================================================
-- 099_score_breakdowns.sql
--
-- What each side's Victory Points were made of, kept with the battle, so an
-- organiser can see and correct the scoring elements rather than just the
-- totals.
--
-- 1. games.player_breakdown / games.opponent_breakdown: each side's VP as
--    the app tallied it when the battle was logged, a list of
--    {key, label, vp}: key is 'units' (a unit destroyed, fled or reduced) or
--    the objective (king-is-dead, trophies-of-war, breaking-the-enemy,
--    special-feature, baggage-trains, domination, strategic-locations). The
--    app already sends both in log_game_with_xp's payload; until now the
--    function ignored them. Battles logged before this have none.
-- 2. log_game_with_xp: as 049 had it (security definer from 070, search
--    path from 046), now also storing the two breakdowns.
-- 3. tournament_pairings.vp_detail: the organiser's corrected elements for
--    a table, {a: {key: vp, ...}, b: {...}}, alongside vp_a / vp_b (084),
--    which stay the totals the standings use. Organisers write it through
--    the existing "organisers manage tournament pairings" policy (039).
--
-- To undo:
--   alter table tournament_pairings drop column if exists vp_detail;
--   alter table games drop column if exists player_breakdown,
--     drop column if exists opponent_breakdown;
--   then re-run log_game_with_xp from 049 (and 070's security definer).
-- ============================================================================

alter table games add column if not exists player_breakdown jsonb;
alter table games add column if not exists opponent_breakdown jsonb;
comment on column games.player_breakdown is 'The logging player''s VP, element by element, as tallied when logged: [{key, label, vp}] (099).';
comment on column games.opponent_breakdown is 'The opponent''s VP, element by element, as tallied when logged: [{key, label, vp}] (099).';

alter table tournament_pairings add column if not exists vp_detail jsonb;
comment on column tournament_pairings.vp_detail is 'The organiser''s corrected VP elements for each side, {a: {key: vp}, b: {key: vp}}; vp_a / vp_b hold the totals (099).';

create or replace function log_game_with_xp(p_game jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $function$
declare
  new_game_id bigint;
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
    opponent_unit_outcomes, own_unit_outcomes, kill_credits, opponent_kill_credits,
    models_removed, models_slain, models_fled,
    baggage_destroyed, baggage_survived, standards_captured,
    opponent_standards_captured, opponent_special_feature,
    opponent_domination_quarters, opponent_domination_double_strength, opponent_domination_uncontested,
    player_vp, opponent_vp, opponent_campaign_points, confirmation_status,
    player_breakdown, opponent_breakdown
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
    case when jsonb_typeof(p_game->'opponent_unit_outcomes') = 'array' then p_game->'opponent_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'own_unit_outcomes') = 'array' then p_game->'own_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'kill_credits') = 'array' then p_game->'kill_credits' else null end,
    case when jsonb_typeof(p_game->'opponent_kill_credits') = 'array' then p_game->'opponent_kill_credits' else null end,
    coalesce((p_game->>'models_removed')::integer, 0),
    coalesce((p_game->>'models_slain')::integer, 0),
    coalesce((p_game->>'models_fled')::integer, 0),
    coalesce((p_game->>'baggage_destroyed')::boolean, false),
    coalesce((p_game->>'baggage_survived')::boolean, false),
    coalesce((p_game->>'standards_captured')::integer, 0),
    coalesce((p_game->>'opponent_standards_captured')::integer, 0),
    coalesce((p_game->>'opponent_special_feature')::boolean, false),
    coalesce((p_game->>'opponent_domination_quarters')::integer, 0),
    coalesce((p_game->>'opponent_domination_double_strength')::integer, 0),
    coalesce((p_game->>'opponent_domination_uncontested')::integer, 0),
    coalesce((p_game->>'player_vp')::integer, 0),
    coalesce((p_game->>'opponent_vp')::integer, 0),
    coalesce((p_game->>'opponent_campaign_points')::integer, 0),
    'pending', -- always server-forced, never taken from the client payload
    case when jsonb_typeof(p_game->'player_breakdown') = 'array' then p_game->'player_breakdown' else null end,
    case when jsonb_typeof(p_game->'opponent_breakdown') = 'array' then p_game->'opponent_breakdown' else null end
  )
  returning id into new_game_id;

  return new_game_id;
end;
$function$;
