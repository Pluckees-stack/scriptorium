-- ============================================================================
-- 075_notifications.sql
--
-- Automatic updates for players, shown under the bell alongside
-- announcements. Everything is written by the database itself (triggers
-- below), never by the app, so nobody can post fake ones.
--
-- 1. notifications: one row per player per update. Players can read, mark
--    read and delete their own; nobody inserts directly.
-- 2. players.fun_notifications: the Account settings switch for the
--    chatty extras (overtakes, streaks, giant-killers). On by default.
-- 3. standings_snapshot: each campaign's last-known ranks and leaders, so
--    a newly confirmed battle can be compared against them.
-- 4. Triggers:
--    - a phase going live            -> everyone in the campaign
--    - a battle logged against you   -> you ("waiting for you to confirm")
--    - your battle confirmed/disputed -> whoever logged it
--    - a battle confirmed (any route: the opponent, an organiser, or a
--      manual entry) ->
--        new leading player / faction / alliance  -> everyone
--        your new rank (both players)             -> the two players
--        Battlefield Losses / Death & Dishonour   -> the unit's owner
--        fun: someone overtook you, a win streak, beating the leader
--
-- Not covered yet: unit XP (it also changes by hand, which shouldn't ping),
-- and "phase ending soon" (phases have no end date).
--
-- To undo:
--   drop trigger if exists notify_phase_live on campaign_phases;
--   drop trigger if exists notify_game_logged on games;
--   drop trigger if exists notify_game_confirmed on games;
--   drop function if exists notify_phase_live_trg(), notify_game_logged_trg(),
--     notify_game_confirmed_trg(), notify_standings_after_battle(uuid, bigint),
--     notify_user(uuid, uuid, text, text, text, boolean),
--     notify_campaign(uuid, text, text, text, boolean, uuid[]);
--   drop table if exists notifications, standings_snapshot;
--   alter table players drop column if exists fun_notifications;
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table players add column if not exists fun_notifications boolean not null default true;

create table if not exists notifications (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references players(id) on delete cascade,
  campaign_id  uuid references campaigns(id) on delete cascade,
  kind         text not null,
  title        text not null,
  body         text,
  fun          boolean not null default false,
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);
create index if not exists notifications_user_idx on notifications (user_id, created_at desc);
alter table notifications enable row level security;

drop policy if exists "players read their own notifications" on notifications;
create policy "players read their own notifications" on notifications
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "players mark their own notifications read" on notifications;
create policy "players mark their own notifications read" on notifications
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "players clear their own notifications" on notifications;
create policy "players clear their own notifications" on notifications
  for delete to authenticated using (user_id = (select auth.uid()));
-- only read_at may change
grant select, delete on notifications to authenticated;
revoke update on notifications from authenticated;
grant update (read_at) on notifications to authenticated;

create table if not exists standings_snapshot (
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  key          text not null,   -- 'rank:<user id>', 'leader:player', 'leader:faction', 'leader:alliance'
  value        text,
  primary key (campaign_id, key)
);
alter table standings_snapshot enable row level security;  -- no policies: internal only

-- ---- helpers ---------------------------------------------------------------

create or replace function notify_user(p_user uuid, p_campaign uuid, p_kind text, p_title text, p_body text, p_fun boolean default false)
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, campaign_id, kind, title, body, fun)
  select p_user, p_campaign, p_kind, p_title, p_body, p_fun
   where p_user is not null
     and (not p_fun or coalesce((select fun_notifications from players where id = p_user), true));
$$;

create or replace function notify_campaign(p_campaign uuid, p_kind text, p_title text, p_body text, p_fun boolean default false, p_except uuid[] default '{}')
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, campaign_id, kind, title, body, fun)
  select cm.user_id, p_campaign, p_kind, p_title, p_body, p_fun
    from campaign_members cm
    join players p on p.id = cm.user_id
   where cm.campaign_id = p_campaign
     and not (cm.user_id = any (p_except))
     and (not p_fun or p.fun_notifications);
