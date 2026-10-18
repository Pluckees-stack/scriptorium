-- ============================================================================
-- 086_battle_safety.sql
--
-- No battle is left open. A battle (a game_invites row) used to stay open
-- for ever if someone walked away from it, which kept two players "locked"
-- together and let stale battles pile up.
--
-- 1. One open battle at a time, enforced here rather than trusted to the
--    app: a player can't send a request while they have another open
--    battle or an unanswered request of their own, can't be sent one while
--    they're in a battle, and can't accept one while in another. Accepting
--    a request withdraws the other requests either player had waiting.
-- 2. leave_battle(): either player ends a battle. Nothing is recorded, and
--    the other player is told.
-- 3. close_battle(): an organiser ends a battle in their campaign; both
--    players are told.
-- 4. tidy_open_battles(): run by the app whenever someone opens the
--    campaign. A battle with no activity for 24 hours, and no result
--    waiting to be confirmed, closes and both players are told. One with
--    no activity for 3 hours is flagged to the campaign's organisers, once.
--    (A battle whose result is already logged is closed too.)
-- 5. last_activity_at: kept up to date on every change to a battle.
-- 6. Organisers can see the battles in their campaign, for Admin's
--    "Battles in progress".
--
-- One-off: battles already idle for more than 24 hours are closed quietly
-- when this runs (no notifications), so the new rules start from a clean
-- slate.
--
-- To undo:
--   drop trigger if exists game_invites_activity on game_invites;
--   drop trigger if exists game_invites_one_open on game_invites;
--   drop trigger if exists game_invites_withdraw_others on game_invites;
--   drop function if exists game_invites_activity_trg();
--   drop function if exists game_invites_one_open_trg();
--   drop function if exists game_invites_withdraw_others_trg();
--   drop function if exists leave_battle(bigint);
--   drop function if exists close_battle(bigint);
--   drop function if exists tidy_open_battles(uuid);
--   drop function if exists my_open_battle();
--   drop policy if exists "organisers read their campaign's battles" on game_invites;
--   alter table game_invites drop column if exists last_activity_at,
--     drop column if exists closed_reason, drop column if exists closed_by,
--     drop column if exists organiser_alerted_at;
-- ============================================================================

alter table game_invites add column if not exists last_activity_at timestamptz not null default now();
alter table game_invites add column if not exists closed_reason text
  check (closed_reason is null or closed_reason in ('left', 'expired', 'organiser', 'withdrawn'));
alter table game_invites add column if not exists closed_by uuid references players(id) on delete set null;
alter table game_invites add column if not exists organiser_alerted_at timestamptz;

comment on column game_invites.closed_reason is 'Why a battle closed without a result: left (a player ended it), expired (24 hours with no activity), organiser (an organiser closed it), withdrawn (a request dropped when either player started another battle).';

-- backfill: the last thing that happened to each battle
update game_invites
   set last_activity_at = greatest(created_at, coalesce(responded_at, created_at), coalesce(from_ready_at, created_at), coalesce(to_ready_at, created_at))
 where last_activity_at >= now() - interval '1 minute';

create index if not exists game_invites_open_idx on game_invites (campaign_id, status) where status in ('pending', 'accepted');

-- ----------------------------------------------------------------------------
-- activity: any change to a battle counts, except the housekeeping below
-- (which sets scriptorium.quiet for its own updates)
-- ----------------------------------------------------------------------------
create or replace function game_invites_activity_trg()
returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('scriptorium.quiet', true), '') <> 'on' then
    new.last_activity_at := now();
  end if;
  return new;
end;
$$;
drop trigger if exists game_invites_activity on game_invites;
create trigger game_invites_activity before update on game_invites
  for each row execute function game_invites_activity_trg();

-- ----------------------------------------------------------------------------
-- one open battle at a time
-- ----------------------------------------------------------------------------
create or replace function game_invites_one_open_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_other game_invites%rowtype;
  v_name text;
