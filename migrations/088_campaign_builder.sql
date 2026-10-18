-- ============================================================================
-- 088_campaign_builder.sql
--
-- The step-by-step campaign builder, and letting any player run their own
-- campaign.
--
-- 1. Campaigns can be drafts. campaigns.status gains 'draft': a draft is
--    visible only to its organisers (and platform admins) and nobody can
--    join it. "Open the campaign" (open_campaign) turns it to 'active',
--    which is what every existing check already treats as open and running,
--    so nothing that reads status = 'active' / 'archived' changes. A
--    campaign can't go back to draft once it's open.
--
-- 2. Join codes can't be read by just anyone any more. Until now every
--    signed-in player could read every campaign row, join code included, so
--    codes could be listed straight from the API. Campaigns are now readable
--    by their own members and platform admins only, and joining goes through
--    join_campaign_by_code(), which looks the code up server-side, tries are
--    limited (10 wrong codes in 15 minutes), and it answers with a status
--    rather than an error so the client can explain what happened. Codes are
--    matched ignoring case, spaces and dashes, and O/0 and I/1/L count as the
--    same, so a code read aloud or typed on a phone still works. Existing
--    campaigns keep the codes (and join links) they already have.
--
-- 3. The creator becomes organiser. A trigger adds whoever created a
--    campaign (campaigns.created_by) as its organiser, so a new campaign
--    shows up in its creator's campaign switcher. This was missing: the
--    Scriptorium tab's "Create campaign" inserted the campaign but not the
--    membership. Campaigns that the bug left with no organiser at all get
--    their creator added now; campaigns that already have an organiser
--    (Season of Skulls) are left exactly as they are.
--
-- 4. Any signed-in player can create a campaign, through save_campaign_draft().
--    Limits: at most 3 drafts at a time, and at most 5 open campaigns
--    organised at once (platform admins are exempt). The builder saves each
--    step through the same function, which replaces the draft's alliances,
--    phases and phase scenarios with what the builder sends. It works on
--    drafts only; open campaigns are changed from the admin tabs as before.
--    Drafts can be built without two-factor login (nobody else is in them),
--    but opening a campaign, like every other organiser power (072), needs
--    it. delete_campaign_draft() lets a player bin a draft they started.
--
-- 5. Phases get dates. campaign_phases.starts_on / ends_on are shown to
--    players ("Phase 2 ends Sunday 9 Nov"). The existing sequence column is
--    the phase order the organiser now sets by dragging in Admin > Phases;
--    it's renumbered 1, 2, 3... here from the current order so gaps and
--    duplicates from hand-typed numbers go away.
--
-- 6. Campaign dates, the template used and a note that the join link was
--    shared live in campaigns.settings (starts_on, ends_on, template,
--    invite_shared_at), which has existed since 001 and was empty.
--
-- Run after 085. Safe to run before or after merging the campaign builder
-- index.html (the page hides the new parts until this has run), but run it
-- soon after merging: until then a new campaign's creator still isn't made
-- its organiser.
--
-- To undo:
--   drop function if exists join_campaign_by_code(text);
--   drop function if exists set_campaign_join_code(uuid, text);
--   drop function if exists save_campaign_draft(uuid, jsonb);
--   drop function if exists open_campaign(uuid);
--   drop function if exists delete_campaign_draft(uuid);
--   drop trigger if exists campaigns_creator_is_organiser on campaigns;
--   drop function if exists campaign_creator_is_organiser_trg();
--   drop trigger if exists campaigns_no_return_to_draft on campaigns;
--   drop function if exists campaign_no_return_to_draft_trg();
--   drop function if exists can_build_campaign(uuid);
--   drop table if exists join_code_attempts;
--   drop index if exists campaigns_join_code_norm_idx;
--   drop function if exists generate_join_code(text);
--   drop function if exists normalise_join_code(text);
--   drop policy if exists "campaigns are readable by their members and admins" on campaigns;
--   create policy "campaigns are readable by any signed-in user" on campaigns
--     for select to authenticated using (true);
--   update campaigns set status = 'active' where status = 'draft';
--   alter table campaigns drop constraint if exists campaigns_status_check;
--   alter table campaigns add constraint campaigns_status_check
--     check (status in ('setup', 'active', 'archived', 'completed'));
--   alter table campaign_phases drop constraint if exists campaign_phases_dates_check;
--   alter table campaign_phases drop column if exists starts_on, drop column if exists ends_on;
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. draft status
-- ----------------------------------------------------------------------------
alter table campaigns drop constraint if exists campaigns_status_check;
alter table campaigns add constraint campaigns_status_check
  check (status in ('draft', 'setup', 'active', 'archived', 'completed'));

