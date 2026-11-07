-- ============================================================================
-- 117_warcastle_tracker_organiser.sql
--
-- WarCastle: the organiser enters a player's corruption or Waaagh! energy
-- (Grant, 7 Nov 2026: players weren't getting the pop-up after their
-- battles, so he enters them by hand). Same form, same scoring as 111.
--
-- 1. warcastle_save_tracker(pairing, player, items): internal. 111's
--    scoring and save, for any player in the battle, moved here from
--    warcastle_submit_tracker so the two can't drift apart. One change:
--    Fortenhaf Manor is on table 7 (it moved there on 4 Nov; 111 had 8).
-- 2. warcastle_submit_tracker(pairing, items): the player, as before (in
--    the battle, round not finished), then 1.
-- 3. warcastle_enter_tracker(pairing, player, items): an organiser of the
--    campaign (or a platform admin), for a player in the battle, in any
--    round, then 1. In a finished round its Favours of the Gods are given
--    straight away (112's warcastle_round_favours).
--
-- To undo: re-run 111's warcastle_submit_tracker, then
--   drop function if exists warcastle_enter_tracker(uuid, uuid, jsonb);
--   drop function if exists warcastle_save_tracker(uuid, uuid, jsonb);
--
-- Idempotent: safe to re-run. Run after 113.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- warcastle_save_tracker: internal; 111's rules
-- ---------------------------------------------------------------------------
create or replace function warcastle_save_tracker(p_pairing uuid, p_player uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         tournament_pairings%rowtype;
  v_settings  jsonb;
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
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then raise exception 'No such battle.'; end if;
  select settings into v_settings from campaigns where id = v_p.campaign_id;
  if coalesce(v_settings ->> 'template', '') <> 'warcastle' then raise exception 'Only for WarCastle.'; end if;
  if v_p.player_b_id is null or p_player is null or p_player not in (v_p.player_a_id, v_p.player_b_id) then raise exception 'That player isn''t in this battle.'; end if;
  if v_p.result is null then raise exception 'The battle needs its result first.'; end if;

  select warcastle_allegiance into v_side from tournament_entrants
   where tournament_id = v_p.tournament_id and player_id = p_player;
  v_track := v_settings -> 'warcastle' -> 'trackers' -> 'kinds' ->> v_side::text;
  if v_track is null or v_track not in ('corruption', 'waaagh') then
    raise exception 'That allegiance has no tracker.';
  end if;
  v_won := (v_p.result = 'a_win' and p_player = v_p.player_a_id) or (v_p.result = 'b_win' and p_player = v_p.player_b_id);

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
    if not v_won or v_p.table_number is distinct from (case v_feature when 'shard' then 13 when 'roots' then 4 else 7 end) then
      raise exception 'A special feature needs a win on its own table.';
    end if;
    if v_feature = 'roots' and exists (select 1 from warcastle_tracker_submissions s
        where s.tournament_id = v_p.tournament_id and s.pairing_id <> p_pairing and s.items -> 'features' ? 'roots') then
      raise exception 'World Roots has already been claimed.';
    end if;
    if v_feature = 'manor' and exists (select 1 from warcastle_tracker_submissions s
        where s.tournament_id = v_p.tournament_id and s.player_id = p_player and s.pairing_id <> p_pairing and s.items -> 'features' ? 'manor') then
      raise exception 'Fortenhaf Manor has already been claimed by this player.';
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
  values (v_p.tournament_id, v_p.campaign_id, v_p.round_id, p_pairing, p_player, v_track,
          jsonb_build_object('burned', v_burned, 'monuments', v_monuments, 'big_units', v_big, 'kills', v_kills,
                             'features', (select coalesce(jsonb_agg(distinct value), '[]'::jsonb) from jsonb_array_elements_text(v_features)),
                             'ritual', v_ritual),
          v_points, v_favour, now())
  on conflict (pairing_id, player_id) do update set track = excluded.track, items = excluded.items,
    points = excluded.points, favour = excluded.favour, updated_at = now();
end;
$$;
revoke all on function warcastle_save_tracker(uuid, uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_submit_tracker: the player, as in 111
-- ---------------------------------------------------------------------------
create or replace function warcastle_submit_tracker(p_pairing uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := auth.uid();
  v_p     tournament_pairings%rowtype;
  v_round text;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then raise exception 'No such battle.'; end if;
  if v_p.player_b_id is null or v_me not in (v_p.player_a_id, v_p.player_b_id) then raise exception 'That isn''t your battle.'; end if;
  select status into v_round from tournament_rounds where id = v_p.round_id;
  if v_round = 'completed' then raise exception 'That round is over: ask the organiser to change it.'; end if;
  perform warcastle_save_tracker(p_pairing, v_me, p_items);
end;
$$;
revoke all on function warcastle_submit_tracker(uuid, jsonb) from public, anon;
grant execute on function warcastle_submit_tracker(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_enter_tracker: an organiser, for a player in the battle
-- ---------------------------------------------------------------------------
create or replace function warcastle_enter_tracker(p_pairing uuid, p_player uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p     tournament_pairings%rowtype;
  v_round text;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  select * into v_p from tournament_pairings where id = p_pairing;
  if not found then raise exception 'No such battle.'; end if;
  if not (is_campaign_organiser(v_p.campaign_id) or is_platform_admin()) then raise exception 'Only an organiser can do that.'; end if;
  perform warcastle_save_tracker(p_pairing, p_player, p_items);
  -- a finished round has given its Favours already: give (or take back) these now
  select status into v_round from tournament_rounds where id = v_p.round_id;
  if v_round = 'completed' then perform warcastle_round_favours(v_p.round_id); end if;
end;
$$;
revoke all on function warcastle_enter_tracker(uuid, uuid, jsonb) from public, anon;
grant execute on function warcastle_enter_tracker(uuid, uuid, jsonb) to authenticated;
