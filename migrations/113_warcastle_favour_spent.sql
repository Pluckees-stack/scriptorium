-- ============================================================================
-- 113_warcastle_favour_spent.sql
--
-- WarCastle: a Favour of the Gods is spent by the round it's carried into
-- (Grant, 29 Oct 2026). Items only go on a unit between rounds, so a
-- Favour on a unit when a round ends was carried through it: it's marked
-- used (used_at, 112) and is gone. No Used button any more.
--
-- 1. warcastle_round_completed(): first spends the Favours on units in the
--    round's campaign, then gives the round's new Favours (112), which
--    aren't on a unit yet.
-- 2. warcastle_use_favour(item) is dropped (112's Used button).
--
-- To undo: re-run 112's warcastle_round_completed and warcastle_use_favour.
--
-- Idempotent: safe to re-run. Run after 112.
-- ============================================================================

create or replace function warcastle_round_completed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    update warcastle_items set used_at = now()
     where campaign_id = new.campaign_id and source = 'favour' and unit_id is not null and used_at is null;
    perform warcastle_round_favours(new.id);
  end if;
  return new;
end;
$$;
revoke all on function warcastle_round_completed() from public, anon, authenticated;

drop function if exists warcastle_use_favour(uuid);
