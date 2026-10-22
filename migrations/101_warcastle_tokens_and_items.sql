-- ============================================================================
-- 101_warcastle_tokens_and_items.sql
--
-- WarCastle's Supply and Warpstone tokens and the magic items players buy
-- with them (warcastle-brief.md; the rules as Grant set them, 22 Oct):
--
--   - Controlling a Strategic Objective at the end of a battle gains 3
--     Supply; the one Warpstone Shard on a table gains a Warpstone token
--     instead (the organiser swaps 3 Supply for it).
--   - Supply buys a Common magic item: 1 for up to 15 points, 2 up to 35,
--     3 up to 50. A Warpstone token buys one item from the faction's list;
--     a Warpstone and 3 Supply, a Common item up to 100 points.
--   - Tokens keep, and players can send them to one another (the sender
--     confirms; the other player is told who sent them).
--
-- 1. warcastle_tokens: every token given, swapped, sent, received or spent,
--    one row each (amount is + or -). A player's tokens are the sum.
--    Players read their own; organisers read all and can delete a row (an
--    undo). Rows are only written through the functions below.
-- 2. warcastle_items: the items a player has bought, and the unit carrying
--    each (null until it's given to one). Campaign members read them (they
--    show on units). A player gives their own items to their own units;
--    organisers can delete one.
-- 3. warcastle_item_price(points, source): what an item costs, by the rules.
--    warcastle_buy_item(): a player buys one, at that price.
--    warcastle_send_tokens(): a player sends tokens to another.
--    warcastle_grant_tokens(): an organiser awards, swaps or corrects.
--
-- To undo:
--   drop function if exists warcastle_grant_tokens(uuid, uuid, integer, integer, text, text);
--   drop function if exists warcastle_send_tokens(uuid, uuid, integer, integer);
--   drop function if exists warcastle_buy_item(uuid, text, integer, text, text);
--   drop function if exists warcastle_item_price(integer, text);
--   drop function if exists warcastle_token_balance(uuid, uuid, text);
--   drop table if exists warcastle_items;
--   drop table if exists warcastle_tokens;
--
-- Idempotent: safe to re-run. Run after 100.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- warcastle_tokens
-- ---------------------------------------------------------------------------
create table if not exists warcastle_tokens (
  id              uuid primary key default gen_random_uuid(),
  campaign_id     uuid not null references campaigns(id) on delete cascade,
  player_id       uuid not null references players(id) on delete cascade,
  kind            text not null check (kind in ('supply', 'warpstone')),
  amount          integer not null check (amount <> 0),
  reason          text not null check (reason in ('award', 'swap', 'correction', 'sent', 'received', 'spent')),
  note            text check (note is null or length(note) <= 200),
  other_player_id uuid references players(id) on delete set null,
  item_id         uuid,
  created_by      uuid references players(id) on delete set null,
  created_at      timestamptz not null default now()
);

comment on table warcastle_tokens is 'WarCastle: Supply and Warpstone tokens, one row a change (101). A player''s tokens are the sum of amount by kind.';

create index if not exists warcastle_tokens_campaign_player_idx on warcastle_tokens (campaign_id, player_id);

alter table warcastle_tokens enable row level security;

drop policy if exists "players read their own tokens" on warcastle_tokens;
drop policy if exists "organisers undo tokens" on warcastle_tokens;

create policy "players read their own tokens" on warcastle_tokens
  for select to authenticated
  using (player_id = (select auth.uid()) or is_campaign_organiser(campaign_id) or is_platform_admin());

create policy "organisers undo tokens" on warcastle_tokens
  for delete to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

revoke insert, update on warcastle_tokens from authenticated;

-- ---------------------------------------------------------------------------
-- warcastle_items
-- ---------------------------------------------------------------------------
create table if not exists warcastle_items (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  player_id   uuid not null references players(id) on delete cascade,
  name        text not null check (length(trim(name)) between 1 and 120),
  points      integer not null check (points between 0 and 1000),
  source      text not null check (source in ('common', 'faction')),
  type        text,
  unit_id     uuid references units(id) on delete set null,
  created_at  timestamptz not null default now()
);

comment on table warcastle_items is 'WarCastle: the magic items a player has bought with tokens (101), and the unit carrying each (null: not given to one yet).';

create index if not exists warcastle_items_campaign_player_idx on warcastle_items (campaign_id, player_id);

alter table warcastle_items enable row level security;

