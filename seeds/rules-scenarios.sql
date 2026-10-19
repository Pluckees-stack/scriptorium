-- ============================================================================
-- seeds/rules-scenarios.sql
--
-- The rules' own scenarios as official scenarios (campaign_id null), set up
-- the scenario builder's way: the rulebook's pitched battles, the Matched Play
-- Guide (with its doubles), the narrative battles and Battle March: General's
-- Companion. Each has its deployment map (the builder draws every one as the
-- rules do, with the terrain and markers the rules' map shows), objectives,
-- game length, the names of its special rules and a link to the full rules
-- on tow.whfb.app. Its description is where it comes from: the book, the
-- scenario number (if it has one) and its name. The rules' wording itself
-- isn't copied.
--
-- These are what everyone can pick in Play. A campaign's own scenarios only
-- show in that campaign's battles. Organisers copy one into their campaign
-- (Admin > Scenarios) to change it.
--
-- Safe to run more than once: each scenario is matched on its rules link and
-- updated, or added if it isn't there. The rules' map images an earlier
-- version of this seed added are removed (the builder draws the maps now).
-- ============================================================================

delete from maps
  where campaign_id is null
    and rules_url in (
      'https://tow.whfb.app/warhammer-battles/open-battle',
      'https://tow.whfb.app/warhammer-battles/flank-attack',
      'https://tow.whfb.app/warhammer-battles/meeting-engagement',
      'https://tow.whfb.app/warhammer-battles/mountain-pass',
      'https://tow.whfb.app/warhammer-battles/command-and-control',
      'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles',
      'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory',
      'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill',
      'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines',
      'https://tow.whfb.app/matched-play/scenario-4-close-quarters',
      'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter',
      'https://tow.whfb.app/matched-play/scenario-6-encirclement',
      'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment',
      'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines',
      'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost',
      'https://tow.whfb.app/narrative-battles/a-timely-arrival',
      'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass',
      'https://tow.whfb.app/narrative-battles/assault-on-leonen',
      'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads',
      'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road',
      'https://tow.whfb.app/narrative-battles/first-linked-battle',
      'https://tow.whfb.app/narrative-battles/second-linked-battle',
      'https://tow.whfb.app/narrative-battles/third-linked-battle',
      'https://tow.whfb.app/narrative-battles/hallowed-ground',
      'https://tow.whfb.app/narrative-battles/looting-and-pillaging',
      'https://tow.whfb.app/narrative-battles/reclamation-of-hollum',
      'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum',
      'https://tow.whfb.app/narrative-battles/the-battle-of-chalons',
      'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss',
      'https://tow.whfb.app/narrative-battles/the-battle-of-matorea',
      'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li',
      'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills',
      'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter',
      'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk',
      'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands',
      'https://tow.whfb.app/battle-march/the-weisnicht-bridge',
      'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas',
      'https://tow.whfb.app/battle-march/drazgogs-raiders',
      'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin',
      'https://tow.whfb.app/battle-march/clash-at-sturdham',
      'https://tow.whfb.app/battle-march/defence-of-gemelwald'
    );

update missions set name = 'Open Battle', mode = 'normal', deployment_type = 'Open Battle', description = 'Warhammer: the Old World rulebook - Open Battle',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/open-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Open Battle', 'normal', 'https://tow.whfb.app/warhammer-battles/open-battle', 'Open Battle', 'Warhammer: the Old World rulebook - Open Battle', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/open-battle');

update missions set name = 'Flank Attack', mode = 'normal', deployment_type = 'Flank Attack', description = 'Warhammer: the Old World rulebook - Flank Attack',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"flank-attack"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/flank-attack';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Flank Attack', 'normal', 'https://tow.whfb.app/warhammer-battles/flank-attack', 'Flank Attack', 'Warhammer: the Old World rulebook - Flank Attack', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"flank-attack"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/flank-attack');

update missions set name = 'Meeting Engagement', mode = 'normal', deployment_type = 'Meeting Engagement', description = 'Warhammer: the Old World rulebook - Meeting Engagement',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"meeting-engagement"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/meeting-engagement';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Meeting Engagement', 'normal', 'https://tow.whfb.app/warhammer-battles/meeting-engagement', 'Meeting Engagement', 'Warhammer: the Old World rulebook - Meeting Engagement', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"meeting-engagement"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/meeting-engagement');

update missions set name = 'Mountain Pass', mode = 'normal', deployment_type = 'Mountain Pass', description = 'Warhammer: the Old World rulebook - Mountain Pass',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Bottleneck**: see the full rules."]'::jsonb, terrain = '{"deployment":"mountain-pass"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/mountain-pass';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Mountain Pass', 'normal', 'https://tow.whfb.app/warhammer-battles/mountain-pass', 'Mountain Pass', 'Warhammer: the Old World rulebook - Mountain Pass', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Bottleneck**: see the full rules."]'::jsonb, '{"deployment":"mountain-pass"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/mountain-pass');

update missions set name = 'Command & Control', mode = 'normal', deployment_type = 'Command & Control', description = 'Warhammer: the Old World rulebook - Command & Control',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"command-and-control"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/command-and-control';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Command & Control', 'normal', 'https://tow.whfb.app/warhammer-battles/command-and-control', 'Command & Control', 'Warhammer: the Old World rulebook - Command & Control', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"command-and-control"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/command-and-control');

update missions set name = 'Break Point', mode = 'normal', deployment_type = 'Break Point', description = 'Warhammer: the Old World rulebook - Break Point',
    turn_limit = null, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Break Point**: see the full rules."]'::jsonb, terrain = '{"deployment":"break-point"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Break Point', 'normal', 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles', 'Break Point', 'Warhammer: the Old World rulebook - Break Point', null, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Break Point**: see the full rules."]'::jsonb, '{"deployment":"break-point"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles');

update missions set name = 'Scenario 1: Upon the Field of Glory', mode = 'normal', deployment_type = 'Scenario 1: Upon the Field of Glory', description = 'Matched Play Guide - Scenario 1 - Upon the Field of Glory',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"field-of-glory"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 1: Upon the Field of Glory', 'normal', 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory', 'Scenario 1: Upon the Field of Glory', 'Matched Play Guide - Scenario 1 - Upon the Field of Glory', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"field-of-glory"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory');

update missions set name = 'Scenario 2: King of the Hill', mode = 'normal', deployment_type = 'Scenario 2: King of the Hill', description = 'Matched Play Guide - Scenario 2 - King of the Hill',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Hill**: see the full rules.","**Running up-hill**: see the full rules.","**Victory Points**: see the full rules."]'::jsonb, terrain = '{"deployment":"king-of-the-hill"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 2: King of the Hill', 'normal', 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill', 'Scenario 2: King of the Hill', 'Matched Play Guide - Scenario 2 - King of the Hill', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Hill**: see the full rules.","**Running up-hill**: see the full rules.","**Victory Points**: see the full rules."]'::jsonb, '{"deployment":"king-of-the-hill"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill');

update missions set name = 'Scenario 3: Drawn Battlelines', mode = 'normal', deployment_type = 'Scenario 3: Drawn Battlelines', description = 'Matched Play Guide - Scenario 3 - Drawn Battlelines',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":3}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"drawn-battlelines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 3: Drawn Battlelines', 'normal', 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines', 'Scenario 3: Drawn Battlelines', 'Matched Play Guide - Scenario 3 - Drawn Battlelines', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":3}]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"drawn-battlelines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines');

update missions set name = 'Scenario 4: Close Quarters', mode = 'normal', deployment_type = 'Scenario 4: Close Quarters', description = 'Matched Play Guide - Scenario 4 - Close Quarters',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":2}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Bottleneck**: see the full rules."]'::jsonb, terrain = '{"deployment":"close-quarters"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-4-close-quarters';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 4: Close Quarters', 'normal', 'https://tow.whfb.app/matched-play/scenario-4-close-quarters', 'Scenario 4: Close Quarters', 'Matched Play Guide - Scenario 4 - Close Quarters', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":2}]'::jsonb, '{}'::jsonb, '["**Bottleneck**: see the full rules."]'::jsonb, '{"deployment":"close-quarters"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-4-close-quarters');

update missions set name = 'Scenario 5: A Chance Encounter', mode = 'normal', deployment_type = 'Scenario 5: A Chance Encounter', description = 'Matched Play Guide - Scenario 5 - A Chance Encounter',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"chance-encounter"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 5: A Chance Encounter', 'normal', 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter', 'Scenario 5: A Chance Encounter', 'Matched Play Guide - Scenario 5 - A Chance Encounter', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"chance-encounter"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter');

update missions set name = 'Scenario 6: Encirclement', mode = 'normal', deployment_type = 'Scenario 6: Encirclement', description = 'Matched Play Guide - Scenario 6 - Encirclement',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":4}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"encirclement"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-6-encirclement';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 6: Encirclement', 'normal', 'https://tow.whfb.app/matched-play/scenario-6-encirclement', 'Scenario 6: Encirclement', 'Matched Play Guide - Scenario 6 - Encirclement', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":4}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"encirclement"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-6-encirclement');

