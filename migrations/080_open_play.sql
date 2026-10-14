-- ============================================================================
-- 080_open_play.sql
--
-- Open play: a permanent space, outside any campaign, where any player on
-- Scriptorium can challenge any other. It is a campaign row with
-- format = 'open', so challenges, Game view, battle logging, battle cards
-- and the chronicle all work unchanged.
--
-- 1. campaigns.format gains 'open'. One Open play campaign is created
--    (Path to Glory off, no join code worth sharing).
-- 2. Every player is a member: existing players are added now, and new
--    players as they register (trigger on players).
-- 3. rosters.is_public: in Open play your list is private unless you make
--    it public. A private list is visible to you, to platform admins, and
--    to players you've accepted a challenge with or played against.
--    Other campaigns are unchanged (any member can read, as before).
-- 4. copy_roster_into_campaign(): copies one of your lists (and its active
--    units, without XP or advances) into another campaign you belong to,
--    e.g. from a campaign into Open play.
-- 5. Campaign-wide notifications (leader changes, streaks, phase live)
--    are skipped in Open play, where "the campaign" is every player.
--
-- Run before merging the open play index.html.
--
-- To undo:
--   drop trigger if exists join_open_play on players;
--   drop function if exists join_open_play_trg(), copy_roster_into_campaign(bigint, uuid),
--     roster_visible(uuid, uuid, boolean);
--   restore the two read policies from 010 (is_campaign_member(campaign_id)),
--   re-run notify_campaign from 075, delete the open campaign
--   (delete from campaigns where format = 'open'), then
--   alter table rosters drop column if exists is_public; and put the
--   campaigns_format_check back to ('narrative', 'tournament').
-- ============================================================================

alter table campaigns drop constraint if exists campaigns_format_check;
alter table campaigns add constraint campaigns_format_check check (format in ('narrative', 'tournament', 'open'));
create unique index if not exists campaigns_one_open_play on campaigns (format) where format = 'open';

insert into campaigns (name, status, join_code, format, path_to_glory_enabled, narrative_enabled, rosters_locked, chronicle_sharing)
select 'Open play', 'active', 'OPEN-PLAY', 'open', false, false, true, true
 where not exists (select 1 from campaigns where format = 'open');

-- everyone is a member
insert into campaign_members (user_id, campaign_id, role, onboarded)
select p.id, c.id, 'player', true
  from players p cross join campaigns c
 where c.format = 'open'
   and not exists (select 1 from campaign_members m where m.user_id = p.id and m.campaign_id = c.id);

create or replace function join_open_play_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into campaign_members (user_id, campaign_id, role, onboarded)
  select new.id, c.id, 'player', true from campaigns c
   where c.format = 'open'
     and not exists (select 1 from campaign_members m where m.user_id = new.id and m.campaign_id = c.id);
  return new;
end;
$$;
drop trigger if exists join_open_play on players;
create trigger join_open_play after insert on players
  for each row execute function join_open_play_trg();

-- public or private lists in Open play
alter table rosters add column if not exists is_public boolean not null default false;

create or replace function roster_visible(p_campaign uuid, p_owner uuid, p_public boolean)
returns boolean language sql stable security definer set search_path = public as $$
  select (is_campaign_member(p_campaign) or is_platform_admin())
     and (
       not exists (select 1 from campaigns c where c.id = p_campaign and c.format = 'open')
       or p_owner = auth.uid()
       or p_public
       or is_platform_admin()
       or exists (select 1 from game_invites i
                   where i.campaign_id = p_campaign and i.status in ('accepted', 'completed')
                     and ((i.from_user_id = auth.uid() and i.to_user_id = p_owner)
                       or (i.to_user_id = auth.uid() and i.from_user_id = p_owner)))
       or exists (select 1 from games g
                   where g.campaign_id = p_campaign
                     and ((g.player_id = auth.uid() and g.opponent_id = p_owner)
                       or (g.opponent_id = auth.uid() and g.player_id = p_owner)))
     );
$$;
revoke all on function roster_visible(uuid, uuid, boolean) from public, anon;
grant execute on function roster_visible(uuid, uuid, boolean) to authenticated;

drop policy if exists "campaign members can read rosters" on rosters;
create policy "campaign members can read rosters" on rosters
  for select to authenticated
  using (roster_visible(campaign_id, player_id, is_public));

drop policy if exists "campaign members can read units" on units;
create policy "campaign members can read units" on units
  for select to authenticated
  using (exists (select 1 from rosters r where r.id = units.roster_id
                   and roster_visible(r.campaign_id, r.player_id, r.is_public)));

-- copy one of your lists into another campaign you're in (fresh: no XP,
-- no advances, archived units left behind)
create or replace function copy_roster_into_campaign(p_roster bigint, p_campaign uuid)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  r rosters%rowtype;
  v_new bigint;
  v_cols text;
  v_ucols text;
  v_usel text;
begin
  select * into r from rosters where id = p_roster;
  if not found or r.player_id is distinct from auth.uid() then
    raise exception 'You can only copy your own lists.';
  end if;
  if not is_campaign_member(p_campaign) then
    raise exception 'You''re not in that campaign.';
  end if;
  if exists (select 1 from rosters where player_id = auth.uid() and campaign_id = p_campaign) then
    raise exception 'You already have a list here. Remove it first, or import over it.';
  end if;

  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'rosters'
     and column_name not in ('id', 'campaign_id', 'is_public', 'created_at', 'updated_at')
     and is_generated = 'NEVER' and is_identity = 'NO';
  execute format('insert into rosters (campaign_id, %1$s) select $1, %1$s from rosters where id = $2 returning id', v_cols)
    into v_new using p_campaign, p_roster;

  -- every other column copied as is; experience starts again at 0 and the
  -- unit is active (whatever it was in the old campaign)
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position),
         string_agg(case column_name when 'experience' then '0' when 'status' then quote_literal('active')
                    else quote_ident(column_name) end, ', ' order by ordinal_position)
    into v_ucols, v_usel
    from information_schema.columns
   where table_schema = 'public' and table_name = 'units'
     and column_name not in ('id', 'roster_id', 'campaign_id', 'archived_at', 'created_at', 'updated_at')
     and is_generated = 'NEVER' and is_identity = 'NO';
  execute format('insert into units (roster_id, campaign_id, %1$s) select $1, $2, %2$s from units where roster_id = $3 and archived_at is null order by id', v_ucols, v_usel)
    using v_new, p_campaign, p_roster;

  update campaign_members set faction_id = r.faction_id
   where user_id = auth.uid() and campaign_id = p_campaign and faction_id is null;
  return v_new;
end;
$$;
revoke all on function copy_roster_into_campaign(bigint, uuid) from public, anon;
grant execute on function copy_roster_into_campaign(bigint, uuid) to authenticated;

-- no campaign-wide broadcasts in Open play
create or replace function notify_campaign(p_campaign uuid, p_kind text, p_title text, p_body text, p_fun boolean default false, p_except uuid[] default '{}')
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, campaign_id, kind, title, body, fun)
  select cm.user_id, p_campaign, p_kind, p_title, p_body, p_fun
    from campaign_members cm
    join players p on p.id = cm.user_id
   where cm.campaign_id = p_campaign
     and not (cm.user_id = any (p_except))
     and (not p_fun or p.fun_notifications)
     and not exists (select 1 from campaigns c where c.id = p_campaign and c.format = 'open');
$$;
revoke all on function notify_campaign(uuid, text, text, text, boolean, uuid[]) from public, anon, authenticated;
