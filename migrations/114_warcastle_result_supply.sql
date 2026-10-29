-- ============================================================================
-- 114_warcastle_result_supply.sql
--
-- WarCastle: Supply for a battle's result (Grant, 29 Oct), on top of the
-- Supply and Warpstone for objectives held (104): the winner gets 3 Supply,
-- each side in a draw 2, the loser 1.
--
-- 1. warcastle_tokens reason 'result': the Supply a battle's result gave
--    (with pairing_id), taken back and given again whenever it changes.
-- 2. warcastle_battle_tokens(pairing) replaced: takes back the pairing's
--    'battle' and 'result' tokens, then, if it has a result and two
--    players, gives the result's Supply and (if reported) the objectives'.
--    Run by the trigger from 104 when the result changes, and by
--    warcastle_report_objectives.
-- 3. Battles that already have a result get their result's Supply now.
--
-- To undo:
--   delete from warcastle_tokens where reason = 'result';
--   re-run 104's warcastle_battle_tokens and reason check.
--
-- Idempotent: safe to re-run. Run after 104.
-- ============================================================================

alter table warcastle_tokens drop constraint if exists warcastle_tokens_reason_check;
alter table warcastle_tokens add constraint warcastle_tokens_reason_check
  check (reason in ('award', 'swap', 'correction', 'sent', 'received', 'spent', 'battle', 'result'));

create or replace function warcastle_battle_tokens(p_pairing uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p     tournament_pairings%rowtype;
  v_o     warcastle_battle_objectives%rowtype;
  v_round integer;
  v_note  text;
begin
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then return; end if;
  if coalesce((select settings ->> 'template' from campaigns where id = v_p.campaign_id), '') <> 'warcastle' then return; end if;
  delete from warcastle_tokens where pairing_id = p_pairing and reason in ('battle', 'result');
  if v_p.result is null or v_p.player_b_id is null then return; end if;
  select round_number into v_round from tournament_rounds where id = v_p.round_id;
  v_note := 'Round ' || coalesce(v_round::text, '?') || ', table ' || coalesce(v_p.table_number::text, '?');
  -- the result: win 3, draw 2, loss 1
  insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, other_player_id, pairing_id) values
    (v_p.campaign_id, v_p.player_a_id, 'supply', case v_p.result when 'a_win' then 3 when 'draw' then 2 else 1 end, 'result', v_note, v_p.player_b_id, p_pairing),
    (v_p.campaign_id, v_p.player_b_id, 'supply', case v_p.result when 'b_win' then 3 when 'draw' then 2 else 1 end, 'result', v_note, v_p.player_a_id, p_pairing);
  -- the objectives held, once reported
  select * into v_o from warcastle_battle_objectives where pairing_id = p_pairing;
  if not found then return; end if;
  if v_o.a_held > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, other_player_id, pairing_id)
    values (v_p.campaign_id, v_p.player_a_id, 'supply', v_o.a_held, 'battle', v_note, v_p.player_b_id, p_pairing);
  end if;
  if v_o.b_held > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, other_player_id, pairing_id)
    values (v_p.campaign_id, v_p.player_b_id, 'supply', v_o.b_held, 'battle', v_note, v_p.player_a_id, p_pairing);
  end if;
  if v_o.warpstone_by in (v_p.player_a_id, v_p.player_b_id) then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, other_player_id, pairing_id)
    values (v_p.campaign_id, v_o.warpstone_by, 'warpstone', 1, 'battle', v_note,
            case when v_o.warpstone_by = v_p.player_a_id then v_p.player_b_id else v_p.player_a_id end, p_pairing);
  end if;
end;
$$;
revoke all on function warcastle_battle_tokens(uuid) from public, anon, authenticated;

-- battles that already have a result
do $$
declare r record;
begin
  for r in select tp.id from tournament_pairings tp join campaigns c on c.id = tp.campaign_id
           where c.settings ->> 'template' = 'warcastle' and tp.result is not null and tp.player_b_id is not null loop
    perform warcastle_battle_tokens(r.id);
  end loop;
end $$;
