-- ============================================================================
-- 093_players_admin.sql
--
-- Everything about players on the organiser's Players tab (admin console
-- PR B):
--
-- 1. campaigns.lists_locked: lists can't change once the organiser locks
--    them (separate from rosters_locked, which despite its name means the
--    lists are revealed to everyone, 040). While locked, players can't add or
--    replace a roster or add or delete units; organisers and platform admins
--    still can. Updates (XP, wounds and so on) aren't touched.
-- 2. campaign_member_admin: the organiser's own notes on each player: a list
--    marked checked, checked in on the day, and a private note. Organisers
--    and platform admins only; players never see it.
-- 3. campaign_waitlist: a full event puts new joiners on a waiting list
--    (join_campaign_by_code now answers 'waitlisted', with their place).
--    When a place opens up, the first in line is added and notified, as
--    long as the event is open, entrants aren't locked and check-in hasn't
--    started (on the day, a free place shouldn't go to someone who isn't
--    there).
-- 4. drop_out_of_event: a player leaves an event themselves, before its
--    entrants are locked (afterwards the organiser withdraws them).
-- 5. find_players_to_add / add_campaign_member: an organiser adds someone
--    who already has a Scriptorium account, past the player cap if need be.
--
-- To undo:
--   drop trigger if exists campaign_waitlist_promote on campaign_members;
--   drop function if exists campaign_waitlist_promote_trg();
--   drop trigger if exists rosters_lists_locked on rosters;
--   drop trigger if exists units_lists_locked on units;
--   drop function if exists lists_locked_guard_trg();
--   drop function if exists drop_out_of_event(uuid), my_waitlist();
--   drop function if exists find_players_to_add(uuid, text);
--   drop function if exists add_campaign_member(uuid, uuid);
--   drop table if exists campaign_waitlist, campaign_member_admin;
--   alter table campaigns drop column if exists lists_locked;
--   then re-run join_campaign_by_code from 088.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. locking lists
-- ----------------------------------------------------------------------------
alter table campaigns add column if not exists lists_locked boolean not null default false;
comment on column campaigns.lists_locked is 'Lists locked by the organiser: players can''t add or replace a roster or add or delete units (organisers and platform admins still can). Not the same as rosters_locked, which means lists are revealed (040).';

create or replace function lists_locked_guard_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_campaign uuid := case when tg_op = 'DELETE' then old.campaign_id else new.campaign_id end;
begin
  if v_campaign is not null and auth.uid() is not null
     and exists (select 1 from campaigns where id = v_campaign and lists_locked)
     and not (is_campaign_organiser(v_campaign) or is_platform_admin()) then
    raise exception 'Lists are locked for this event. Ask the organiser if something needs changing.';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
drop trigger if exists rosters_lists_locked on rosters;
create trigger rosters_lists_locked before insert or delete on rosters
  for each row execute function lists_locked_guard_trg();
drop trigger if exists units_lists_locked on units;
create trigger units_lists_locked before insert or delete on units
  for each row execute function lists_locked_guard_trg();