drop policy if exists "campaign members read magic items" on warcastle_items;
drop policy if exists "players give their items to their units" on warcastle_items;
drop policy if exists "organisers remove magic items" on warcastle_items;

create policy "campaign members read magic items" on warcastle_items
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

-- only to a unit of their own (or back to the store)
create policy "players give their items to their units" on warcastle_items
  for update to authenticated
  using (player_id = (select auth.uid()) and is_campaign_member(campaign_id))
  with check (player_id = (select auth.uid()) and (unit_id is null or exists (
    select 1 from units u join rosters r on r.id = u.roster_id
     where u.id = unit_id and r.player_id = (select auth.uid()) and u.campaign_id = warcastle_items.campaign_id)));

create policy "organisers remove magic items" on warcastle_items
  for delete to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

revoke insert, update on warcastle_items from authenticated;
grant update (unit_id) on warcastle_items to authenticated;

-- ---------------------------------------------------------------------------
-- the functions
-- ---------------------------------------------------------------------------
create or replace function warcastle_token_balance(p_campaign uuid, p_player uuid, p_kind text)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::integer from warcastle_tokens
   where campaign_id = p_campaign and player_id = p_player and kind = p_kind;
$$;
revoke all on function warcastle_token_balance(uuid, uuid, text) from public, anon, authenticated;

-- what an item costs: Common, by its points; the faction's list, a Warpstone
create or replace function warcastle_item_price(p_points integer, p_source text, out supply integer, out warpstone integer)
language plpgsql immutable as $$
begin
  if p_source = 'faction' then supply := 0; warpstone := 1;
  elsif p_source = 'common' and p_points <= 15 then supply := 1; warpstone := 0;
  elsif p_source = 'common' and p_points <= 35 then supply := 2; warpstone := 0;
  elsif p_source = 'common' and p_points <= 50 then supply := 3; warpstone := 0;
  elsif p_source = 'common' and p_points <= 100 then supply := 3; warpstone := 1;
  else raise exception 'No price for that item: Common items go up to 100 points.';
  end if;
end;
$$;
grant execute on function warcastle_item_price(integer, text) to authenticated;

-- a player buys an item, at its price
create or replace function warcastle_buy_item(p_campaign uuid, p_name text, p_points integer, p_source text, p_type text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_price record;
  v_item uuid;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  if not is_campaign_member(p_campaign) then raise exception 'You''re not in this event.'; end if;
  if coalesce((select settings ->> 'template' from campaigns where id = p_campaign), '') <> 'warcastle' then
    raise exception 'Magic items are bought this way only at WarCastle.';
  end if;
  if coalesce(trim(p_name), '') = '' or p_points is null or p_points < 0 then raise exception 'Pick an item.'; end if;
  select * into v_price from warcastle_item_price(p_points, p_source);
  perform pg_advisory_xact_lock(hashtextextended(p_campaign::text || v_me::text, 0));
  if warcastle_token_balance(p_campaign, v_me, 'supply') < v_price.supply then
    raise exception 'Not enough Supply: % needed.', v_price.supply;
  end if;
  if warcastle_token_balance(p_campaign, v_me, 'warpstone') < v_price.warpstone then
    raise exception 'Not enough Warpstone: % needed.', v_price.warpstone;
  end if;
  insert into warcastle_items (campaign_id, player_id, name, points, source, type)
  values (p_campaign, v_me, left(trim(p_name), 120), p_points, p_source, left(p_type, 40))
  returning id into v_item;
  if v_price.supply > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, item_id, created_by)
    values (p_campaign, v_me, 'supply', -v_price.supply, 'spent', left(trim(p_name), 200), v_item, v_me);
  end if;
  if v_price.warpstone > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, item_id, created_by)
    values (p_campaign, v_me, 'warpstone', -v_price.warpstone, 'spent', left(trim(p_name), 200), v_item, v_me);
  end if;
  return v_item;
end;
$$;
revoke all on function warcastle_buy_item(uuid, text, integer, text, text) from public, anon;
grant execute on function warcastle_buy_item(uuid, text, integer, text, text) to authenticated;

