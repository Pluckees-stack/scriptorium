-- ============================================================================
-- seeds/warcastle-test.sql
--
-- The WarCastle test event: a copy of the real one (seeds/warcastle.sql)
-- with 26 dummy players, for rehearsing the day and trying changes before
-- the real event (warcastle-brief.md, "Two instances").
--
-- What it does:
--   - Creates the dummy logins wc-test-01@example.com … wc-test-26@example.com
--     (once), each with a faction, spread across every movement group. Sign
--     in as one with that email and the password set below.
--   - Creates "WarCastle (test)" (once): the real event's settings, its
--     organisers as organisers, and the dummies as players.
--   - Copies the real event's scenarios in, so its 13 tables match. Run it
--     again after changing the real event's tables to bring them across.
--   - Resets the test event's tournament: a fresh copy of the real one, in
--     set-up, with all 26 dummies entered, no rounds, moves or results, and
--     no Supply, Warpstone or magic items (101).
--     (Battles already logged in the test event stay in its battle log.)
--
-- Run in the Supabase SQL editor, after migrations/100 and seeds/warcastle.sql.
-- Set the password first: it refuses to run with the placeholder. Safe to
-- run again; each run is a reset.
-- ============================================================================

do $$
declare
  v_password  constant text := 'CHANGE-ME';   -- the dummies' password
  -- a reserved domain: not the username sign-in's (AUTH_DOMAIN in
  -- index.html), which would ask each dummy to add a real email first
  v_domain    constant text := 'example.com';
  -- one faction per dummy, in turn: every movement group is covered
  v_factions  constant text[] := array[
    'high-elf-realms', 'wood-elf-realms', 'dark-elves', 'skaven',
    'warriors-of-chaos', 'daemons-of-chaos', 'beastmen-brayherds',
    'empire-of-man', 'kingdom-of-bretonnia', 'grand-cathay', 'renegade-crowns',
    'orc-and-goblin-tribes', 'lizardmen', 'ogre-kingdoms',
    'vampire-counts', 'tomb-kings-of-khemri',
    'dwarfen-mountain-holds', 'chaos-dwarfs',
    'high-elf-realms', 'skaven', 'warriors-of-chaos', 'empire-of-man',
    'orc-and-goblin-tribes', 'vampire-counts', 'dwarfen-mountain-holds', 'wood-elf-realms'];
  v_real      campaigns%rowtype;
  v_test      uuid;
  v_real_t    tournaments%rowtype;
  v_test_t    uuid;
  v_uid       uuid;
  v_email     text;
  v_map       jsonb;
  v_settings  text;
  v_rounds    text;
  m           record;
  v_copy      uuid;
