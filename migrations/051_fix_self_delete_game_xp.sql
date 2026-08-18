-- ============================================================================
-- 051_fix_self_delete_game_xp.sql
--
-- delete_game_with_xp (the player-facing "remove this battle" button,
-- predates migration tracking) had two problems once 048/049 introduced
-- two-sided, held-until-confirmed XP:
--
-- 1. It unconditionally reversed kill_credits regardless of confirmation
--    status -- a pending/disputed game never had that XP applied
--    (apply_game_kill_credits only runs on confirm), so deleting one would
--    have wrongly deducted XP nobody actually received. Same bug
--    admin_delete_game had, fixed the same way in 049.
--
-- 2. It only ever reversed kill_credits (the logger's own units) --
--    correct under the old one-sided model, since that's all that existed,
--    but a confirmed game can now also carry opponent_kill_credits
--    (crediting the OPPONENT's units). Being SECURITY INVOKER, it could
--    never have reversed those anyway -- RLS blocks writing to someone
--    else's units. It needs to become SECURITY DEFINER, same as
--    admin_delete_game, to correctly reverse both sides atomically.
--
-- reverse_game_kill_credits is pulled out as a shared private helper
-- (revoked from public/anon/authenticated, same treatment as
-- apply_game_kill_credits in 049) so this reversal logic exists in exactly
-- one place instead of duplicated between admin_delete_game and
-- delete_game_with_xp.
--
-- delete_game_with_xp keeps its original, narrower authorization (only the
-- game's own player_id may call it) -- this is the player's own
-- self-service delete, not the organiser/admin override, so it
-- deliberately does NOT gain is_campaign_organiser/is_platform_admin access
-- the way admin_delete_game has.
--
-- Idempotent: safe to re-run. Run after 049.
-- ============================================================================

create or replace function reverse_game_kill_credits(p_game_id bigint)
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
end;
$$;

revoke all on function reverse_game_kill_credits(bigint) from public;

create or replace function admin_delete_game(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_status text;
begin
  select campaign_id, confirmation_status into v_campaign_id, v_status from games where id = p_game_id;

  if v_campaign_id is null then
    raise exception 'Game not found.';
  end if;
  if not (is_campaign_organiser(v_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can delete another player''s battle.';
  end if;

  if v_status in ('confirmed', 'legacy') then
    perform reverse_game_kill_credits(p_game_id);
  end if;

  delete from games where id = p_game_id;
end;
$$;

revoke all on function admin_delete_game(bigint) from public;
grant execute on function admin_delete_game(bigint) to authenticated;

create or replace function delete_game_with_xp(p_game_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_status text;
begin
  select player_id, confirmation_status into v_player_id, v_status
    from games where id = p_game_id;

  if v_player_id is null then
    raise exception 'Battle not found, or it is not yours to delete.';
  end if;
  if v_player_id <> auth.uid() then
    raise exception 'Battle not found, or it is not yours to delete.';
  end if;

  if v_status in ('confirmed', 'legacy') then
    perform reverse_game_kill_credits(p_game_id);
  end if;

  delete from games where id = p_game_id;
end;
$$;

revoke all on function delete_game_with_xp(bigint) from public;
grant execute on function delete_game_with_xp(bigint) to authenticated;