$$;

revoke all on function notify_user(uuid, uuid, text, text, text, boolean) from public, anon, authenticated;
revoke all on function notify_campaign(uuid, text, text, text, boolean, uuid[]) from public, anon, authenticated;

create or replace function scriptorium_ordinal(n bigint)
returns text language sql immutable as $$
  select n || case when n % 100 in (11, 12, 13) then 'th'
                   when n % 10 = 1 then 'st' when n % 10 = 2 then 'nd' when n % 10 = 3 then 'rd'
                   else 'th' end;
$$;

create or replace function scriptorium_faction_label(slug text)
returns text language sql immutable as $$
  select replace(replace(replace(initcap(replace(coalesce(slug, ''), '-', ' ')), ' Of ', ' of '), ' And ', ' and '), ' The ', ' the ');
$$;

-- ---- phase goes live -------------------------------------------------------

create or replace function notify_phase_live_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' and old.status is distinct from 'active' then
    perform notify_campaign(new.campaign_id, 'phase_live',
      new.name || ' is live',
      coalesce('You can play up to ' || new.max_games || ' battles in this phase. ', '') || 'Check the Game view for its scenarios.');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_phase_live on campaign_phases;
create trigger notify_phase_live after update of status on campaign_phases
  for each row execute function notify_phase_live_trg();

-- ---- a battle logged against you -------------------------------------------

create or replace function notify_game_logged_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_logger text;
begin
  if new.confirmation_status = 'pending' and new.opponent_id is not null then
    select display_name into v_logger from players where id = new.player_id;
    perform notify_user(new.opponent_id, new.campaign_id, 'confirm_battle',
      coalesce(v_logger, 'Your opponent') || ' logged your battle',
      'It''s waiting for you to confirm the result in the Game view.');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_game_logged on games;
create trigger notify_game_logged after insert on games
  for each row execute function notify_game_logged_trg();

-- ---- standings after a confirmed battle ------------------------------------

