-- ============================================================================
-- 111_warcastle_trackers.sql
--
-- WarCastle: Chaos corruption and Waaagh! energy (Grant, 29 Oct 2026; the
-- rules are Grant's "Warcastle allegiance rules" doc). Once a battle has a
-- result, each player in a Chaos or Orc allegiance says what they did in it
-- (terrain burned, Grim Monuments, big units destroyed, characters killed,
-- special features, the ritual); that's turned into points here, so a
-- player never sees a number. The bars, the knock-backs from Order wins and
-- the Waaagh! ladder are worked out in index.html from these rows' totals.
--
-- Which allegiance feeds which bar is campaigns.settings.warcastle.trackers
-- .kinds ({ allegiance id: 'corruption' | 'waaagh' | 'order' }), set by the
-- organiser in Run › Allegiances. Nothing else changes: no existing table,
-- function or policy is touched.
--
-- 1. warcastle_tracker_submissions: one per player per battle. A player
--    reads their own; organisers read and delete any. Written only through
--    warcastle_submit_tracker.
-- 2. warcastle_submit_tracker(pairing, items): a player in the battle,
--    while its round isn't finished, once it has a result. Works out the
--    points and Favour of the Gods from items:
--      { burned, monuments, big_units,
--        kills: [{ rank: 'advisor' | 'lieutenant' | 'bsb' | 'castellan' | 'warlord', by_warlord: bool }],
--        features: ['shard' | 'roots' | 'manor'], ritual: bool }
--    burned 1 each (6 at most), monuments 2 each (5 at most), big units 2
--    each, kills 1 to 5 by rank (6 at most; half, rounded up, if not by the
--    Warlord); features and the ritual only on their own table (13 the
--    Shard, 100; 4 World Roots, 75, once per event; 8 the Manor, 50, once
--    per army; 6 the ritual, Chaos only) and only after a win there.
--    Favour of the Gods (Chaos only): one a kill, a feature, the ritual.
-- 3. warcastle_tracker_totals(tournament): any member; each round's points
--    for each bar, and nothing per player.
--
-- To undo:
--   drop function if exists warcastle_tracker_totals(uuid);
--   drop function if exists warcastle_submit_tracker(uuid, jsonb);
--   drop table if exists warcastle_tracker_submissions;
--
-- Idempotent: safe to re-run. Run after 110.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- warcastle_tracker_submissions
-- ---------------------------------------------------------------------------
create table if not exists warcastle_tracker_submissions (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  round_id      uuid not null references tournament_rounds(id) on delete cascade,
  pairing_id    uuid not null references tournament_pairings(id) on delete cascade,
  player_id     uuid not null references players(id) on delete cascade,
  track         text not null check (track in ('corruption', 'waaagh')),
  items         jsonb not null default '{}'::jsonb,
  points        integer not null default 0 check (points >= 0),
  favour        integer not null default 0 check (favour >= 0),
  updated_at    timestamptz not null default now(),
  unique (pairing_id, player_id)
);

comment on table warcastle_tracker_submissions is 'WarCastle: what a Chaos or Orc player did in a battle, and the corruption or Waaagh! energy it scored (111). Written through warcastle_submit_tracker.';

create index if not exists warcastle_tracker_submissions_tournament_idx on warcastle_tracker_submissions (tournament_id);

alter table warcastle_tracker_submissions enable row level security;

drop policy if exists "players read their own tracker submissions" on warcastle_tracker_submissions;
drop policy if exists "organisers read tracker submissions" on warcastle_tracker_submissions;
drop policy if exists "organisers remove tracker submissions" on warcastle_tracker_submissions;

create policy "players read their own tracker submissions" on warcastle_tracker_submissions
  for select to authenticated
  using (player_id = (select auth.uid()));

create policy "organisers read tracker submissions" on warcastle_tracker_submissions
  for select to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

create policy "organisers remove tracker submissions" on warcastle_tracker_submissions
  for delete to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

revoke insert, update on warcastle_tracker_submissions from authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_submit_tracker
-- ---------------------------------------------------------------------------
create or replace function warcastle_submit_tracker(p_pairing uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me        uuid := auth.uid();
  v_p         tournament_pairings%rowtype;
  v_settings  jsonb;
  v_round     text;
  v_side      uuid;
  v_track     text;
  v_won       boolean;
  v_burned    integer;
  v_monuments integer;
  v_big       integer;
  v_kills     jsonb;
  v_kill      jsonb;
  v_value     integer;
  v_features  jsonb;
  v_feature   text;
  v_ritual    boolean;
  v_points    integer := 0;
  v_favour    integer := 0;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then raise exception 'No such battle.'; end if;
  select settings into v_settings from campaigns where id = v_p.campaign_id;
  if coalesce(v_settings ->> 'template', '') <> 'warcastle' then raise exception 'Only for WarCastle.'; end if;
  if v_p.player_b_id is null or v_me not in (v_p.player_a_id, v_p.player_b_id) then raise exception 'That isn''t your battle.'; end if;
  select status into v_round from tournament_rounds where id = v_p.round_id;
  if v_round = 'completed' then raise exception 'That round is over: ask the organiser to change it.'; end if;
  if v_p.result is null then raise exception 'The battle needs its result first.'; end if;

  select warcastle_allegiance into v_side from tournament_entrants
   where tournament_id = v_p.tournament_id and player_id = v_me;
  v_track := v_settings -> 'warcastle' -> 'trackers' -> 'kinds' ->> v_side::text;
  if v_track is null or v_track not in ('corruption', 'waaagh') then
    raise exception 'Your allegiance has no tracker.';
  end if;
  v_won := (v_p.result = 'a_win' and v_me = v_p.player_a_id) or (v_p.result = 'b_win' and v_me = v_p.player_b_id);

  p_items := coalesce(p_items, '{}'::jsonb);
  v_burned := coalesce((p_items ->> 'burned')::integer, 0);
  v_monuments := coalesce((p_items ->> 'monuments')::integer, 0);
  v_big := coalesce((p_items ->> 'big_units')::integer, 0);
  if v_burned not between 0 and 6 then raise exception 'Terrain burned: 0 to 6.'; end if;
  if v_monuments not between 0 and 5 then raise exception 'Grim Monuments: 0 to 5.'; end if;
  if v_big not between 0 and 50 then raise exception 'Units destroyed: 0 to 50.'; end if;
  v_points := v_burned + 2 * v_monuments + 2 * v_big;

  v_kills := coalesce(p_items -> 'kills', '[]'::jsonb);
  if jsonb_typeof(v_kills) <> 'array' or jsonb_array_length(v_kills) > 6 then raise exception 'Characters killed: 6 at most.'; end if;
  for v_kill in select * from jsonb_array_elements(v_kills) loop
    v_value := case v_kill ->> 'rank' when 'advisor' then 1 when 'lieutenant' then 2 when 'bsb' then 3
                                      when 'castellan' then 4 when 'warlord' then 5 end;
    if v_value is null then raise exception 'Unknown character killed.'; end if;
    if not coalesce((v_kill ->> 'by_warlord')::boolean, false) then v_value := (v_value + 1) / 2; end if;
    v_points := v_points + v_value;
    v_favour := v_favour + 1;
  end loop;

  v_features := coalesce(p_items -> 'features', '[]'::jsonb);
  if jsonb_typeof(v_features) <> 'array' then raise exception 'Special features: a list.'; end if;
  for v_feature in select distinct value from jsonb_array_elements_text(v_features) loop
    if v_feature not in ('shard', 'roots', 'manor') then raise exception 'Unknown special feature.'; end if;
    if not v_won or v_p.table_number is distinct from (case v_feature when 'shard' then 13 when 'roots' then 4 else 8 end) then
      raise exception 'A special feature needs a win on its own table.';
    end if;
    if v_feature = 'roots' and exists (select 1 from warcastle_tracker_submissions s
        where s.tournament_id = v_p.tournament_id and s.pairing_id <> p_pairing and s.items -> 'features' ? 'roots') then
      raise exception 'World Roots has already been claimed.';
    end if;
    if v_feature = 'manor' and exists (select 1 from warcastle_tracker_submissions s
        where s.tournament_id = v_p.tournament_id and s.player_id = v_me and s.pairing_id <> p_pairing and s.items -> 'features' ? 'manor') then
      raise exception 'You''ve already claimed Fortenhaf Manor.';
    end if;
    v_points := v_points + case v_feature when 'shard' then 100 when 'roots' then 75 else 50 end;
    v_favour := v_favour + 1;
  end loop;

  v_ritual := coalesce((p_items ->> 'ritual')::boolean, false);
  if v_ritual then
    if v_track <> 'corruption' or not v_won or v_p.table_number is distinct from 6 then
      raise exception 'The ritual needs a Chaos win on Mount Kalnas.';
    end if;
    if exists (select 1 from warcastle_tracker_submissions s
        where s.tournament_id = v_p.tournament_id and s.pairing_id <> p_pairing and coalesce((s.items ->> 'ritual')::boolean, false)) then
      raise exception 'The ritual has already been completed.';
    end if;
    v_favour := v_favour + 1;
  end if;
  if v_track <> 'corruption' then v_favour := 0; end if;

  insert into warcastle_tracker_submissions (tournament_id, campaign_id, round_id, pairing_id, player_id, track, items, points, favour, updated_at)
  values (v_p.tournament_id, v_p.campaign_id, v_p.round_id, p_pairing, v_me, v_track,
          jsonb_build_object('burned', v_burned, 'monuments', v_monuments, 'big_units', v_big, 'kills', v_kills,
                             'features', (select coalesce(jsonb_agg(distinct value), '[]'::jsonb) from jsonb_array_elements_text(v_features)),
                             'ritual', v_ritual),
          v_points, v_favour, now())
  on conflict (pairing_id, player_id) do update set track = excluded.track, items = excluded.items,
    points = excluded.points, favour = excluded.favour, updated_at = now();
end;
$$;
revoke all on function warcastle_submit_tracker(uuid, jsonb) from public, anon;
grant execute on function warcastle_submit_tracker(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_tracker_totals: each round's points for each bar (members)
-- ---------------------------------------------------------------------------
create or replace function warcastle_tracker_totals(p_tournament uuid)
returns table (round_number integer, track text, points integer)
language sql stable security definer set search_path = public as $$
  select r.round_number, s.track, sum(s.points)::integer
    from warcastle_tracker_submissions s
    join tournament_rounds r on r.id = s.round_id
   where s.tournament_id = p_tournament
     and (is_campaign_member(s.campaign_id) or is_platform_admin())
   group by r.round_number, s.track
   order by r.round_number, s.track;
$$;
revoke all on function warcastle_tracker_totals(uuid) from public, anon;
grant execute on function warcastle_tracker_totals(uuid) to authenticated;
