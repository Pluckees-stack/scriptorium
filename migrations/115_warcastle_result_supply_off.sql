-- ============================================================================
-- 115_warcastle_result_supply_off.sql
--
-- WarCastle: no Supply for a battle's result after all (Grant, 30 Oct).
-- Undoes 114: a battle gives Supply and Warpstone only for objectives held
-- (104).
--
-- 1. The result Supply already given (warcastle_tokens reason 'result') is
--    taken back.
-- 2. warcastle_battle_tokens(pairing) is 104's again: objectives only.
-- 3. The tokens' reason check is 104's again (no 'result').
--
-- Idempotent: safe to re-run. Run after 114.
-- ============================================================================

delete from warcastle_tokens where reason = 'result';

alter table warcastle_tokens drop constraint if exists warcastle_tokens_reason_check;
alter table warcastle_tokens add constraint warcastle_tokens_reason_check
  check (reason in ('award', 'swap', 'correction', 'sent', 'received', 'spent', 'battle'));

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
  delete from warcastle_tokens where pairing_id = p_pairing and reason = 'battle';
  if v_p.result is null or v_p.player_b_id is null then return; end if;
  select * into v_o from warcastle_battle_objectives where pairing_id = p_pairing;
  if not found then return; end if;
  select round_number into v_round from tournament_rounds where id = v_p.round_id;
  v_note := 'Round ' || coalesce(v_round::text, '?') || ', table ' || coalesce(v_p.table_number::text, '?');
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
