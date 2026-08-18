-- ============================================================================
-- 049_game_confirmation_rpcs.sql
--
-- Rewrites log_game_with_xp so logging a battle only ever inserts a pending
-- row -- no XP is granted at insert time any more. XP is held until both
-- sides have agreed, the direct extension of "not scored until confirmed":
-- awarding it immediately and clawing it back on a dispute is strictly worse
-- (a unit could act on XP -- e.g. a level-up ability -- during a window that
-- later has to be silently reversed), so this codebase leans the other way.
--
-- games RLS (010/028) grants the row owner (player_id) full access but the
-- opponent only read access -- so confirming/disputing, and admin
-- resolution, all need to go through SECURITY DEFINER functions, the same
-- shape as admin_delete_game (028), not a bare RLS-backed UPDATE.
--
-- apply_game_kill_credits is a private shared helper (revoked from
-- public/anon/authenticated -- it does no authorization check of its own,
-- confirm_game_result/admin_resolve_game do that before calling it) used by
-- both the confirm and admin-resolve paths so the crediting logic isn't
-- duplicated. It defensively re-verifies each credited unit actually
-- belongs to the expected side's roster in this campaign before writing --
-- never trusts the stored kill_credits/opponent_kill_credits jsonb blindly,
-- since a malicious payload at log time could otherwise get a SECURITY
-- DEFINER function to grant XP to arbitrary units once "confirmed".
--
-- admin_delete_game is also rewritten here (still the same function, not a
-- new one) to branch on confirmation_status before reversing any XP -- a
-- pending/disputed game never had XP applied via apply_game_kill_credits,
-- so unconditionally reversing it (the old behaviour, from when everything
-- was instant) would incorrectly deduct XP nobody ever actually received.
--
-- Idempotent: safe to re-run. Run after 048.
-- ============================================================================

create or replace function log_game_with_xp(p_game jsonb)
returns bigint
language plpgsql
security invoker
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
    player_vp, opponent_vp, opponent_campaign_points, confirmation_status
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
    'pending' -- always server-forced, never taken from the client payload
  )
  returning id into new_game_id;

  return new_game_id;
end;
$function$;

create or replace function apply_game_kill_credits(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_opponent_id uuid;
  v_campaign_id uuid;
  v_kill_credits jsonb;
  v_opponent_kill_credits jsonb;
  credit jsonb;
begin
  select player_id, opponent_id, campaign_id, kill_credits, opponent_kill_credits
    into v_player_id, v_opponent_id, v_campaign_id, v_kill_credits, v_opponent_kill_credits
    from games where id = p_game_id;

  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(v_kill_credits) = 'array' then v_kill_credits else '[]'::jsonb end)
  loop
    update units
       set experience = experience + coalesce((credit->>'amount')::integer, 0),
           updated_at = now()
     where id = (credit->>'unitId')::bigint
       and roster_id in (select id from rosters where player_id = v_player_id and campaign_id = v_campaign_id);
  end loop;

  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(v_opponent_kill_credits) = 'array' then v_opponent_kill_credits else '[]'::jsonb end)
  loop
    update units
       set experience = experience + coalesce((credit->>'amount')::integer, 0),
           updated_at = now()
     where id = (credit->>'unitId')::bigint
       and roster_id in (select id from rosters where player_id = v_opponent_id and campaign_id = v_campaign_id);
  end loop;
end;
$$;

revoke all on function apply_game_kill_credits(bigint) from public;

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
end;
$$;

revoke all on function confirm_game_result(bigint) from public;
grant execute on function confirm_game_result(bigint) to authenticated;

create or replace function dispute_game_result(p_game_id bigint, p_reason text)
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
  if auth.uid() <> v_opponent_id then raise exception 'Only the opponent on this battle can dispute it.'; end if;
  if v_status <> 'pending' then raise exception 'This battle isn''t awaiting confirmation.'; end if;

  update games
     set confirmation_status = 'disputed', disputed_at = now(), dispute_reason = nullif(trim(p_reason), '')
   where id = p_game_id;
end;
$$;

revoke all on function dispute_game_result(bigint, text) from public;
grant execute on function dispute_game_result(bigint, text) to authenticated;

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
end;
$$;

revoke all on function admin_resolve_game(bigint, jsonb) from public;
grant execute on function admin_resolve_game(bigint, jsonb) to authenticated;

create or replace function admin_delete_game(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_status text;
  v_player_id uuid;
  v_opponent_id uuid;
  v_kill_credits jsonb;
  v_opponent_kill_credits jsonb;
  credit jsonb;
begin
  select campaign_id, confirmation_status, player_id, opponent_id, kill_credits, opponent_kill_credits
    into v_campaign_id, v_status, v_player_id, v_opponent_id, v_kill_credits, v_opponent_kill_credits
    from games where id = p_game_id;

  if v_campaign_id is null then
    raise exception 'Game not found.';
  end if;
  if not (is_campaign_organiser(v_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can delete another player''s battle.';
  end if;

  -- XP is only ever actually granted for a confirmed/legacy game (see
  -- apply_game_kill_credits) -- a pending/disputed game never had it
  -- applied, so reversing it here would incorrectly deduct XP nobody
  -- actually received.
  if v_status in ('confirmed', 'legacy') then
    for credit in
      select * from jsonb_array_elements(case when jsonb_typeof(v_kill_credits) = 'array' then v_kill_credits else '[]'::jsonb end)
    loop
      update units
         set experience = greatest(0, experience - coalesce((credit->>'amount')::integer, 0)),
             updated_at = now()
       where id = (credit->>'unitId')::bigint
         and roster_id in (select id from rosters where player_id = v_player_id and campaign_id = v_campaign_id);
    end loop;

    for credit in
      select * from jsonb_array_elements(case when jsonb_typeof(v_opponent_kill_credits) = 'array' then v_opponent_kill_credits else '[]'::jsonb end)
    loop
      update units
         set experience = greatest(0, experience - coalesce((credit->>'amount')::integer, 0)),
             updated_at = now()
       where id = (credit->>'unitId')::bigint
         and roster_id in (select id from rosters where player_id = v_opponent_id and campaign_id = v_campaign_id);
    end loop;
  end if;

  delete from games where id = p_game_id;
end;
$$;

revoke all on function admin_delete_game(bigint) from public;
grant execute on function admin_delete_game(bigint) to authenticated;