-- a player sends tokens to another; they're told who sent them
create or replace function warcastle_send_tokens(p_campaign uuid, p_to uuid, p_supply integer, p_warpstone integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_name text;
  v_what text;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  if not is_campaign_member(p_campaign) then raise exception 'You''re not in this event.'; end if;
  if coalesce((select settings ->> 'template' from campaigns where id = p_campaign), '') <> 'warcastle' then
    raise exception 'Tokens are sent this way only at WarCastle.';
  end if;
  if p_to is null or p_to = v_me then raise exception 'Pick another player.'; end if;
  if not exists (select 1 from campaign_members where campaign_id = p_campaign and user_id = p_to) then
    raise exception 'That player isn''t in this event.';
  end if;
  p_supply := coalesce(p_supply, 0); p_warpstone := coalesce(p_warpstone, 0);
  if p_supply < 0 or p_warpstone < 0 or p_supply + p_warpstone = 0 then raise exception 'Send at least one token.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_campaign::text || v_me::text, 0));
  if warcastle_token_balance(p_campaign, v_me, 'supply') < p_supply then raise exception 'You don''t have that much Supply.'; end if;
  if warcastle_token_balance(p_campaign, v_me, 'warpstone') < p_warpstone then raise exception 'You don''t have that much Warpstone.'; end if;
  if p_supply > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, other_player_id, created_by) values
      (p_campaign, v_me, 'supply', -p_supply, 'sent', p_to, v_me),
      (p_campaign, p_to, 'supply', p_supply, 'received', v_me, v_me);
  end if;
  if p_warpstone > 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, other_player_id, created_by) values
      (p_campaign, v_me, 'warpstone', -p_warpstone, 'sent', p_to, v_me),
      (p_campaign, p_to, 'warpstone', p_warpstone, 'received', v_me, v_me);
  end if;
  select display_name into v_name from players where id = v_me;
  v_what := concat_ws(' and ',
    case when p_supply > 0 then p_supply || ' Supply' end,
    case when p_warpstone > 0 then p_warpstone || ' Warpstone' end);
  perform notify_user(p_to, p_campaign, 'warcastle_tokens', coalesce(v_name, 'A player') || ' sent you ' || v_what, null, false);
end;
$$;
revoke all on function warcastle_send_tokens(uuid, uuid, integer, integer) from public, anon;
grant execute on function warcastle_send_tokens(uuid, uuid, integer, integer) to authenticated;

-- an organiser awards, swaps (3 Supply for a Warpstone) or corrects; the player is told
create or replace function warcastle_grant_tokens(p_campaign uuid, p_player uuid, p_supply integer, p_warpstone integer, p_reason text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_what text;
begin
  if v_me is null then raise exception 'Sign in first.'; end if;
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then raise exception 'Only an organiser of this event can do that.'; end if;
  if p_reason not in ('award', 'swap', 'correction') then raise exception 'Award, swap or correction.'; end if;
  if not exists (select 1 from campaign_members where campaign_id = p_campaign and user_id = p_player) then
    raise exception 'That player isn''t in this event.';
  end if;
  p_supply := coalesce(p_supply, 0); p_warpstone := coalesce(p_warpstone, 0);
  if p_supply = 0 and p_warpstone = 0 then raise exception 'Nothing to change.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_campaign::text || p_player::text, 0));
  if warcastle_token_balance(p_campaign, p_player, 'supply') + p_supply < 0 then raise exception 'They don''t have that much Supply.'; end if;
  if warcastle_token_balance(p_campaign, p_player, 'warpstone') + p_warpstone < 0 then raise exception 'They don''t have that much Warpstone.'; end if;
  if p_supply <> 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, created_by)
    values (p_campaign, p_player, 'supply', p_supply, p_reason, left(p_note, 200), v_me);
  end if;
  if p_warpstone <> 0 then
    insert into warcastle_tokens (campaign_id, player_id, kind, amount, reason, note, created_by)
    values (p_campaign, p_player, 'warpstone', p_warpstone, p_reason, left(p_note, 200), v_me);
  end if;
  v_what := case
    when p_reason = 'swap' then 'Your Supply became a Warpstone token'
    else concat_ws(', ',
      case when p_supply <> 0 then (case when p_supply > 0 then '+' else '' end) || p_supply || ' Supply' end,
      case when p_warpstone <> 0 then (case when p_warpstone > 0 then '+' else '' end) || p_warpstone || ' Warpstone' end) end;
  perform notify_user(p_player, p_campaign, 'warcastle_tokens', v_what, p_note, false);
end;
$$;
revoke all on function warcastle_grant_tokens(uuid, uuid, integer, integer, text, text) from public, anon;
grant execute on function warcastle_grant_tokens(uuid, uuid, integer, integer, text, text) to authenticated;