comment on column campaigns.status is 'draft = being set up, visible only to its organisers, not joinable (088). active = open and running. archived = ended (036): no new players or battles. setup/completed are older values kept for compatibility.';

-- Once players can see a campaign it can't be hidden again by going back to
-- draft (they'd lose it from their switcher mid-season).
create or replace function campaign_no_return_to_draft_trg()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'draft' and old.status <> 'draft' then
    raise exception 'An open campaign can''t go back to being a draft. Use End campaign instead.';
  end if;
  return new;
end;
$$;
drop trigger if exists campaigns_no_return_to_draft on campaigns;
create trigger campaigns_no_return_to_draft
  before update of status on campaigns
  for each row execute function campaign_no_return_to_draft_trg();

-- ----------------------------------------------------------------------------
-- 5. phase dates and order
-- ----------------------------------------------------------------------------
alter table campaign_phases add column if not exists starts_on date;
alter table campaign_phases add column if not exists ends_on date;
alter table campaign_phases drop constraint if exists campaign_phases_dates_check;
alter table campaign_phases add constraint campaign_phases_dates_check
  check (starts_on is null or ends_on is null or ends_on >= starts_on);

comment on column campaign_phases.starts_on is 'Optional planned start date, shown to players. Activating the phase is still a separate step.';
comment on column campaign_phases.ends_on is 'Optional planned end date, shown to players ("Phase 2 ends Sunday 9 Nov").';
comment on column campaign_phases.sequence is 'Phase order within the campaign, 1 upwards. Set by dragging (or Move up / Move down) in Admin > Phases.';

-- renumber 1, 2, 3... per campaign, keeping the current order
with ordered as (
  select id, row_number() over (partition by campaign_id order by sequence, created_at, id) as rn
    from campaign_phases
)
update campaign_phases p set sequence = o.rn
  from ordered o
 where o.id = p.id and p.sequence is distinct from o.rn;

-- ----------------------------------------------------------------------------
-- 2. join codes
-- ----------------------------------------------------------------------------
-- What two codes are compared on: letters and digits only, upper case, with
-- 0 read as O and 1/L read as I.
create or replace function normalise_join_code(p_code text)
returns text language sql immutable set search_path = public as $$
  select translate(regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g'), '01L', 'OII');
$$;

-- A readable code: a word from the campaign's name, a dash and four
-- characters with nothing that can be mistaken for something else
-- (no 0/O, 1/I/L). For example SEASON-7KQ4.
create or replace function generate_join_code(p_name text)
returns text language plpgsql volatile set search_path = public as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_word text;
  v_prefix text := '';
  v_code text;
  v_tries integer := 0;
begin
  foreach v_word in array regexp_split_to_array(upper(coalesce(p_name, '')), '\s+') loop
    v_word := regexp_replace(v_word, '[^A-Z]', '', 'g');
    if length(v_word) >= 3 and v_word not in ('THE', 'AND', 'FOR', 'WITH') then
      v_prefix := left(v_word, 6);
      exit;
    end if;
  end loop;
  if v_prefix = '' then v_prefix := 'CAMP'; end if;

  loop
    v_tries := v_tries + 1;
    v_code := v_prefix || '-';
    for i in 1..4 loop
      v_code := v_code || substr(v_alphabet, 1 + (get_byte(gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    exit when not exists (select 1 from campaigns where normalise_join_code(join_code) = normalise_join_code(v_code));
    if v_tries > 50 then raise exception 'Couldn''t find a free join code. Try again.'; end if;
  end loop;
  return v_code;
end;
$$;

create index if not exists campaigns_join_code_norm_idx on campaigns (normalise_join_code(join_code));

revoke all on function normalise_join_code(text) from public, anon;
revoke all on function generate_join_code(text) from public, anon;
grant execute on function normalise_join_code(text) to authenticated;
grant execute on function generate_join_code(text) to authenticated;

-- Campaigns (and so their join codes) are readable by members and platform
-- admins only. A draft's only members are its organisers, so a draft is
-- visible to them alone. Nothing in the app reads another campaign's row:
-- the Story tab's shared posts carry their own campaign_name.
drop policy if exists "campaigns are readable by any signed-in user" on campaigns;
drop policy if exists "campaigns are readable by their members and admins" on campaigns;
create policy "campaigns are readable by their members and admins" on campaigns
  for select to authenticated
  using (is_campaign_member(id) or is_platform_admin());

-- wrong codes, to limit guessing; read only by join_campaign_by_code
create table if not exists join_code_attempts (
  user_id      uuid not null references players(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index if not exists join_code_attempts_user_idx on join_code_attempts (user_id, attempted_at);
alter table join_code_attempts enable row level security;
-- no policies: nobody reads or writes this directly

-- ----------------------------------------------------------------------------
-- join_campaign_by_code: join a campaign with its code. Returns
--   { status, campaign_id, name }
-- where status is joined, already_member, not_found, not_open (a draft),
-- ended, full or too_many_tries. Only 'joined' adds a membership.
-- ----------------------------------------------------------------------------
create or replace function join_campaign_by_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_norm text := normalise_join_code(p_code);
  v_c campaigns%rowtype;
  v_count integer;
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
      return jsonb_build_object('status', 'full', 'name', v_c.name);
    end if;
  end if;

  insert into campaign_members (user_id, campaign_id, role)
  values (v_uid, v_c.id, 'player')
  on conflict (user_id, campaign_id) do nothing;

  return jsonb_build_object('status', 'joined', 'campaign_id', v_c.id, 'name', v_c.name);
end;
$$;

revoke all on function join_campaign_by_code(text) from public, anon;
grant execute on function join_campaign_by_code(text) to authenticated;

-- ----------------------------------------------------------------------------
-- 3. the creator is organiser
-- ----------------------------------------------------------------------------
create or replace function campaign_creator_is_organiser_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.created_by is not null and new.format <> 'open' then
    insert into campaign_members (user_id, campaign_id, role, onboarded)
    values (new.created_by, new.id, 'organiser', true)
    on conflict (user_id, campaign_id) do update set role = 'organiser';
  end if;
  return new;
end;
$$;
drop trigger if exists campaigns_creator_is_organiser on campaigns;
create trigger campaigns_creator_is_organiser
  after insert on campaigns
  for each row execute function campaign_creator_is_organiser_trg();

-- campaigns the bug left without any organiser: their creator becomes one
insert into campaign_members (user_id, campaign_id, role, onboarded)
select c.created_by, c.id, 'organiser', true
  from campaigns c
 where c.created_by is not null
   and c.format <> 'open'
   and exists (select 1 from players p where p.id = c.created_by)
   and not exists (select 1 from campaign_members m where m.campaign_id = c.id and m.role = 'organiser')
on conflict (user_id, campaign_id) do update set role = 'organiser';

-- ----------------------------------------------------------------------------
-- 4. building a draft
-- ----------------------------------------------------------------------------
-- Who may build a campaign: its organisers and platform admins as usual
-- (two-factor login), and, while it's still a draft, its organisers without
-- two-factor login too.
create or replace function can_build_campaign(p_campaign uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select is_campaign_organiser(p_campaign) or is_platform_admin() or exists (
    select 1 from campaigns c
      join campaign_members m on m.campaign_id = c.id
     where c.id = p_campaign and c.status = 'draft'
       and m.user_id = auth.uid() and m.role = 'organiser'
  );
$$;
revoke all on function can_build_campaign(uuid) from public, anon;
grant execute on function can_build_campaign(uuid) to authenticated;

-- set_campaign_join_code: a new code (p_code null) or the organiser's own.
create or replace function set_campaign_join_code(p_campaign uuid, p_code text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_code text;
begin
  if not can_build_campaign(p_campaign) then
    raise exception 'Only an organiser of this campaign can change its join code.';
  end if;
  select name into v_name from campaigns where id = p_campaign and format <> 'open';
  if not found then raise exception 'That campaign doesn''t exist.'; end if;

  if p_code is null or trim(p_code) = '' then
    v_code := generate_join_code(v_name);
  else
    v_code := upper(regexp_replace(trim(p_code), '\s+', '-', 'g'));
    if v_code !~ '^[A-Z0-9]+(-[A-Z0-9]+)*$' or length(v_code) > 20 or length(normalise_join_code(v_code)) < 4 then
      raise exception 'A join code is 4 to 20 letters and numbers, with dashes between groups if you like.';
    end if;
    if exists (select 1 from campaigns where id <> p_campaign and normalise_join_code(join_code) = normalise_join_code(v_code)) then
      raise exception 'Another campaign already uses that code (or one that reads the same). Try another.';
    end if;
  end if;

  update campaigns set join_code = v_code where id = p_campaign;
  return v_code;
end;
$$;
revoke all on function set_campaign_join_code(uuid, text) from public, anon;
grant execute on function set_campaign_join_code(uuid, text) to authenticated;

-- ----------------------------------------------------------------------------
-- save_campaign_draft: create a draft (p_campaign null) or save the
-- builder's steps to one. p_payload:
--   name, format ('narrative' | 'tournament'), starts_on, ends_on (dates),
--   player_cap, path_to_glory_enabled, narrative_enabled, chronicle_sharing,
--   alliance_selection_locked, campaign_point_tiers, template,
--   alliances: [{ id?, name, colour }],
--   phases:    [{ id?, name, starts_on, ends_on, max_games, mission_ids: [] }],
--   tournament: { name, format, rounds_planned, points_limit } (tournaments only)
-- A key left out keeps what's there; alliances/phases, when sent, replace
-- the draft's whole list (in the order sent). Returns { id, join_code }.
-- ----------------------------------------------------------------------------
create or replace function save_campaign_draft(p_campaign uuid, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_p jsonb := coalesce(p_payload, '{}'::jsonb);
  v_c campaigns%rowtype;
  v_cid uuid := p_campaign;
  v_name text;
  v_format text;
  v_cap integer;
  v_starts date;
  v_ends date;
  v_settings jsonb;
  v_item jsonb;
  v_keep_text text[] := '{}';
  v_keep_uuid uuid[] := '{}';
  v_aid text;
  v_base text;
  v_pid uuid;
  v_pname text;
  v_colour text;
  v_max integer;
  v_t jsonb;
  v_tid uuid;
  v_tfmt text;
begin
  if v_uid is null then raise exception 'Sign in first.'; end if;

  v_name := nullif(left(trim(coalesce(v_p->>'name', '')), 80), '');
  if v_p ? 'format' then
    v_format := v_p->>'format';
    if v_format not in ('narrative', 'tournament') then raise exception 'Choose a narrative campaign or a tournament.'; end if;
  end if;
  if v_p ? 'starts_on' then v_starts := nullif(v_p->>'starts_on', '')::date; end if;
  if v_p ? 'ends_on' then v_ends := nullif(v_p->>'ends_on', '')::date; end if;
  if v_starts is not null and v_ends is not null and v_ends < v_starts then
    raise exception 'The campaign can''t end before it starts.';
  end if;
  if v_p ? 'player_cap' then
    v_cap := nullif(v_p->>'player_cap', '')::integer;
    if v_cap is not null and (v_cap < 2 or v_cap > 500) then raise exception 'Max players must be between 2 and 500, or blank for no limit.'; end if;
  end if;

  if v_cid is null then
    -- a new draft
    if v_name is null then raise exception 'Give the campaign a name.'; end if;
    perform pg_advisory_xact_lock(hashtext('save_campaign_draft:' || v_uid::text));
    if not is_platform_admin() then
      if (select count(*) from campaigns where created_by = v_uid and status = 'draft') >= 3 then
        raise exception 'You already have 3 draft campaigns. Open or delete one before starting another.';
      end if;
      if (select count(*) from campaigns c join campaign_members m on m.campaign_id = c.id
           where m.user_id = v_uid and m.role = 'organiser' and c.status in ('active', 'setup') and c.format <> 'open') >= 5 then
        raise exception 'You''re already running 5 campaigns. End one before starting another.';
      end if;
    end if;
    insert into campaigns (name, status, join_code, format, created_by, path_to_glory_enabled, narrative_enabled)
    values (v_name, 'draft', generate_join_code(v_name), coalesce(v_format, 'narrative'), v_uid, true, false)
    returning id into v_cid;
    -- campaigns_creator_is_organiser has made v_uid its organiser
  else
    if not can_build_campaign(v_cid) then
      raise exception 'Only an organiser of this campaign can change it.';
    end if;
  end if;

  select * into v_c from campaigns where id = v_cid for update;
  if not found then raise exception 'That campaign doesn''t exist.'; end if;
  if v_c.status <> 'draft' then
    raise exception 'This campaign is already open. Change it from the admin tabs instead.';
  end if;

  -- the campaign itself
  v_settings := coalesce(v_c.settings, '{}'::jsonb);
  if v_p ? 'starts_on' then
    v_settings := v_settings - 'starts_on';
    if v_starts is not null then v_settings := v_settings || jsonb_build_object('starts_on', v_starts::text); end if;
  end if;
  if v_p ? 'ends_on' then
    v_settings := v_settings - 'ends_on';
    if v_ends is not null then v_settings := v_settings || jsonb_build_object('ends_on', v_ends::text); end if;
  end if;
  if v_p ? 'template' then v_settings := v_settings || jsonb_build_object('template', left(coalesce(v_p->>'template', ''), 40)); end if;

  update campaigns set
    name = coalesce(v_name, name),
    format = coalesce(v_format, format),
    player_cap = case when v_p ? 'player_cap' then v_cap else player_cap end,
    path_to_glory_enabled = coalesce((v_p->>'path_to_glory_enabled')::boolean, path_to_glory_enabled),
    narrative_enabled = coalesce((v_p->>'narrative_enabled')::boolean, narrative_enabled),
    chronicle_sharing = coalesce((v_p->>'chronicle_sharing')::boolean, chronicle_sharing),
    alliance_selection_locked = coalesce((v_p->>'alliance_selection_locked')::boolean, alliance_selection_locked),
    campaign_point_tiers = case when jsonb_typeof(v_p->'campaign_point_tiers') = 'object' then v_p->'campaign_point_tiers' else campaign_point_tiers end,
    settings = v_settings
  where id = v_cid;

  -- alliances, in the order sent
  if jsonb_typeof(v_p->'alliances') = 'array' then
    if jsonb_array_length(v_p->'alliances') > 12 then raise exception 'A campaign can have up to 12 alliances.'; end if;
    for v_item in select * from jsonb_array_elements(v_p->'alliances') loop
      v_pname := nullif(left(trim(coalesce(v_item->>'name', '')), 60), '');
      continue when v_pname is null;
      v_colour := case when coalesce(v_item->>'colour', '') ~ '^#[0-9a-fA-F]{6}$' then v_item->>'colour' else '#8a1c1c' end;
      v_aid := nullif(v_item->>'id', '');
      if v_aid is not null and exists (select 1 from alliances where id = v_aid and campaign_id = v_cid) then
        update alliances set name = v_pname, colour = v_colour where id = v_aid;
      else
        -- alliances.id is a slug and unique across every campaign
        v_base := coalesce(nullif(trim(both '-' from regexp_replace(lower(v_pname), '[^a-z0-9]+', '-', 'g')), ''), 'alliance');
        v_aid := v_base;
        while exists (select 1 from alliances where id = v_aid) loop
          v_aid := v_base || '-' || substr(md5(gen_random_uuid()::text), 1, 4);
        end loop;
        insert into alliances (id, name, colour, campaign_id) values (v_aid, v_pname, v_colour, v_cid);
      end if;
      v_keep_text := v_keep_text || v_aid;
    end loop;
    update campaign_members set alliance_id = null
     where campaign_id = v_cid and alliance_id is not null and not (alliance_id = any(v_keep_text));
    delete from alliances where campaign_id = v_cid and not (id = any(v_keep_text));
  end if;

  -- phases and their scenarios, in the order sent
  if jsonb_typeof(v_p->'phases') = 'array' then
    if jsonb_array_length(v_p->'phases') > 20 then raise exception 'A campaign can have up to 20 phases.'; end if;
    for v_item in select * from jsonb_array_elements(v_p->'phases') loop
      v_pname := nullif(left(trim(coalesce(v_item->>'name', '')), 80), '');
      continue when v_pname is null;
      v_starts := nullif(v_item->>'starts_on', '')::date;
      v_ends := nullif(v_item->>'ends_on', '')::date;
      if v_starts is not null and v_ends is not null and v_ends < v_starts then
        raise exception '"%" can''t end before it starts.', v_pname;
      end if;
      v_max := nullif(v_item->>'max_games', '')::integer;
      if v_max is not null and (v_max < 1 or v_max > 20) then v_max := null; end if;
      v_pid := nullif(v_item->>'id', '')::uuid;
      if v_pid is not null and exists (select 1 from campaign_phases where id = v_pid and campaign_id = v_cid) then
        update campaign_phases set name = v_pname, sequence = coalesce(array_length(v_keep_uuid, 1), 0) + 1,
               starts_on = v_starts, ends_on = v_ends, max_games = v_max
         where id = v_pid;
      else
        insert into campaign_phases (campaign_id, name, sequence, starts_on, ends_on, max_games, created_by)
        values (v_cid, v_pname, coalesce(array_length(v_keep_uuid, 1), 0) + 1, v_starts, v_ends, v_max, v_uid)
        returning id into v_pid;
      end if;
      v_keep_uuid := v_keep_uuid || v_pid;

      delete from campaign_phase_missions where phase_id = v_pid;
      if jsonb_typeof(v_item->'mission_ids') = 'array' then
        insert into campaign_phase_missions (phase_id, mission_id)
        select distinct v_pid, m.id
          from missions m
         where m.id in (select x::uuid from jsonb_array_elements_text(v_item->'mission_ids') as t(x))
           and (m.campaign_id is null or m.campaign_id = v_cid);
      end if;
    end loop;
    delete from campaign_phases where campaign_id = v_cid and not (id = any(v_keep_uuid));
  end if;

  -- a tournament campaign's tournament, ready to take entrants once open
  v_t := v_p->'tournament';
  if jsonb_typeof(v_t) = 'object' and coalesce(v_format, v_c.format) = 'tournament' then
    v_tfmt := case when v_t->>'format' in ('swiss', 'single_elim', 'round_robin') then v_t->>'format' else 'swiss' end;
    select id into v_tid from tournaments where campaign_id = v_cid order by created_at limit 1;
    if v_tid is null then
      insert into tournaments (campaign_id, name, format, rounds_planned, points_limit, created_by)
      values (v_cid, coalesce(nullif(left(trim(coalesce(v_t->>'name', '')), 80), ''), coalesce(v_name, v_c.name)), v_tfmt,
              case when v_tfmt = 'swiss' then least(greatest(coalesce(nullif(v_t->>'rounds_planned', '')::integer, 3), 1), 10) end,
              nullif(v_t->>'points_limit', '')::integer, v_uid);
    else
      update tournaments set
        name = coalesce(nullif(left(trim(coalesce(v_t->>'name', '')), 80), ''), name),
        format = v_tfmt,
        rounds_planned = case when v_tfmt = 'swiss' then least(greatest(coalesce(nullif(v_t->>'rounds_planned', '')::integer, 3), 1), 10) end,
        points_limit = nullif(v_t->>'points_limit', '')::integer
       where id = v_tid and status = 'setup' and entrants_locked_at is null;
    end if;
  end if;

  return jsonb_build_object('id', v_cid, 'join_code', (select join_code from campaigns where id = v_cid));
end;
$$;
revoke all on function save_campaign_draft(uuid, jsonb) from public, anon;
grant execute on function save_campaign_draft(uuid, jsonb) to authenticated;

-- open_campaign: a draft becomes open, so its join code and link work.
-- Needs two-factor login, like the rest of an organiser's powers (072).
create or replace function open_campaign(p_campaign uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Opening a campaign needs two-factor login. Set it up in Account settings, then sign in again.';
  end if;
  update campaigns set status = 'active' where id = p_campaign and status = 'draft';
  if not found then raise exception 'This campaign isn''t a draft any more.'; end if;
end;
$$;
revoke all on function open_campaign(uuid) from public, anon;
grant execute on function open_campaign(uuid) to authenticated;

-- delete_campaign_draft: bin a draft. Only drafts: an open campaign keeps
-- its players' data and is deleted by a platform admin, as before.
create or replace function delete_campaign_draft(p_campaign uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_build_campaign(p_campaign) then
    raise exception 'Only an organiser of this campaign can delete it.';
  end if;
  perform 1 from campaigns where id = p_campaign and status = 'draft' for update;
  if not found then raise exception 'Only a draft can be deleted here.'; end if;
  -- these point at campaigns without "on delete cascade" (003, 004, 006),
  -- e.g. a list the organiser imported while trying the draft out
  delete from unit_advances where campaign_id = p_campaign;
  delete from units where campaign_id = p_campaign;
  delete from rosters where campaign_id = p_campaign;
  delete from games where campaign_id = p_campaign;
  delete from trait_objectives where campaign_id = p_campaign;
  update campaign_members set alliance_id = null where campaign_id = p_campaign;
  delete from alliances where campaign_id = p_campaign;
  delete from campaigns where id = p_campaign;
end;
$$;
revoke all on function delete_campaign_draft(uuid) from public, anon;
grant execute on function delete_campaign_draft(uuid) to authenticated;
