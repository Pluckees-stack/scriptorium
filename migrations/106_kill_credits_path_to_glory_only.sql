-- ============================================================================
-- 106_kill_credits_path_to_glory_only.sql
--
-- Kill credits (which unit killed which, 1 XP a kill) are part of Path to
-- Glory. index.html now only picks a killer and sends kill_credits /
-- opponent_kill_credits when the campaign has path_to_glory_enabled; this
-- is the database side of the same rule, so credits that arrive anyway (an
-- old copy of the page, or a hand-made payload) give no experience.
--
-- apply_game_kill_credits (049; revoked from clients in 070) is the same
-- function as before, except that when the battle's campaign has Path to
-- Glory off it gives nothing and clears the battle's credits. Clearing
-- them keeps reverse_game_kill_credits (051) exact: deleting the battle
-- later takes back only experience that was actually given, even if Path
-- to Glory is switched on in between. The rows are only touched when
-- there were credits to clear.
--
-- How units ended (alive, fleeing, at 25% or less, fled, destroyed) and
-- the scoring are untouched.
--
-- index.html works before this is run (it already sends no credits with
-- Path to Glory off). Run after 070. Idempotent: safe to re-run.
--
-- To undo: re-run the apply_game_kill_credits part of
-- 049_game_confirmation_rpcs.sql, then the revoke in 070.
-- ============================================================================

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
  v_ptg boolean;
  credit jsonb;
begin
  select player_id, opponent_id, campaign_id, kill_credits, opponent_kill_credits
    into v_player_id, v_opponent_id, v_campaign_id, v_kill_credits, v_opponent_kill_credits
    from games where id = p_game_id;

  select path_to_glory_enabled into v_ptg from campaigns where id = v_campaign_id;
  if not coalesce(v_ptg, false) then
    if v_kill_credits is not null or v_opponent_kill_credits is not null then
      update games set kill_credits = null, opponent_kill_credits = null where id = p_game_id;
    end if;
    return;
  end if;

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

-- create or replace keeps the grants, but be sure: no direct callers (070)
revoke all on function apply_game_kill_credits(bigint) from public, anon, authenticated;
