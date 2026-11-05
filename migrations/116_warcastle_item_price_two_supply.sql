-- ============================================================================
-- 116_warcastle_item_price_two_supply.sql
--
-- WarCastle: a Common magic item worth 51 to 100 points costs a Warpstone
-- and 2 Supply, as the Player Compendium has it (5.3; Grant, 5 Nov). It was
-- a Warpstone and 3 Supply (101).
--
-- warcastle_item_price(points, source) replaced; warcastle_buy_item (101)
-- reads its price from it, so nothing else changes. Items already bought
-- keep what was paid for them.
--
-- To undo: re-run 101's warcastle_item_price.
--
-- Idempotent: safe to re-run. Run after 101.
-- ============================================================================

create or replace function warcastle_item_price(p_points integer, p_source text, out supply integer, out warpstone integer)
language plpgsql immutable as $$
begin
  if p_source = 'faction' then supply := 0; warpstone := 1;
  elsif p_source = 'common' and p_points <= 15 then supply := 1; warpstone := 0;
  elsif p_source = 'common' and p_points <= 35 then supply := 2; warpstone := 0;
  elsif p_source = 'common' and p_points <= 50 then supply := 3; warpstone := 0;
  elsif p_source = 'common' and p_points <= 100 then supply := 2; warpstone := 1;
  else raise exception 'No price for that item: Common items go up to 100 points.';
  end if;
end;
$$;
grant execute on function warcastle_item_price(integer, text) to authenticated;
