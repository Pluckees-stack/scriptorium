-- ============================================================================
-- 112_warcastle_favour.sql
--
-- WarCastle: Favour of the Gods into magic items (Grant, 29 Oct 2026; the
-- rules are Grant's "Warcastle allegiance rules" doc). 111 counts each
-- Chaos player's Favours in their tracker (one a kill, a feature, the
-- ritual). When the round ends, each Favour becomes a free Enchanted Item
-- in the player's magic items, ready to give to a unit. Only armies that
-- roll on the Gaze of the Gods get them: Warriors of Chaos and Beastmen
-- Brayherds (not Dark Elves or Daemons of Chaos, Grant 29 Oct). Single use
-- for the event: once used it's gone, so the player marks it Used.
--
-- 1. warcastle_items.source may be 'favour'; tracker_submission_id is the
--    tracker that earned it; used_at is when its player marked it Used
--    (kept, so ending a round again never gives it back).
-- 2. warcastle_round_favours(round): internal. For each Chaos tracker in a
--    finished round, gives the Favours not given yet (and takes back any
--    over the count, unequipped and unused first). Run by a trigger when a
--    round is finished, and below for rounds already finished.
-- 3. warcastle_use_favour(item): the player, for a Favour on one of their
--    units.
-- A tracker an organiser removes takes its Favours with it.
--
-- To undo:
--   drop trigger if exists tournament_rounds_warcastle_favours on tournament_rounds;
--   drop function if exists warcastle_round_completed();
--   drop function if exists warcastle_use_favour(uuid);
--   drop function if exists warcastle_round_favours(uuid);
--   delete from warcastle_items where source = 'favour';
--   alter table warcastle_items drop column if exists used_at, drop column if exists tracker_submission_id;
--   (and put the source check back to 'common', 'faction')
--
-- Idempotent: safe to re-run. Run after 111.
-- ============================================================================

alter table warcastle_items add column if not exists tracker_submission_id uuid
  references warcastle_tracker_submissions(id) on delete cascade;
alter table warcastle_items add column if not exists used_at timestamptz;
alter table warcastle_items drop constraint if exists warcastle_items_source_check;
alter table warcastle_items add constraint warcastle_items_source_check check (source in ('common', 'faction', 'favour'));

create index if not exists warcastle_items_tracker_submission_idx on warcastle_items (tracker_submission_id);

comment on column warcastle_items.tracker_submission_id is 'WarCastle: for a Favour of the Gods, the tracker that earned it (112).';
comment on column warcastle_items.used_at is 'WarCastle: when its player marked it Used (a Favour of the Gods is single use, 112). A used item is no longer theirs to give.';

-- ---------------------------------------------------------------------------
-- warcastle_round_favours: a finished round's Favours into magic items
-- ---------------------------------------------------------------------------
create or replace function warcastle_round_favours(p_round uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_s       warcastle_tracker_submissions%rowtype;
  v_faction text;
  v_want    integer;
  v_have    integer;
begin
  for v_s in select * from warcastle_tracker_submissions where round_id = p_round loop
    -- the army they play: their roster in the campaign, else their membership's
    v_faction := coalesce(
      (select r.faction_id from rosters r where r.campaign_id = v_s.campaign_id and r.player_id = v_s.player_id order by r.created_at limit 1),
      (select m.faction_id from campaign_members m where m.campaign_id = v_s.campaign_id and m.user_id = v_s.player_id));
    v_want := case when v_s.track = 'corruption' and v_faction in ('warriors-of-chaos', 'beastmen-brayherds') then v_s.favour else 0 end;
    select count(*) into v_have from warcastle_items where tracker_submission_id = v_s.id;
    if v_have < v_want then
      insert into warcastle_items (campaign_id, player_id, name, points, source, type, tracker_submission_id)
      select v_s.campaign_id, v_s.player_id, 'Favour of the Gods', 0, 'favour', 'enchanted-item', v_s.id
        from generate_series(1, v_want - v_have);
    elsif v_have > v_want then
      delete from warcastle_items where id in (
        select id from warcastle_items where tracker_submission_id = v_s.id
         order by (used_at is not null), (unit_id is not null), created_at desc
         limit v_have - v_want);
    end if;
  end loop;
end;
$$;
revoke all on function warcastle_round_favours(uuid) from public, anon, authenticated;

-- a WarCastle round is finished: its Favours are given
create or replace function warcastle_round_completed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    perform warcastle_round_favours(new.id);
  end if;
  return new;
end;
$$;
revoke all on function warcastle_round_completed() from public, anon, authenticated;

drop trigger if exists tournament_rounds_warcastle_favours on tournament_rounds;
create trigger tournament_rounds_warcastle_favours after update of status on tournament_rounds
  for each row execute function warcastle_round_completed();

-- ---------------------------------------------------------------------------
-- warcastle_use_favour: the player has used it, so it's gone
-- ---------------------------------------------------------------------------
create or replace function warcastle_use_favour(p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_i  warcastle_items%rowtype;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  select * into v_i from warcastle_items where id = p_item for update;
  if not found or v_i.player_id <> v_me then raise exception 'That isn''t your item.'; end if;
  if v_i.source <> 'favour' then raise exception 'Only a Favour of the Gods is used up.'; end if;
  if v_i.used_at is not null then raise exception 'That Favour of the Gods has already been used.'; end if;
  if v_i.unit_id is null then raise exception 'Give it to a unit first.'; end if;
  update warcastle_items set used_at = now() where id = p_item;
end;
$$;
revoke all on function warcastle_use_favour(uuid) from public, anon;
grant execute on function warcastle_use_favour(uuid) to authenticated;

-- rounds already finished before this was run
do $$
declare v_r uuid;
begin
  for v_r in select distinct s.round_id from warcastle_tracker_submissions s
               join tournament_rounds r on r.id = s.round_id where r.status = 'completed' loop
    perform warcastle_round_favours(v_r);
  end loop;
end;
$$;