begin
  if v_password = 'CHANGE-ME' then
    raise exception 'Set v_password at the top of the script first.';
  end if;

  select * into v_real from campaigns
  where name = 'WarCastle' and settings ->> 'template' = 'warcastle';
  if not found then
    raise exception 'No WarCastle event found: create it, then run seeds/warcastle.sql.';
  end if;
  select * into v_real_t from tournaments where campaign_id = v_real.id order by created_at limit 1;
  if not found then
    raise exception 'The WarCastle event has no tournament yet.';
  end if;

  -- the dummy logins (the players rows come from 063's trigger)
  for i in 1 .. 26 loop
    v_email := format('wc-test-%s@%s', lpad(i::text, 2, '0'), v_domain);
    select id into v_uid from auth.users where email = v_email;
    if v_uid is null then
      v_uid := gen_random_uuid();
      insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, email_change, email_change_token_new, recovery_token)
      values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email,
        extensions.crypt(v_password, extensions.gen_salt('bf')), now(),
        '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', format('wc-test-%s', lpad(i::text, 2, '0'))),
        now(), now(), '', '', '', '');
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), v_uid, v_uid::text, jsonb_build_object('sub', v_uid::text, 'email', v_email), 'email', now(), now(), now());
    else
      update auth.users set encrypted_password = extensions.crypt(v_password, extensions.gen_salt('bf')) where id = v_uid;
    end if;
  end loop;

  -- the test campaign, made once
  select id into v_test from campaigns where name = 'WarCastle (test)';
  if v_test is null then
    insert into campaigns (name, status, join_code, format, settings, created_by, player_cap)
    values ('WarCastle (test)', 'active', 'WCTEST-' || upper(substr(md5(random()::text), 1, 4)), 'tournament',
      v_real.settings - 'setup' - 'soft_results', v_real.created_by, null)
    returning id into v_test;
  end if;

  -- the real event's organisers, and the dummies with their factions
  insert into campaign_members (user_id, campaign_id, role, onboarded)
  select user_id, v_test, 'organiser', true from campaign_members
  where campaign_id = v_real.id and role = 'organiser'
  on conflict (user_id, campaign_id) do update set role = 'organiser';
  for i in 1 .. 26 loop
    select id into v_uid from auth.users where email = format('wc-test-%s@%s', lpad(i::text, 2, '0'), v_domain);
    insert into campaign_members (user_id, campaign_id, role, faction_id, onboarded)
    values (v_uid, v_test, 'player', v_factions[i], true)
    on conflict (user_id, campaign_id) do update set faction_id = excluded.faction_id;
  end loop;

  -- the real event's scenarios, copied in (or refreshed); the copies are
  -- remembered in settings.warcastle_test_copies { real id: copy id }
  select coalesce(settings -> 'warcastle_test_copies', '{}'::jsonb) into v_map from campaigns where id = v_test;
  for m in select * from missions where campaign_id = v_real.id loop
    v_copy := coalesce((v_map ->> m.id::text)::uuid, gen_random_uuid());
    begin
      delete from missions where id = v_copy;
      insert into missions
      select (jsonb_populate_record(null::missions, to_jsonb(m) || jsonb_build_object('id', v_copy, 'campaign_id', v_test))).*;
    exception when foreign_key_violation then
      null; -- a battle uses the old copy: keep it as it is
    end;
    v_map := v_map || jsonb_build_object(m.id::text, v_copy);
  end loop;

  -- settings as the real event's, pointing at the copies
  v_settings := (v_real.settings - 'setup' - 'soft_results')::text;
  v_rounds := v_real_t.round_scenarios::text;
  for m in select key, value from jsonb_each_text(v_map) loop
    v_settings := replace(v_settings, m.key, m.value);
    v_rounds := replace(v_rounds, m.key, m.value);
  end loop;
  update campaigns set settings = v_settings::jsonb || jsonb_build_object('warcastle_test_copies', v_map)
  where id = v_test;

  -- a fresh tournament: rounds, pairings, entrants, moves and allegiances go with the old one
  delete from tournaments where campaign_id = v_test;
  -- and no tokens or magic items yet (once 101 is run)
  if to_regclass('public.warcastle_items') is not null then execute 'delete from warcastle_items where campaign_id = $1' using v_test; end if;
  if to_regclass('public.warcastle_tokens') is not null then execute 'delete from warcastle_tokens where campaign_id = $1' using v_test; end if;
  insert into tournaments (campaign_id, name, format, status, rounds_planned, current_round, created_by,
    round_scenarios, points_limit, round_minutes)
  values (v_test, v_real_t.name, v_real_t.format, 'setup', v_real_t.rounds_planned, 0, v_real_t.created_by,
    v_rounds::jsonb, v_real_t.points_limit, v_real_t.round_minutes)
  returning id into v_test_t;
  insert into tournament_entrants (tournament_id, campaign_id, player_id, status)
  select v_test_t, v_test, cm.user_id, 'active' from campaign_members cm
  join auth.users u on u.id = cm.user_id
  where cm.campaign_id = v_test and u.email like 'wc-test-%@' || v_domain;

  raise notice 'WarCastle (test) is ready: % dummies entered.', (select count(*) from tournament_entrants where tournament_id = v_test_t);
end $$;