update missions set name = 'Doubles 1: Double Envelopment', mode = 'normal', deployment_type = 'Doubles 1: Double Envelopment', description = 'Matched Play Guide - Doubles scenario 1 - Double Envelopment',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"double-envelopment"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 1: Double Envelopment', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment', 'Doubles 1: Double Envelopment', 'Matched Play Guide - Doubles scenario 1 - Double Envelopment', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"double-envelopment"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment');

update missions set name = 'Doubles 2: Forward Battlelines', mode = 'normal', deployment_type = 'Doubles 2: Forward Battlelines', description = 'Matched Play Guide - Doubles scenario 2 - Forward Battlelines',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"forward-battlelines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 2: Forward Battlelines', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines', 'Doubles 2: Forward Battlelines', 'Matched Play Guide - Doubles scenario 2 - Forward Battlelines', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"forward-battlelines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines');

update missions set name = 'Doubles 3: The Old Outpost', mode = 'normal', deployment_type = 'Doubles 3: The Old Outpost', description = 'Matched Play Guide - Doubles scenario 3 - The Old Outpost',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"old-outpost"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 3: The Old Outpost', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost', 'Doubles 3: The Old Outpost', 'Matched Play Guide - Doubles scenario 3 - The Old Outpost', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"old-outpost"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost');

