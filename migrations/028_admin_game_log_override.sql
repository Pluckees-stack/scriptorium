-- ============================================================================
-- 028_admin_game_log_override.sql
--
-- Reverses part of the "no organiser override on player-owned data" decision
-- from 010_rls_policies_all_tables.sql, for games specifically. That decision
-- was correct when written, but with real players now mid-campaign it means
-- a single mis-entered result or points total has no fix path at all short of
-- editing the database directly. Confirmed with Grant 2026-07-22: organisers
-- (and platform admins) may now correct or remove a game logged by anyone in
-- their own campaign. rosters/units/unit_advances are NOT touched by this
-- migration and remain strictly owner-write, as before.
--
-- Two separate mechanisms, deliberately not one:
--
-- 1. A plain RLS UPDATE policy, for editing fields with no side effects
--    (result, campaign_points, opponent, mission, scenario, notes,
--    played_on, trait_objective_*). The client only ever sends these fields;
--    kill_credits/opponent_unit_outcomes are left alone by the app's edit
--    form on purpose, since they're what log_game_with_xp already used to
--    apply XP at insert time and editing them here wouldn't reconcile that.
--
-- 2. A SECURITY DEFINER function for delete, because deleting a game also
--    needs to reverse whatever XP its kill_credits already granted -- a bare
--    RLS DELETE grant can't do that atomic "delete + reverse" step. This is
--    a NEW function (admin_delete_game), not a change to the existing
--    player-facing delete_game_with_xp -- that function predates migration
--    tracking (see 014_rewrite_xp_functions.sql's header) and its exact live
--    definition isn't in this repo, so it's safer to leave it untouched and
--    add a parallel admin path than to guess its body via create-or-replace.
--    XP reversal is clamped at 0, same reasoning as delete_game_with_xp per
--    014's description of it: a unit's XP may have moved since (spent,
--    other games) so a straight subtraction could otherwise go negative.
--
-- Idempotent: safe to re-run. Run after 009 (is_campaign_organiser/
-- is_platform_admin) and 020 (games.phase_id, kill_credits shape).
-- ============================================================================

drop policy if exists "organisers can update games in their campaign" on games;
create policy "organisers can update games in their campaign" on games
  for update
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

create or replace function admin_delete_game(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_kill_credits jsonb;
  credit jsonb;
begin
  select campaign_id, kill_credits into v_campaign_id, v_kill_credits
    from games where id = p_game_id;

  if v_campaign_id is null then
    raise exception 'Game not found.';
  end if;
  if not (is_campaign_organiser(v_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can delete another player''s battle.';
  end if;

  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(v_kill_credits) = 'array' then v_kill_credits else '[]'::jsonb end)
  loop
    update units
       set experience = greatest(0, experience - coalesce((credit->>'amount')::integer, 0)),
           updated_at = now()
     where id = (credit->>'unitId')::bigint;
  end loop;

  delete from games where id = p_game_id;
end;
$$;

revoke all on function admin_delete_game(bigint) from public;
grant execute on function admin_delete_game(bigint) to authenticated;