begin
  if tg_op = 'INSERT' then
    -- the sender: no battle under way, and no other request of theirs waiting
    select * into v_other from game_invites
     where id <> new.id and status in ('pending', 'accepted')
       and ((status = 'accepted' and (from_user_id = new.from_user_id or to_user_id = new.from_user_id))
         or (status = 'pending' and from_user_id = new.from_user_id))
     limit 1;
    if found then
      select display_name into v_name from players
       where id = case when v_other.from_user_id = new.from_user_id then v_other.to_user_id else v_other.from_user_id end;
      raise exception 'You already have a battle in progress with %. Finish or end it before starting another.', coalesce(v_name, 'another player')
        using errcode = 'P0001', hint = 'open_battle';
    end if;
    -- the person asked: not in the middle of a battle
    if exists (select 1 from game_invites where status = 'accepted' and (from_user_id = new.to_user_id or to_user_id = new.to_user_id)) then
      select display_name into v_name from players where id = new.to_user_id;
      raise exception '% is in another battle right now. Try again once it''s finished.', coalesce(v_name, 'That player')
        using errcode = 'P0001', hint = 'opponent_busy';
    end if;
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    if exists (select 1 from game_invites
                where id <> new.id and status = 'accepted'
                  and (from_user_id in (new.from_user_id, new.to_user_id) or to_user_id in (new.from_user_id, new.to_user_id))) then
      raise exception 'One of you is already in another battle. Finish or end it first.'
        using errcode = 'P0001', hint = 'open_battle';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists game_invites_one_open on game_invites;
create trigger game_invites_one_open before insert or update of status on game_invites
  for each row execute function game_invites_one_open_trg();

-- once a battle is on, any other requests either player had waiting are withdrawn
create or replace function game_invites_withdraw_others_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r game_invites%rowtype;
  v_names text;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select string_agg(display_name, ' and ') into v_names from players where id in (new.from_user_id, new.to_user_id);
    for r in
      select * from game_invites
       where id <> new.id and status = 'pending'
         and (from_user_id in (new.from_user_id, new.to_user_id) or to_user_id in (new.from_user_id, new.to_user_id))
    loop
      update game_invites set status = 'cancelled', closed_reason = 'withdrawn', responded_at = now() where id = r.id;
      perform notify_user(case when r.from_user_id in (new.from_user_id, new.to_user_id) then r.to_user_id else r.from_user_id end,
        r.campaign_id, 'battle', 'Battle request withdrawn', coalesce(v_names, 'They') || ' started a battle, so your request was withdrawn.');
    end loop;
  end if;
  return null;
end;
$$;
drop trigger if exists game_invites_withdraw_others on game_invites;
create trigger game_invites_withdraw_others after update of status on game_invites
  for each row execute function game_invites_withdraw_others_trg();