update missions set name = 'A Timely Arrival', mode = 'normal', deployment_type = 'A Timely Arrival', description = 'Arcane Journal: Dawn of the Storm Dragon - A Timely Arrival',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"timely-arrival"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/a-timely-arrival';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'A Timely Arrival', 'normal', 'https://tow.whfb.app/narrative-battles/a-timely-arrival', 'A Timely Arrival', 'Arcane Journal: Dawn of the Storm Dragon - A Timely Arrival', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"timely-arrival"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/a-timely-arrival');

update missions set name = 'Ambush at Winter''s Teeth Pass', mode = 'normal', deployment_type = 'Ambush at Winter''s Teeth Pass', description = 'Arcane Journal: Orc & Goblin Tribes - Ambush at Winter''s Teeth Pass',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Late Snows**: see the full rules.","**Fleeing to Safety**: see the full rules."]'::jsonb, terrain = '{"deployment":"winters-teeth"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Ambush at Winter''s Teeth Pass', 'normal', 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass', 'Ambush at Winter''s Teeth Pass', 'Arcane Journal: Orc & Goblin Tribes - Ambush at Winter''s Teeth Pass', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Late Snows**: see the full rules.","**Fleeing to Safety**: see the full rules."]'::jsonb, '{"deployment":"winters-teeth"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass');

update missions set name = 'Assault on Leonen', mode = 'normal', deployment_type = 'Assault on Leonen', description = 'Arcane Journal: Dawn of the Storm Dragon - Assault on Leonen',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Gods Watch On!**: see the full rules.","**The Might of Grand Cathay**: see the full rules."]'::jsonb, terrain = '{"deployment":"assault-on-leonen"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/assault-on-leonen';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Assault on Leonen', 'normal', 'https://tow.whfb.app/narrative-battles/assault-on-leonen', 'Assault on Leonen', 'Arcane Journal: Dawn of the Storm Dragon - Assault on Leonen', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Gods Watch On!**: see the full rules.","**The Might of Grand Cathay**: see the full rules."]'::jsonb, '{"deployment":"assault-on-leonen"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/assault-on-leonen');

update missions set name = 'Clash at the Northern Crossroads', mode = 'normal', deployment_type = 'Clash at the Northern Crossroads', description = 'Arcane Journal: Beastmen Brayherds - Clash at the Northern Crossroads',
    turn_limit = null, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Break Point**: see the full rules.","**Heavy Snowfall**: see the full rules."]'::jsonb, terrain = '{"deployment":"northern-crossroads"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash at the Northern Crossroads', 'normal', 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads', 'Clash at the Northern Crossroads', 'Arcane Journal: Beastmen Brayherds - Clash at the Northern Crossroads', null, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Break Point**: see the full rules.","**Heavy Snowfall**: see the full rules."]'::jsonb, '{"deployment":"northern-crossroads"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads');

update missions set name = 'Clash on the Zandri Road', mode = 'normal', deployment_type = 'Clash on the Zandri Road', description = 'Arcane Journal: Tomb Kings of Khemri - Clash on the Zandri Road',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"zandri-road"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash on the Zandri Road', 'normal', 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road', 'Clash on the Zandri Road', 'Arcane Journal: Tomb Kings of Khemri - Clash on the Zandri Road', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"zandri-road"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road');

update missions set name = 'First Linked Battle', mode = 'normal', deployment_type = 'First Linked Battle', description = 'Warhammer: the Old World rulebook - First Linked Battle',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Surprise Battle**: see the full rules.","**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"first-linked"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/first-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'First Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/first-linked-battle', 'First Linked Battle', 'Warhammer: the Old World rulebook - First Linked Battle', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Surprise Battle**: see the full rules.","**Reserves**: see the full rules."]'::jsonb, '{"deployment":"first-linked"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/first-linked-battle');

update missions set name = 'Second Linked Battle', mode = 'normal', deployment_type = 'Second Linked Battle', description = 'Warhammer: the Old World rulebook - Second Linked Battle',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"second-linked"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/second-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Second Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/second-linked-battle', 'Second Linked Battle', 'Warhammer: the Old World rulebook - Second Linked Battle', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"second-linked"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/second-linked-battle');