create or replace function notify_standings_after_battle(p_campaign uuid, p_game bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_first   boolean := not exists (select 1 from standings_snapshot where campaign_id = p_campaign);
  v_game    games%rowtype;
  v_winner  uuid;
  v_loser   uuid;
  v_name    text;
  v_loser_name text;
  v_old     text;
  v_new     text;
  v_label   text;
  v_streak  int;
  r         record;
begin
  select * into v_game from games where id = p_game;

  -- current ranks (ties share a rank)
  create temporary table if not exists _ranks (user_id uuid primary key, rank bigint, old_rank bigint, display_name text) on commit drop;
  truncate _ranks;
  insert into _ranks (user_id, rank, display_name)
  select id, rank() over (order by campaign_points desc), display_name
    from player_standings where campaign_id = p_campaign;
  update _ranks k set old_rank = s.value::bigint
    from standings_snapshot s
   where s.campaign_id = p_campaign and s.key = 'rank:' || k.user_id;

  if not v_first then
    -- the two players: their new place
    for r in select * from _ranks where user_id in (v_game.player_id, v_game.opponent_id) and old_rank is not null and rank <> old_rank loop
      perform notify_user(r.user_id, p_campaign, 'rank',
        'You''re now ' || scriptorium_ordinal(r.rank) || ' in the standings',
        case when r.rank < r.old_rank then 'Up ' || (r.old_rank - r.rank) else 'Down ' || (r.rank - r.old_rank) end
          || ' from ' || scriptorium_ordinal(r.old_rank) || '.');
    end loop;
    -- fun: who they overtook
    for r in
      select o.user_id, o.rank, string_agg(p.display_name, ' and ' order by p.display_name) as passer, count(*) as n
        from _ranks o
        join _ranks p on p.user_id in (v_game.player_id, v_game.opponent_id)
       where o.user_id not in (v_game.player_id, v_game.opponent_id)
         and o.old_rank is not null and p.old_rank is not null
         and p.old_rank > o.old_rank and p.rank < o.rank
       group by o.user_id, o.rank
    loop
      perform notify_user(r.user_id, p_campaign, 'overtaken',
        r.passer || ' just passed you',
        'You''re now ' || scriptorium_ordinal(r.rank) || ' in the standings.', true);
    end loop;
  end if;

  -- leaders: player, faction, alliance (only when one is clearly ahead)
  select case when count(*) = 1 then max(display_name) end into v_new from _ranks where rank = 1;
  select value into v_old from standings_snapshot where campaign_id = p_campaign and key = 'leader:player';
  if not v_first and v_new is not null and v_new is distinct from v_old then
    perform notify_campaign(p_campaign, 'leader_player', v_new || ' leads the campaign',
      coalesce('Taking the top spot from ' || v_old || '.', 'First place in the standings.'), false,
      array(select user_id from _ranks where rank = 1));
  end if;
  insert into standings_snapshot values (p_campaign, 'leader:player', v_new)
    on conflict (campaign_id, key) do update set value = excluded.value;

  select max(faction_id) into v_new from (
    select faction_id, sum(campaign_points) pts, rank() over (order by sum(campaign_points) desc) rk
      from player_standings where campaign_id = p_campaign and faction_id is not null
     group by faction_id) f
   where rk = 1 having count(*) = 1;
  select value into v_old from standings_snapshot where campaign_id = p_campaign and key = 'leader:faction';
  if not v_first and v_new is not null and v_new is distinct from v_old then
    perform notify_campaign(p_campaign, 'leader_faction', scriptorium_faction_label(v_new) || ' take the lead',
      coalesce('Overtaking ' || scriptorium_faction_label(v_old) || ' as the leading faction.', 'The leading faction in the campaign.'));
  end if;
  insert into standings_snapshot values (p_campaign, 'leader:faction', v_new)
    on conflict (campaign_id, key) do update set value = excluded.value;

  select max(name) into v_new from (
    select name, rank() over (order by campaign_points desc) rk from alliance_standings where campaign_id = p_campaign) a
   where rk = 1 having count(*) = 1;
  select value into v_old from standings_snapshot where campaign_id = p_campaign and key = 'leader:alliance';
  if not v_first and v_new is not null and v_new is distinct from v_old then
    perform notify_campaign(p_campaign, 'leader_alliance', v_new || ' lead the alliances',
      coalesce('Pushing ' || v_old || ' into second.', 'The leading alliance in the campaign.'));
  end if;
  insert into standings_snapshot values (p_campaign, 'leader:alliance', v_new)
    on conflict (campaign_id, key) do update set value = excluded.value;

  -- fun: giant-killer and win streaks
  if v_game.opponent_id is not null and v_game.result <> 'draw' then
    v_winner := case when v_game.result = 'win' then v_game.player_id else v_game.opponent_id end;
    v_loser  := case when v_game.result = 'win' then v_game.opponent_id else v_game.player_id end;
    select display_name into v_name from _ranks where user_id = v_winner;
    select display_name into v_loser_name from _ranks where user_id = v_loser;
    if not v_first and (select old_rank from _ranks where user_id = v_loser) = 1
       and coalesce((select old_rank from _ranks where user_id = v_winner), 2) > 1 then
      perform notify_campaign(p_campaign, 'giant_killer', 'Giant-killer!',
        v_name || ' has beaten the campaign leader, ' || v_loser_name || '.', true, array[v_winner, v_loser]);
    end if;
    select count(*) into v_streak from (
      select result, row_number() over (order by game_id desc) n,
             sum(case when result <> 'win' then 1 else 0 end) over (order by game_id desc rows unbounded preceding) losses_so_far
        from game_credits where campaign_id = p_campaign and user_id = v_winner) g
     where losses_so_far = 0;
    if v_streak in (3, 5, 10) then
      perform notify_campaign(p_campaign, 'streak', v_name || ' is on a streak',
        v_streak || ' wins in a row.', true, array[v_winner]);
      perform notify_user(v_winner, p_campaign, 'streak', v_streak || ' wins in a row', 'Keep it going.', true);
    end if;
  end if;

  -- remember the new ranks
  insert into standings_snapshot (campaign_id, key, value)
  select p_campaign, 'rank:' || user_id, rank::text from _ranks
  on conflict (campaign_id, key) do update set value = excluded.value;
end;
$$;
revoke all on function notify_standings_after_battle(uuid, bigint) from public, anon, authenticated;

-- ---- a battle confirmed (or disputed) --------------------------------------

create or replace function notify_game_confirmed_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_opp text;
  v_ptg boolean;
  o     jsonb;
  v_unit text;
  v_owner uuid;
begin
  if tg_op = 'UPDATE' and new.confirmation_status is not distinct from old.confirmation_status then
    return new;
  end if;

  if new.confirmation_status = 'disputed' then
    select display_name into v_opp from players where id = new.opponent_id;
    perform notify_user(new.player_id, new.campaign_id, 'battle_disputed',
      coalesce(v_opp, 'Your opponent') || ' disputed your battle',
      coalesce('Reason: ' || nullif(new.dispute_reason, '') || '. ', '') || 'An organiser will sort it out.');
    return new;
  end if;

  if new.confirmation_status <> 'confirmed' then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.opponent_id is not null then
    select display_name into v_opp from players where id = new.opponent_id;
    if auth.uid() is not distinct from new.opponent_id then
      perform notify_user(new.player_id, new.campaign_id, 'battle_confirmed',
        'Battle confirmed', coalesce(v_opp, 'Your opponent') || ' confirmed the result. It now counts in the standings.');
    else
      -- confirmed by an organiser: tell both sides
      perform notify_user(new.player_id, new.campaign_id, 'battle_confirmed',
        'Battle confirmed', 'An organiser confirmed your battle against ' || coalesce(v_opp, 'your opponent') || '. It now counts in the standings.');
      perform notify_user(new.opponent_id, new.campaign_id, 'battle_confirmed',
        'Battle confirmed', 'An organiser confirmed your battle against ' || coalesce((select display_name from players where id = new.player_id), 'your opponent') || '. It now counts in the standings.');
    end if;
  end if;

  -- Battlefield Losses / Death & Dishonour rolls, for Path to Glory campaigns
  select path_to_glory_enabled into v_ptg from campaigns where id = new.campaign_id;
  if coalesce(v_ptg, false) then
    for o in
      select x from jsonb_array_elements(coalesce(new.own_unit_outcomes, '[]'::jsonb)) x
      union all
      select x from jsonb_array_elements(coalesce(new.opponent_unit_outcomes, '[]'::jsonb)) x
    loop
      select coalesce(u.nickname, u.name), r.player_id into v_unit, v_owner
        from units u join rosters r on r.id = u.roster_id
       where u.id = (o->>'unitId')::bigint;
      if v_owner is not null then
        perform notify_user(v_owner, new.campaign_id, 'loss_roll',
          'Roll for ' || v_unit,
          'After your last battle, ' || v_unit || ' needs a ' ||
          case when exists (select 1 from units where id = (o->>'unitId')::bigint and category = 'characters')
               then 'Death & Dishonour' else 'Battlefield Losses' end || ' roll. Open it on the Muster list tab.');
      end if;
    end loop;
  end if;

  perform notify_standings_after_battle(new.campaign_id, new.id);
  return new;
end;
$$;
drop trigger if exists notify_game_confirmed on games;
create trigger notify_game_confirmed after insert or update of confirmation_status on games
  for each row execute function notify_game_confirmed_trg();