-- ----------------------------------------------------------------------------
-- 2. the organiser's notes on each player
-- ----------------------------------------------------------------------------
create table if not exists campaign_member_admin (
  campaign_id      uuid not null references campaigns(id) on delete cascade,
  user_id          uuid not null references players(id) on delete cascade,
  list_checked_at  timestamptz,
  checked_in_at    timestamptz,
  note             text check (note is null or length(note) <= 500),
  updated_at       timestamptz not null default now(),
  primary key (campaign_id, user_id)
);
alter table campaign_member_admin enable row level security;
drop policy if exists "organisers manage member notes" on campaign_member_admin;
create policy "organisers manage member notes" on campaign_member_admin
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ----------------------------------------------------------------------------
-- 3. the waiting list
-- ----------------------------------------------------------------------------
create table if not exists campaign_waitlist (
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  user_id      uuid not null references players(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (campaign_id, user_id)
);
create index if not exists campaign_waitlist_order_idx on campaign_waitlist (campaign_id, created_at);
alter table campaign_waitlist enable row level security;
drop policy if exists "see your own place or your event's list" on campaign_waitlist;
create policy "see your own place or your event's list" on campaign_waitlist
  for select to authenticated
  using (user_id = (select auth.uid()) or is_campaign_organiser(campaign_id) or is_platform_admin());
drop policy if exists "leave the list, or organisers take people off" on campaign_waitlist;
create policy "leave the list, or organisers take people off" on campaign_waitlist
  for delete to authenticated
  using (user_id = (select auth.uid()) or is_campaign_organiser(campaign_id) or is_platform_admin());
-- no insert or update policies: joining goes through join_campaign_by_code

-- join_campaign_by_code, as in 088, but a full event puts you on the
-- waiting list ('waitlisted', with your place) instead of turning you away
create or replace function join_campaign_by_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_norm text := normalise_join_code(p_code);
  v_c campaigns%rowtype;
  v_count integer;
  v_place integer;
begin
  if v_uid is null then raise exception 'Sign in first.'; end if;

  delete from join_code_attempts where user_id = v_uid and attempted_at < now() - interval '1 day';
  if (select count(*) from join_code_attempts where user_id = v_uid and attempted_at > now() - interval '15 minutes') >= 10 then
    return jsonb_build_object('status', 'too_many_tries');
  end if;

  -- an exact match first, then the forgiving one
  select * into v_c from campaigns
   where format <> 'open' and upper(join_code) = upper(trim(coalesce(p_code, '')))
   limit 1;
  if not found and length(v_norm) >= 4 then
    select * into v_c from campaigns
     where format <> 'open' and normalise_join_code(join_code) = v_norm
     order by created_at limit 1;
  end if;
  if not found then
    insert into join_code_attempts (user_id) values (v_uid);
    return jsonb_build_object('status', 'not_found');
  end if;

  if exists (select 1 from campaign_members where campaign_id = v_c.id and user_id = v_uid) then
    return jsonb_build_object('status', 'already_member', 'campaign_id', v_c.id, 'name', v_c.name);
  end if;
  if v_c.status = 'draft' then
    return jsonb_build_object('status', 'not_open');
  end if;
  if v_c.status <> 'active' then
    return jsonb_build_object('status', 'ended', 'name', v_c.name);
  end if;

  -- the player cap (059); lock the campaign so two people can't take the last place
  perform 1 from campaigns where id = v_c.id for update;
  if v_c.player_cap is not null and not is_platform_admin() then
    select count(*) into v_count from campaign_members where campaign_id = v_c.id;
    if v_count >= v_c.player_cap then
      insert into campaign_waitlist (campaign_id, user_id) values (v_c.id, v_uid)
      on conflict (campaign_id, user_id) do nothing;
      select count(*) into v_place from campaign_waitlist w
       where w.campaign_id = v_c.id
         and w.created_at <= (select created_at from campaign_waitlist where campaign_id = v_c.id and user_id = v_uid);
      return jsonb_build_object('status', 'waitlisted', 'campaign_id', v_c.id, 'name', v_c.name, 'place', v_place);
    end if;
  end if;

  insert into campaign_members (user_id, campaign_id, role)
  values (v_uid, v_c.id, 'player')
  on conflict (user_id, campaign_id) do nothing;
  delete from campaign_waitlist where campaign_id = v_c.id and user_id = v_uid;

  return jsonb_build_object('status', 'joined', 'campaign_id', v_c.id, 'name', v_c.name);
end;
$$;
revoke all on function join_campaign_by_code(text) from public, anon;
grant execute on function join_campaign_by_code(text) to authenticated;

-- a place opening up goes to the first in line
create or replace function campaign_waitlist_promote_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_c campaigns%rowtype;
  v_next uuid;
begin
  select * into v_c from campaigns where id = old.campaign_id;
  if not found or v_c.status <> 'active' or v_c.player_cap is null then return null; end if;
  -- too late to bring someone in: entrants locked, or check-in under way
  if exists (select 1 from tournaments where campaign_id = v_c.id and entrants_locked_at is not null) then return null; end if;
  if exists (select 1 from campaign_member_admin where campaign_id = v_c.id and checked_in_at is not null) then return null; end if;
  if (select count(*) from campaign_members where campaign_id = v_c.id) >= v_c.player_cap then return null; end if;

  select user_id into v_next from campaign_waitlist
   where campaign_id = v_c.id order by created_at limit 1 for update skip locked;
  if v_next is null then return null; end if;
  delete from campaign_waitlist where campaign_id = v_c.id and user_id = v_next;
  insert into campaign_members (user_id, campaign_id, role) values (v_next, v_c.id, 'player')
  on conflict (user_id, campaign_id) do nothing;
  perform notify_user(v_next, v_c.id, 'waitlist', 'You''re in',
    format('A place opened up in %s, and it''s yours.', v_c.name));
  return null;
end;
$$;
drop trigger if exists campaign_waitlist_promote on campaign_members;
create trigger campaign_waitlist_promote after delete on campaign_members
  for each row execute function campaign_waitlist_promote_trg();

-- ----------------------------------------------------------------------------
-- 4. dropping out
-- ----------------------------------------------------------------------------
create or replace function drop_out_of_event(p_campaign uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then raise exception 'Sign in first.'; end if;
  select role into v_role from campaign_members where campaign_id = p_campaign and user_id = v_uid;
  if not found then raise exception 'You''re not in this event.'; end if;
  if v_role = 'organiser' then
    raise exception 'Organisers can''t drop out. Make someone else an organiser first, or end the event.';
  end if;
  if exists (select 1 from tournaments where campaign_id = p_campaign and entrants_locked_at is not null) then
    raise exception 'The entrants are locked, so the organiser needs to withdraw you. Let them know.';
  end if;
  delete from campaign_members where campaign_id = p_campaign and user_id = v_uid;
end;
$$;
revoke all on function drop_out_of_event(uuid) from public, anon;
grant execute on function drop_out_of_event(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 5. adding a player by hand
-- ----------------------------------------------------------------------------
create or replace function find_players_to_add(p_campaign uuid, p_query text)
returns table (id uuid, display_name text) language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser of this event can add players.';
  end if;
  if length(trim(coalesce(p_query, ''))) < 2 then return; end if;
  return query
    select p.id, p.display_name from players p
     where p.display_name ilike '%' || replace(replace(trim(p_query), '%', ''), '_', '') || '%'
       and not exists (select 1 from campaign_members m where m.campaign_id = p_campaign and m.user_id = p.id)
     order by p.display_name limit 10;
end;
$$;
revoke all on function find_players_to_add(uuid, text) from public, anon;
grant execute on function find_players_to_add(uuid, text) to authenticated;

create or replace function add_campaign_member(p_campaign uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser of this event can add players.';
  end if;
  if not exists (select 1 from players where id = p_user) then raise exception 'That player doesn''t exist.'; end if;
  insert into campaign_members (user_id, campaign_id, role) values (p_user, p_campaign, 'player')
  on conflict (user_id, campaign_id) do nothing;
  delete from campaign_waitlist where campaign_id = p_campaign and user_id = p_user;
  perform notify_user(p_user, p_campaign, 'added', 'You''ve been added to an event',
    format('An organiser added you to %s.', (select name from campaigns where id = p_campaign)));
end;
$$;
revoke all on function add_campaign_member(uuid, uuid) from public, anon;
grant execute on function add_campaign_member(uuid, uuid) to authenticated;

-- your places on waiting lists, with each event's name (you can't read an
-- event you're not in yet)
create or replace function my_waitlist()
returns table (campaign_id uuid, name text, place integer) language sql stable security definer set search_path = public as $$
  select w.campaign_id, c.name,
         (select count(*)::integer from campaign_waitlist x where x.campaign_id = w.campaign_id and x.created_at <= w.created_at)
    from campaign_waitlist w join campaigns c on c.id = w.campaign_id
   where w.user_id = auth.uid()
   order by w.created_at;
$$;
revoke all on function my_waitlist() from public, anon;
grant execute on function my_waitlist() to authenticated;