update missions set name = 'Third Linked Battle', mode = 'normal', deployment_type = 'Third Linked Battle', description = 'Warhammer: the Old World rulebook - Third Linked Battle',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"third-linked"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/third-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Third Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/third-linked-battle', 'Third Linked Battle', 'Warhammer: the Old World rulebook - Third Linked Battle', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"third-linked"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/third-linked-battle');

update missions set name = 'Hallowed Ground', mode = 'normal', deployment_type = 'Hallowed Ground', description = 'Arcane Journal: The Razing of Westerland - Hallowed Ground',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Landmark**: see the full rules."]'::jsonb, terrain = '{"deployment":"hallowed-ground"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/hallowed-ground';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Hallowed Ground', 'normal', 'https://tow.whfb.app/narrative-battles/hallowed-ground', 'Hallowed Ground', 'Arcane Journal: The Razing of Westerland - Hallowed Ground', 5, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Landmark**: see the full rules."]'::jsonb, '{"deployment":"hallowed-ground"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/hallowed-ground');

update missions set name = 'Looting & Pillaging', mode = 'normal', deployment_type = 'Looting & Pillaging', description = 'Arcane Journal: The Razing of Westerland - Looting & Pillaging',
    turn_limit = 4, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Controlling the Baggage Train**: see the full rules.","**Looting the Baggage Train**: see the full rules."]'::jsonb, terrain = '{"deployment":"looting-and-pillaging"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/looting-and-pillaging';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Looting & Pillaging', 'normal', 'https://tow.whfb.app/narrative-battles/looting-and-pillaging', 'Looting & Pillaging', 'Arcane Journal: The Razing of Westerland - Looting & Pillaging', 4, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Controlling the Baggage Train**: see the full rules.","**Looting the Baggage Train**: see the full rules."]'::jsonb, '{"deployment":"looting-and-pillaging"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/looting-and-pillaging');

update missions set name = 'Reclamation of Hollum', mode = 'normal', deployment_type = 'Reclamation of Hollum', description = 'Arcane Journal: Dawn of the Storm Dragon - Reclamation of Hollum',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Judgement of the Gods**: see the full rules.","**The Storm Dragon''s Triumph**: see the full rules."]'::jsonb, terrain = '{"deployment":"reclamation-of-hollum"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Reclamation of Hollum', 'normal', 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum', 'Reclamation of Hollum', 'Arcane Journal: Dawn of the Storm Dragon - Reclamation of Hollum', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Judgement of the Gods**: see the full rules.","**The Storm Dragon''s Triumph**: see the full rules."]'::jsonb, '{"deployment":"reclamation-of-hollum"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum');

update missions set name = 'The Ruins of Hollum', mode = 'normal', deployment_type = 'The Ruins of Hollum', description = 'Arcane Journal: Warriors of Chaos - The Ruins of Hollum',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Judgement of the Gods**: see the full rules.","**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"ruins-of-hollum"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Ruins of Hollum', 'normal', 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum', 'The Ruins of Hollum', 'Arcane Journal: Warriors of Chaos - The Ruins of Hollum', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Judgement of the Gods**: see the full rules.","**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"ruins-of-hollum"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum');

update missions set name = 'The Battle of Châlons', mode = 'normal', deployment_type = 'The Battle of Châlons', description = 'Arcane Journal: High Elf Realms - The Battle of Châlons',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Drawn To Battle**: see the full rules."]'::jsonb, terrain = '{"deployment":"battle-of-chalons"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Châlons', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons', 'The Battle of Châlons', 'Arcane Journal: High Elf Realms - The Battle of Châlons', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Drawn To Battle**: see the full rules."]'::jsonb, '{"deployment":"battle-of-chalons"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons');

update missions set name = 'The Battle of Fort Nordenschloss', mode = 'normal', deployment_type = 'The Battle of Fort Nordenschloss', description = 'Arcane Journal: Warriors of Chaos - The Battle of Fort Nordenschloss',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"fort-nordenschloss"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Fort Nordenschloss', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss', 'The Battle of Fort Nordenschloss', 'Arcane Journal: Warriors of Chaos - The Battle of Fort Nordenschloss', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"fort-nordenschloss"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss');

update missions set name = 'The Battle of Matorea', mode = 'normal', deployment_type = 'The Battle of Matorea', description = 'Arcane Journal: Kingdom of Bretonnia - The Battle of Matorea',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules.","**Staked Defences**: see the full rules."]'::jsonb, terrain = '{"deployment":"battle-of-matorea"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Matorea', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea', 'The Battle of Matorea', 'Arcane Journal: Kingdom of Bretonnia - The Battle of Matorea', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules.","**Staked Defences**: see the full rules."]'::jsonb, '{"deployment":"battle-of-matorea"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea');

update missions set name = 'The Battle of Nan-Li', mode = 'normal', deployment_type = 'The Battle of Nan-Li', description = 'Arcane Journal: The Breaching of the Great Bastion - The Battle of Nan-Li',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Steadfast Presence**: see the full rules."]'::jsonb, terrain = '{"deployment":"battle-of-nan-li"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Nan-Li', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li', 'The Battle of Nan-Li', 'Arcane Journal: The Breaching of the Great Bastion - The Battle of Nan-Li', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Steadfast Presence**: see the full rules."]'::jsonb, '{"deployment":"battle-of-nan-li"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li');

update missions set name = 'The Battle of Stirhügel Hills', mode = 'normal', deployment_type = 'The Battle of Stirhügel Hills', description = 'Arcane Journal: Empire of Man - The Battle of Stirhügel Hills',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"stirhuegel-hills"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Stirhügel Hills', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills', 'The Battle of Stirhügel Hills', 'Arcane Journal: Empire of Man - The Battle of Stirhügel Hills', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"stirhuegel-hills"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills');

update missions set name = 'The Prophet & The Hunter', mode = 'normal', deployment_type = 'The Prophet & The Hunter', description = 'Arcane Journal: Wood Elf Realms - The Prophet & The Hunter',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Roaming Warherds**: see the full rules.","**Fighting to Safety**: see the full rules.","**Vengeful Wrath**: see the full rules."]'::jsonb, terrain = '{"deployment":"prophet-and-hunter"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Prophet & The Hunter', 'normal', 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter', 'The Prophet & The Hunter', 'Arcane Journal: Wood Elf Realms - The Prophet & The Hunter', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Roaming Warherds**: see the full rules.","**Fighting to Safety**: see the full rules.","**Vengeful Wrath**: see the full rules."]'::jsonb, '{"deployment":"prophet-and-hunter"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter');

update missions set name = 'The Storming of Khazid Vosk', mode = 'normal', deployment_type = 'The Storming of Khazid Vosk', description = 'Arcane Journal: Dwarfen Mountain Holds - The Storming of Khazid Vosk',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Mountains Are Crawling With ''Em**: see the full rules.","**Entrenched Besiegers**: see the full rules.","**The Gatehouse**: see the full rules."]'::jsonb, terrain = '{"deployment":"khazid-vosk"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Storming of Khazid Vosk', 'normal', 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk', 'The Storming of Khazid Vosk', 'Arcane Journal: Dwarfen Mountain Holds - The Storming of Khazid Vosk', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Mountains Are Crawling With ''Em**: see the full rules.","**Entrenched Besiegers**: see the full rules.","**The Gatehouse**: see the full rules."]'::jsonb, '{"deployment":"khazid-vosk"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk');

update missions set name = 'War in the Shadowlands', mode = 'normal', deployment_type = 'War in the Shadowlands', description = 'Arcane Journal: The Razing of Westerland - War in the Shadowlands',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Warrior''s Duel**: see the full rules."]'::jsonb, terrain = '{"deployment":"war-in-the-shadowlands"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'War in the Shadowlands', 'normal', 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands', 'War in the Shadowlands', 'Arcane Journal: The Razing of Westerland - War in the Shadowlands', 5, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Warrior''s Duel**: see the full rules."]'::jsonb, '{"deployment":"war-in-the-shadowlands"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands');

update missions set name = 'The Weisnicht Bridge', mode = 'battle-march', deployment_type = 'The Weisnicht Bridge', description = 'Battle March: General''s Companion - The Weisnicht Bridge',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Clash of Steel**: see the full rules."]'::jsonb, terrain = '{"deployment":"weisnicht-bridge"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-weisnicht-bridge';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Weisnicht Bridge', 'battle-march', 'https://tow.whfb.app/battle-march/the-weisnicht-bridge', 'The Weisnicht Bridge', 'Battle March: General''s Companion - The Weisnicht Bridge', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Clash of Steel**: see the full rules."]'::jsonb, '{"deployment":"weisnicht-bridge"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-weisnicht-bridge');

update missions set name = 'The Ambush of Bel-Cedas', mode = 'battle-march', deployment_type = 'The Ambush of Bel-Cedas', description = 'Battle March: General''s Companion - The Ambush of Bel-Cedas',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**It''s an Ambush!**: see the full rules."]'::jsonb, terrain = '{"deployment":"ambush-of-bel-cedas"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Ambush of Bel-Cedas', 'battle-march', 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas', 'The Ambush of Bel-Cedas', 'Battle March: General''s Companion - The Ambush of Bel-Cedas', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**It''s an Ambush!**: see the full rules."]'::jsonb, '{"deployment":"ambush-of-bel-cedas"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas');

update missions set name = 'Drazgog''s Raiders', mode = 'battle-march', deployment_type = 'Drazgog''s Raiders', description = 'Battle March: General''s Companion - Drazgog''s Raiders',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Loot the Barn**: see the full rules."]'::jsonb, terrain = '{"deployment":"drazgogs-raiders"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/drazgogs-raiders';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Drazgog''s Raiders', 'battle-march', 'https://tow.whfb.app/battle-march/drazgogs-raiders', 'Drazgog''s Raiders', 'Battle March: General''s Companion - Drazgog''s Raiders', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Loot the Barn**: see the full rules."]'::jsonb, '{"deployment":"drazgogs-raiders"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/drazgogs-raiders');

update missions set name = 'The Forges of Karak Ziflin', mode = 'battle-march', deployment_type = 'The Forges of Karak Ziflin', description = 'Battle March: General''s Companion - The Forges of Karak Ziflin',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{"objectives":[{"key":"strategic-landmark"}]}'::jsonb, special_rules = '["**Plenty o'' Sharp Stuff**: see the full rules."]'::jsonb, terrain = '{"deployment":"forges-of-karak-ziflin"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Forges of Karak Ziflin', 'battle-march', 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin', 'The Forges of Karak Ziflin', 'Battle March: General''s Companion - The Forges of Karak Ziflin', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{"objectives":[{"key":"strategic-landmark"}]}'::jsonb, '["**Plenty o'' Sharp Stuff**: see the full rules."]'::jsonb, '{"deployment":"forges-of-karak-ziflin"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin');

update missions set name = 'Clash at Sturdham', mode = 'battle-march', deployment_type = 'Clash at Sturdham', description = 'Battle March: General''s Companion - Clash at Sturdham',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Secure the Livestock!**: see the full rules."]'::jsonb, terrain = '{"deployment":"clash-at-sturdham"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/clash-at-sturdham';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash at Sturdham', 'battle-march', 'https://tow.whfb.app/battle-march/clash-at-sturdham', 'Clash at Sturdham', 'Battle March: General''s Companion - Clash at Sturdham', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Secure the Livestock!**: see the full rules."]'::jsonb, '{"deployment":"clash-at-sturdham"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/clash-at-sturdham');

update missions set name = 'Defence of Gemelwald', mode = 'battle-march', deployment_type = 'Defence of Gemelwald', description = 'Battle March: General''s Companion - Defence of Gemelwald',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Hold Fast!**: see the full rules.","**Ours for the Taking!**: see the full rules."]'::jsonb, terrain = '{"deployment":"defence-of-gemelwald"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/defence-of-gemelwald';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Defence of Gemelwald', 'battle-march', 'https://tow.whfb.app/battle-march/defence-of-gemelwald', 'Defence of Gemelwald', 'Battle March: General''s Companion - Defence of Gemelwald', 6, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Hold Fast!**: see the full rules.","**Ours for the Taking!**: see the full rules."]'::jsonb, '{"deployment":"defence-of-gemelwald"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/defence-of-gemelwald');
