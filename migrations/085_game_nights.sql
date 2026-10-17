-- ============================================================================
-- 085_game_nights.sql
--
-- Game nights and table booking. An organiser lists the campaign's gaming
-- nights and tournament days (date and time, venue, how many tables, the
-- shop's ticket link). Players book a place, optionally naming who they
-- want to play; once the tables are full, later bookings join a waiting
-- list and move up in order when someone cancels. Organisers number the
-- tables and tick off who has bought a ticket.
--
-- Tickets are still bought in the venue's own shop: Scriptorium links to
-- the night's ticket and never takes payment.
--
-- game_nights          one gaming night or tournament day in a campaign
-- game_night_bookings  one player's place (or waiting-list spot) on a night
--
-- Players book and cancel only through book_game_night() and
-- cancel_game_night_booking() below, which lock the night while counting
-- so two people can't take the last table at once. Organisers edit
-- bookings directly (table numbers, paid, moving people on or off the
-- waiting list).
--
-- Run before merging the game nights index.html.
--
-- To undo:
--   drop function if exists book_game_night(uuid, uuid, text);
--   drop function if exists cancel_game_night_booking(uuid);
--   drop table if exists game_night_bookings;
--   drop table if exists game_nights;
-- ============================================================================

create table if not exists game_nights (
  id                uuid primary key default gen_random_uuid(),
  campaign_id       uuid not null references campaigns(id) on delete cascade,
  title             text not null check (length(title) between 1 and 120),
  starts_at         timestamptz not null,
  ends_at           timestamptz,
  venue             text check (venue is null or length(venue) <= 120),
  tables            integer not null default 8 check (tables between 1 and 200),
  players_per_table integer not null default 2 check (players_per_table in (2, 4)),
  points            integer check (points is null or points between 100 and 10000),
  ticket_url        text check (ticket_url is null or ticket_url ~ '^https://'),
  price_text        text check (price_text is null or length(price_text) <= 30),
  notes             text check (notes is null or length(notes) <= 1000),
  phase_id          uuid references campaign_phases(id) on delete set null,
  booking_closes_at timestamptz,
  created_by        uuid references players(id) on delete set null,
  created_at        timestamptz not null default now()
);

comment on table game_nights is 'A campaign gaming night or tournament day players can book a table for. players_per_table is 4 for doubles. ticket_url links to the venue''s own shop; Scriptorium never takes payment.';

create index if not exists game_nights_campaign_starts_idx on game_nights (campaign_id, starts_at);

create table if not exists game_night_bookings (
  id           uuid primary key default gen_random_uuid(),
  night_id     uuid not null references game_nights(id) on delete cascade,
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  player_id    uuid not null references players(id) on delete cascade,
  partner_id   uuid references players(id) on delete set null,
  status       text not null default 'booked' check (status in ('booked', 'waitlist', 'cancelled')),
  table_number integer check (table_number is null or table_number between 1 and 200),
  paid         boolean not null default false,
  note         text check (note is null or length(note) <= 200),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (night_id, player_id)
);

comment on table game_night_bookings is 'partner_id is who the player would like to play (or partner, on a doubles night) -- a wish the organiser uses when numbering tables. paid is ticked by the organiser once the shop ticket is bought. campaign_id is denormalised from game_nights for RLS.';

create index if not exists game_night_bookings_night_idx on game_night_bookings (night_id, status, created_at);
create index if not exists game_night_bookings_player_idx on game_night_bookings (player_id);

alter table game_nights enable row level security;
alter table game_night_bookings enable row level security;

drop policy if exists "campaign members read game nights" on game_nights;
create policy "campaign members read game nights" on game_nights
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "organisers manage game nights" on game_nights;
create policy "organisers manage game nights" on game_nights
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- everyone in the campaign sees who's coming (and how many tables are left)
drop policy if exists "campaign members read bookings" on game_night_bookings;
create policy "campaign members read bookings" on game_night_bookings
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "organisers manage bookings" on game_night_bookings;
create policy "organisers manage bookings" on game_night_bookings
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ----------------------------------------------------------------------------
-- book_game_night: book a place, or join the waiting list when it's full.
-- Booking again (to change who you'd like to play, or to come back after
-- cancelling) updates your one booking. Returns 'booked' or 'waitlist'.
-- ----------------------------------------------------------------------------
create or replace function book_game_night(p_night uuid, p_partner uuid default null, p_note text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_night game_nights%rowtype;
  v_mine game_night_bookings%rowtype;
  v_taken integer;
  v_status text;
begin
  -- lock the night so two people can't take the last place at once
  select * into v_night from game_nights where id = p_night for update;
  if not found then raise exception 'That game night doesn''t exist.'; end if;
  if not is_campaign_member(v_night.campaign_id) then raise exception 'You''re not in this campaign.'; end if;
  if v_night.starts_at < now() - interval '6 hours' then raise exception 'That game night has already happened.'; end if;
  if v_night.booking_closes_at is not null and now() > v_night.booking_closes_at then raise exception 'Booking for that night has closed.'; end if;
  if p_partner is not null and (p_partner = auth.uid() or not exists (
       select 1 from campaign_members where campaign_id = v_night.campaign_id and user_id = p_partner)) then
    raise exception 'Pick someone else in this campaign to play.';
  end if;

  select * into v_mine from game_night_bookings where night_id = p_night and player_id = auth.uid();
  if found and v_mine.status in ('booked', 'waitlist') then
    -- already in: just update who they'd like to play and their note
    update game_night_bookings set partner_id = p_partner, note = nullif(trim(p_note), ''), updated_at = now()
     where id = v_mine.id;
    return v_mine.status;
  end if;

  select count(*) into v_taken from game_night_bookings where night_id = p_night and status = 'booked';
  v_status := case when v_taken < v_night.tables * v_night.players_per_table then 'booked' else 'waitlist' end;

  insert into game_night_bookings (night_id, campaign_id, player_id, partner_id, status, note)
  values (p_night, v_night.campaign_id, auth.uid(), p_partner, v_status, nullif(trim(p_note), ''))
  on conflict (night_id, player_id) do update
    set partner_id = excluded.partner_id, status = excluded.status, note = excluded.note,
        table_number = null, created_at = now(), updated_at = now();

  -- let the person they named know
  if p_partner is not null then
    perform notify_user(p_partner, v_night.campaign_id, 'game_night',
      'Someone wants a battle with you',
      (select display_name from players where id = auth.uid()) || ' has booked ' || v_night.title || ' on ' ||
        to_char(v_night.starts_at at time zone 'Europe/London', 'FMDy FMDD FMMon') || ' and would like to play you.');
  end if;
  return v_status;
end;
$$;

-- ----------------------------------------------------------------------------
-- cancel_game_night_booking: give up your place; the first person on the
-- waiting list takes it and is told.
-- ----------------------------------------------------------------------------
create or replace function cancel_game_night_booking(p_night uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_night game_nights%rowtype;
  v_next game_night_bookings%rowtype;
begin
  select * into v_night from game_nights where id = p_night for update;
  if not found then raise exception 'That game night doesn''t exist.'; end if;

  update game_night_bookings set status = 'cancelled', table_number = null, updated_at = now()
   where night_id = p_night and player_id = auth.uid() and status in ('booked', 'waitlist');
  if not found then return; end if;

  -- a place has come free: the longest-waiting player gets it
  if (select count(*) from game_night_bookings where night_id = p_night and status = 'booked')
       < v_night.tables * v_night.players_per_table then
    select * into v_next from game_night_bookings
     where night_id = p_night and status = 'waitlist' order by created_at limit 1 for update;
    if found then
      update game_night_bookings set status = 'booked', updated_at = now() where id = v_next.id;
      perform notify_user(v_next.player_id, v_night.campaign_id, 'game_night',
        'You''re off the waiting list',
        'A table has come free for ' || v_night.title || ' on ' ||
          to_char(v_night.starts_at at time zone 'Europe/London', 'FMDy FMDD FMMon') || '. You''re booked in.');
    end if;
  end if;
end;
$$;

revoke all on function book_game_night(uuid, uuid, text) from public, anon;
revoke all on function cancel_game_night_booking(uuid) from public, anon;
grant execute on function book_game_night(uuid, uuid, text) to authenticated;
grant execute on function cancel_game_night_booking(uuid) to authenticated;