-- ----------------------------------------------------------------------------
-- leave_battle: either player ends their battle; nothing is recorded
-- ----------------------------------------------------------------------------
create or replace function leave_battle(p_invite bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v game_invites%rowtype;
  v_me text;
  v_other uuid;
begin
  select * into v from game_invites where id = p_invite for update;
  if not found then raise exception 'That battle doesn''t exist.'; end if;
  if auth.uid() not in (v.from_user_id, v.to_user_id) then raise exception 'That isn''t your battle.'; end if;
  if v.status not in ('pending', 'accepted') then return; end if; -- already over
  update game_invites set status = 'cancelled', closed_reason = 'left', closed_by = auth.uid(), responded_at = coalesce(responded_at, now())
   where id = p_invite;
  select display_name into v_me from players where id = auth.uid();
  v_other := case when v.from_user_id = auth.uid() then v.to_user_id else v.from_user_id end;
  perform notify_user(v_other, v.campaign_id, 'battle', 'Battle ended',
    coalesce(v_me, 'Your opponent') || case when v.status = 'pending' then ' withdrew their battle request.' else ' ended your battle. Nothing was recorded for it.' end);
end;
$$;

-- ----------------------------------------------------------------------------
-- close_battle: an organiser ends a battle in their campaign
-- ----------------------------------------------------------------------------
create or replace function close_battle(p_invite bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v game_invites%rowtype;
begin
  select * into v from game_invites where id = p_invite for update;
  if not found then raise exception 'That battle doesn''t exist.'; end if;
  if not (is_campaign_organiser(v.campaign_id) or is_platform_admin()) then raise exception 'Only an organiser can close other players'' battles.'; end if;
  if v.status not in ('pending', 'accepted') then return; end if;
  update game_invites set status = 'cancelled', closed_reason = 'organiser', closed_by = auth.uid(), responded_at = coalesce(responded_at, now())
   where id = p_invite;
  perform notify_user(v.from_user_id, v.campaign_id, 'battle', 'Battle closed by an organiser', 'An organiser closed your open battle. Nothing was recorded for it.');
  perform notify_user(v.to_user_id, v.campaign_id, 'battle', 'Battle closed by an organiser', 'An organiser closed your open battle. Nothing was recorded for it.');
end;
$$;

-- ----------------------------------------------------------------------------
-- tidy_open_battles: the app runs this when anyone opens a campaign
-- ----------------------------------------------------------------------------
create or replace function tidy_open_battles(p_campaign uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  r game_invites%rowtype;
  v_names text;
  v_closed integer := 0;
  v_org record;
begin
  if not (is_campaign_member(p_campaign) or is_platform_admin()) then return 0; end if;
  perform set_config('scriptorium.quiet', 'on', true);

  for r in select * from game_invites where campaign_id = p_campaign and status in ('pending', 'accepted') for update skip locked loop
    select string_agg(display_name, ' and ' order by display_name) into v_names from players where id in (r.from_user_id, r.to_user_id);
    if r.staged_game_id is not null then
      -- its result is logged: it's finished
      update game_invites set status = 'completed' where id = r.id;
    elsif r.staged_result is null and r.last_activity_at < now() - interval '24 hours' then
      -- 24 hours with nothing happening, and no result waiting: close it
      update game_invites set status = 'cancelled', closed_reason = 'expired', responded_at = coalesce(responded_at, now()) where id = r.id;
      perform notify_user(r.from_user_id, r.campaign_id, 'battle', 'Battle closed',
        'Your battle with ' || coalesce((select display_name from players where id = r.to_user_id), 'your opponent') || ' had no activity for 24 hours, so it was closed. Nothing was recorded for it.');
      perform notify_user(r.to_user_id, r.campaign_id, 'battle', 'Battle closed',
        'Your battle with ' || coalesce((select display_name from players where id = r.from_user_id), 'your opponent') || ' had no activity for 24 hours, so it was closed. Nothing was recorded for it.');
      v_closed := v_closed + 1;
    elsif r.status = 'accepted' and r.organiser_alerted_at is null and r.last_activity_at < now() - interval '3 hours' then
      -- 3 hours quiet: let the organisers know, once
      update game_invites set organiser_alerted_at = now() where id = r.id;
      for v_org in select user_id from campaign_members where campaign_id = r.campaign_id and role = 'organiser' loop
        perform notify_user(v_org.user_id, r.campaign_id, 'battle_stuck', 'A battle has gone quiet',
          'The battle between ' || coalesce(v_names, 'two players') || ' has had no activity for 3 hours' ||
          case when r.staged_result is not null then ', with a result waiting to be confirmed' else '' end ||
          '. You can close it in Admin › Players › Battles in progress.');
      end loop;
    end if;
  end loop;
  return v_closed;
end;
$$;

-- ----------------------------------------------------------------------------
-- my_open_battle: the battle (or unanswered request) the player has open
-- anywhere, for "You've a battle in progress with Dave"
-- ----------------------------------------------------------------------------
create or replace function my_open_battle()
returns table (id bigint, campaign_id uuid, campaign_name text, other_id uuid, other_name text, status text, mine_to_answer boolean, result_waiting boolean)
language sql stable security definer set search_path = public as $$
  select i.id, i.campaign_id, c.name, o.id, o.display_name, i.status,
         (i.status = 'pending' and i.to_user_id = auth.uid()), (i.staged_result is not null)
    from game_invites i
    join campaigns c on c.id = i.campaign_id
    join players o on o.id = case when i.from_user_id = auth.uid() then i.to_user_id else i.from_user_id end
   where (i.status = 'accepted' and auth.uid() in (i.from_user_id, i.to_user_id))
      or (i.status = 'pending' and i.from_user_id = auth.uid())
   order by (i.status = 'accepted') desc, i.last_activity_at desc
   limit 1;
$$;

revoke all on function leave_battle(bigint) from public, anon;
revoke all on function close_battle(bigint) from public, anon;
revoke all on function tidy_open_battles(uuid) from public, anon;
revoke all on function my_open_battle() from public, anon;
grant execute on function leave_battle(bigint) to authenticated;
grant execute on function close_battle(bigint) to authenticated;
grant execute on function tidy_open_battles(uuid) to authenticated;
grant execute on function my_open_battle() to authenticated;

-- organisers see their campaign's battles (Admin › Players › Battles in progress)
drop policy if exists "organisers read their campaign's battles" on game_invites;
create policy "organisers read their campaign's battles" on game_invites
  for select to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

-- one-off: start from a clean slate. Battles whose result is logged are
-- finished; any other battle idle for 24 hours without a result waiting
-- closes, quietly.
select set_config('scriptorium.quiet', 'on', true);
update game_invites set status = 'completed'
 where status in ('pending', 'accepted') and staged_game_id is not null;
update game_invites set status = 'cancelled', closed_reason = 'expired', responded_at = coalesce(responded_at, now())
 where status in ('pending', 'accepted') and staged_result is null and last_activity_at < now() - interval '24 hours';
