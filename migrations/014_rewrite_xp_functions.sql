-- ============================================================================
-- 014_rewrite_xp_functions.sql
--
-- Phase 2, part 6.
--
-- Of the three atomic XP functions, only log_game_with_xp needs a change.
-- The other two were pulled via pg_get_functiondef() and checked against
-- the new RLS from 010, not assumed -- deliberately left untouched here:
--
-- - increment_unit_xp(unit_id, amount): does a bare
--   `update units set experience = ... where id = p_unit_id`, with no
--   ownership check of its own -- it relies entirely on units' RLS policy
--   to silently match zero rows for a unit that isn't the caller's, which
--   it then turns into a friendly exception via `returning ... into new_xp`
--   plus a null check. The new "players manage their own units" policy
--   (010) preserves the exact same ownership logic (roster ownership),
--   just inside a campaign-scoped schema -- nothing here reasons about
--   campaign_id directly, so nothing needs to change.
--
-- - delete_game_with_xp(game_id): same shape -- ownership-gated via
--   `player_id = auth.uid()` on an existing row, acting on a game and its
--   own units purely by ID. No campaign reasoning needed to delete a row
--   that already has a fixed campaign_id.
--
-- - log_game_with_xp(game): the one exception, because it INSERTs a brand
--   new row that has no campaign_id yet -- there's no existing row for RLS
--   to have already scoped, unlike the other two. campaign_id must now be
--   supplied by the caller via p_game (a small addition to index.html's
--   doLog() call in Phase 4) and is checked explicitly before the insert,
--   in addition to whatever RLS's WITH CHECK on games would catch on its
--   own -- a membership check with a clear message beats a raw "row-level
--   security policy violation" error, matching this codebase's existing
--   error-message style ("Unit not found, or it does not belong to you.",
--   "Battle not found, or it is not yours to delete.").
--
-- Explicitly declared SECURITY INVOKER below -- it was always the default
-- (no clause = invoker), but this file is specifically about that property
-- being load-bearing: SECURITY INVOKER is what makes the campaign
-- membership check on the new games row actually enforced by RLS, not
-- just by the explicit check added here. Everything else in the body is
-- unchanged from the live version pulled via pg_get_functiondef().
--
-- Idempotent: safe to re-run. Run after 009 (needs is_campaign_member()).
-- ============================================================================

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
    scenario, trait_objective_id, trait_objective_met, played_on, notes,
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
