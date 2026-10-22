-- ============================================================================
-- 104_warcastle_battle_tokens.sql
--
-- WarCastle: Supply and Warpstone from the objectives held at the end of a
-- battle (Grant, 23 Oct): each Strategic Objective a side holds is 1
-- Supply; the table's one Warpstone objective is 1 Warpstone. The players
-- declare them with their result; the tokens are given once the battle has
-- a result, and put right whenever the result or the objectives change.
--
-- 1. warcastle_battle_objectives: per pairing, how many each side held
--    (a_held for player_a, b_held for player_b) and who held the Warpstone
--    objective (null: no one). Members read; written only through
--    warcastle_report_objectives.
-- 2. warcastle_tokens.pairing_id, and reason 'battle': the tokens a battle
--    gave, so they can be taken back and given again when it changes.
-- 3. warcastle_battle_tokens(pairing): internal. Takes back the pairing's
--    battle tokens, then, if it has a result and objectives, gives them.
--    Run by a trigger when a pairing's result changes, and by
--    warcastle_report_objectives.
-- 4. warcastle_report_objectives(pairing, a_held, b_held, warpstone_by):
--    either player in the pairing (while its round isn't finished), or an
--    organiser (any time).
--
-- To undo:
--   drop trigger if exists tournament_pairings_warcastle_tokens on tournament_pairings;
--   drop function if exists warcastle_pairing_result_changed();
--   drop function if exists warcastle_report_objectives(uuid, integer, integer, uuid);
--   drop function if exists warcastle_battle_tokens(uuid);
--   delete from warcastle_tokens where reason = 'battle';
--   alter table warcastle_tokens drop column if exists pairing_id;
--   (and put the reason check back without 'battle')
--   drop table if exists warcastle_battle_objectives;
--
-- Idempotent: safe to re-run. Run after 101.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- warcastle_battle_objectives
-- ---------------------------------------------------------------------------
create table if not exists warcastle_battle_objectives (
  pairing_id   uuid primary key references tournament_pairings(id) on delete cascade,
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  a_held       integer not null default 0 check (a_held between 0 and 20),
  b_held       integer not null default 0 check (b_held between 0 and 20),
  warpstone_by uuid references players(id) on delete set null,
  reported_by  uuid references players(id) on delete set null,
  updated_at   timestamptz not null default now()
);

comment on table warcastle_battle_objectives is 'WarCastle: the Strategic Objectives each side held at the end of a battle, and who held the Warpstone one (104). Written through warcastle_report_objectives.';

alter table warcastle_battle_objectives enable row level security;

drop policy if exists "campaign members read battle objectives" on warcastle_battle_objectives;
create policy "campaign members read battle objectives" on warcastle_battle_objectives
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

revoke insert, update, delete on warcastle_battle_objectives from authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_tokens: a battle's tokens
-- ---------------------------------------------------------------------------
alter table warcastle_tokens add column if not exists pairing_id uuid references tournament_pairings(id) on delete cascade;
create index if not exists warcastle_tokens_pairing_idx on warcastle_tokens (pairing_id) where pairing_id is not null;

alter table warcastle_tokens drop constraint if exists warcastle_tokens_reason_check;
alter table warcastle_tokens add constraint warcastle_tokens_reason_check
  check (reason in ('award', 'swap', 'correction', 'sent', 'received', 'spent', 'battle'));

-- ---------------------------------------------------------------------------
-- warcastle_battle_tokens: give (or put right) a battle's tokens
-- ---------------------------------------------------------------------------
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

-- a pairing's result changes (a confirmed battle, or the organiser's word): its tokens follow
create or replace function warcastle_pairing_result_changed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.result is distinct from old.result then perform warcastle_battle_tokens(new.id); end if;
  return new;
end;
$$;
revoke all on function warcastle_pairing_result_changed() from public, anon, authenticated;

drop trigger if exists tournament_pairings_warcastle_tokens on tournament_pairings;
create trigger tournament_pairings_warcastle_tokens after update of result on tournament_pairings
  for each row execute function warcastle_pairing_result_changed();

-- ---------------------------------------------------------------------------
-- warcastle_report_objectives: a player (or the organiser) declares them
-- ---------------------------------------------------------------------------
create or replace function warcastle_report_objectives(p_pairing uuid, p_a_held integer, p_b_held integer, p_warpstone_by uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := auth.uid();
  v_p     tournament_pairings%rowtype;
  v_org   boolean;
  v_round text;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then raise exception 'No such battle.'; end if;
  if coalesce((select settings ->> 'template' from campaigns where id = v_p.campaign_id), '') <> 'warcastle' then
    raise exception 'Only for WarCastle.';
  end if;
  v_org := is_campaign_organiser(v_p.campaign_id) or is_platform_admin();
  if not v_org then
    if v_me not in (v_p.player_a_id, coalesce(v_p.player_b_id, v_p.player_a_id)) then raise exception 'That isn''t your battle.'; end if;
    select status into v_round from tournament_rounds where id = v_p.round_id;
    if v_round = 'completed' then raise exception 'That round is over: ask the organiser to change it.'; end if;
  end if;
  if p_a_held is null or p_b_held is null or p_a_held not between 0 and 20 or p_b_held not between 0 and 20 then
    raise exception 'Objectives held: 0 to 20 each.';
  end if;
  if p_warpstone_by is not null and p_warpstone_by not in (v_p.player_a_id, coalesce(v_p.player_b_id, v_p.player_a_id)) then
    raise exception 'The Warpstone objective goes to one of the two players, or no one.';
  end if;
  insert into warcastle_battle_objectives (pairing_id, campaign_id, a_held, b_held, warpstone_by, reported_by, updated_at)
  values (p_pairing, v_p.campaign_id, p_a_held, p_b_held, p_warpstone_by, v_me, now())
  on conflict (pairing_id) do update set a_held = excluded.a_held, b_held = excluded.b_held,
    warpstone_by = excluded.warpstone_by, reported_by = excluded.reported_by, updated_at = now();
  perform warcastle_battle_tokens(p_pairing);
end;
$$;
revoke all on function warcastle_report_objectives(uuid, integer, integer, uuid) from public, anon;
grant execute on function warcastle_report_objectives(uuid, integer, integer, uuid) to authenticated;
