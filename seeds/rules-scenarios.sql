-- ============================================================================
-- seeds/rules-scenarios.sql
--
-- The rules' own scenarios as official scenarios (campaign_id null), set up
-- the scenario builder's way: the rulebook's pitched battles, the Matched Play
-- Guide (with its doubles), the narrative battles and Battle March: Axe Bite
-- Pass. Each has its deployment map (the builder's exact map where it has
-- one, otherwise the nearest, with the rules' own map image shown alongside),
-- objectives, game length, the names of its special rules and a link to the
-- full rules on tow.whfb.app. The rules' wording itself isn't copied.
--
-- These are what everyone can pick in Play. A campaign's own scenarios only
-- show in that campaign's battles. Organisers copy one into their campaign
-- (Admin > Scenarios) to change it.
--
-- Safe to run more than once: each scenario is matched on its rules link and
-- updated, or added if it isn't there. Generated from the rules pages.
-- ============================================================================

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Open Battle', 'https://images.ctfassets.net/0v8db9sevlqj/7LggvP50VKWU3OopRTexXh/2e2d7def32691aab8244956cae65f7b9/open-battle.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/open-battle'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/open-battle');
update missions set name = 'Open Battle', mode = 'normal', deployment_type = 'Open Battle', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/open-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Open Battle', 'normal', 'https://tow.whfb.app/warhammer-battles/open-battle', 'Open Battle', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/open-battle');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Flank Attack', 'https://images.ctfassets.net/0v8db9sevlqj/3cFNz0niHYduLBCqCiTlrm/4952cb3bf6cfcb00a5ba1fef2e31d3b9/flank-attack.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/flank-attack'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/flank-attack');
update missions set name = 'Flank Attack', mode = 'normal', deployment_type = 'Flank Attack', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"flank-attack"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/flank-attack';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Flank Attack', 'normal', 'https://tow.whfb.app/warhammer-battles/flank-attack', 'Flank Attack', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"flank-attack"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/flank-attack');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Meeting Engagement', 'https://images.ctfassets.net/0v8db9sevlqj/7yZS62jMhWGPK5Zv18EwNa/9aecba2f4e9d5012884acd32723fad6e/meeting-engagement.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/meeting-engagement'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/meeting-engagement');
update missions set name = 'Meeting Engagement', mode = 'normal', deployment_type = 'Meeting Engagement', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"meeting-engagement"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/meeting-engagement';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Meeting Engagement', 'normal', 'https://tow.whfb.app/warhammer-battles/meeting-engagement', 'Meeting Engagement', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"meeting-engagement"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/meeting-engagement');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Mountain Pass', 'https://images.ctfassets.net/0v8db9sevlqj/xwmN1DZUQfqNwWqj6aDM6/ed147f8a1b27eddb0818e8948bb68c60/mountain-pass.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/mountain-pass'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/mountain-pass');
update missions set name = 'Mountain Pass', mode = 'normal', deployment_type = 'Mountain Pass', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Bottleneck**: see the full rules."]'::jsonb, terrain = '{"deployment":"mountain-pass"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/mountain-pass';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Mountain Pass', 'normal', 'https://tow.whfb.app/warhammer-battles/mountain-pass', 'Mountain Pass', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Bottleneck**: see the full rules."]'::jsonb, '{"deployment":"mountain-pass"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/mountain-pass');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Command & Control', 'https://images.ctfassets.net/0v8db9sevlqj/6opUfcxsYRURY4MpEjWUAy/f5e6a495c86135dc2ca15ceade552f78/command-and-control.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/command-and-control'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/command-and-control');
update missions set name = 'Command & Control', mode = 'normal', deployment_type = 'Command & Control', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"command-and-control"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/command-and-control';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Command & Control', 'normal', 'https://tow.whfb.app/warhammer-battles/command-and-control', 'Command & Control', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"command-and-control"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/command-and-control');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Break Point', 'https://images.ctfassets.net/0v8db9sevlqj/1QaDPpMQ6PGcxRUwA0MvtH/11bd0355e389a46615973f6d98839ad3/break-point.png', null, 'normal', 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles');
update missions set name = 'Break Point', mode = 'normal', deployment_type = 'Break Point', description = 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Break Point**: see the full rules."]'::jsonb, terrain = '{"deployment":"break-point"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Break Point', 'normal', 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles', 'Break Point', 'From the Warhammer: the Old World rulebook. Read the full rules for set-up, deployment and victory conditions.', null, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Break Point**: see the full rules."]'::jsonb, '{"deployment":"break-point"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/warhammer-battles/break-point-warhammer-battles');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 1: Upon the Field of Glory', 'https://images.ctfassets.net/0v8db9sevlqj/71XJ9iRzVDWOewcbgi1t7D/ce4827bd047c2b8cd108a0f3f82f2f15/matched-play-scenario-1.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory');
update missions set name = 'Scenario 1: Upon the Field of Glory', mode = 'normal', deployment_type = 'Scenario 1: Upon the Field of Glory', description = 'From the Matched Play Guide. May also use Strategic Locations, Special Feature, Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"field-of-glory"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 1: Upon the Field of Glory', 'normal', 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory', 'Scenario 1: Upon the Field of Glory', 'From the Matched Play Guide. May also use Strategic Locations, Special Feature, Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"field-of-glory"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-1-upon-the-field-of-glory');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 2: King of the Hill', 'https://images.ctfassets.net/0v8db9sevlqj/3gej5n3C1GXdklrGwA0SQu/0284e27ee9404005c62a49da83dfafe4/matched-play-scenario-2.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill');
update missions set name = 'Scenario 2: King of the Hill', mode = 'normal', deployment_type = 'Scenario 2: King of the Hill', description = 'From the Matched Play Guide. May also use Special Feature or Baggage Trains: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Hill**: see the full rules.","**Running up-hill**: see the full rules.","**Victory Points**: see the full rules."]'::jsonb, terrain = '{"deployment":"king-of-the-hill"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 2: King of the Hill', 'normal', 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill', 'Scenario 2: King of the Hill', 'From the Matched Play Guide. May also use Special Feature or Baggage Trains: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Hill**: see the full rules.","**Running up-hill**: see the full rules.","**Victory Points**: see the full rules."]'::jsonb, '{"deployment":"king-of-the-hill"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-2-king-of-the-hill');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 3: Drawn Battlelines', 'https://images.ctfassets.net/0v8db9sevlqj/1b1cRrSilD0q4y4FJQuGIT/3ffe4c9b594160a12a0a6c3feaed8c3c/matched-play-scenario-3.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines');
update missions set name = 'Scenario 3: Drawn Battlelines', mode = 'normal', deployment_type = 'Scenario 3: Drawn Battlelines', description = 'From the Matched Play Guide. May also use Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":3}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"drawn-battlelines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 3: Drawn Battlelines', 'normal', 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines', 'Scenario 3: Drawn Battlelines', 'From the Matched Play Guide. May also use Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":3}]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"drawn-battlelines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-3-drawn-battlelines');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 4: Close Quarters', 'https://images.ctfassets.net/0v8db9sevlqj/4Wi7e767Zaa6R2QnlgCkRU/cbdadbc0460ecc7b7829616b6367d617/matched-play-scenario-4.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-4-close-quarters'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-4-close-quarters');
update missions set name = 'Scenario 4: Close Quarters', mode = 'normal', deployment_type = 'Scenario 4: Close Quarters', description = 'From the Matched Play Guide. May also use Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":2}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Bottleneck**: see the full rules."]'::jsonb, terrain = '{"deployment":"close-quarters"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-4-close-quarters';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 4: Close Quarters', 'normal', 'https://tow.whfb.app/matched-play/scenario-4-close-quarters', 'Scenario 4: Close Quarters', 'From the Matched Play Guide. May also use Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":2}]'::jsonb, '{}'::jsonb, '["**Bottleneck**: see the full rules."]'::jsonb, '{"deployment":"close-quarters"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-4-close-quarters');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 5: A Chance Encounter', 'https://images.ctfassets.net/0v8db9sevlqj/54fJ5eMAfCnWXT7cfLL428/e51f80f979439f6f402c66f30910321c/matched-play-scenario-5.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter');
update missions set name = 'Scenario 5: A Chance Encounter', mode = 'normal', deployment_type = 'Scenario 5: A Chance Encounter', description = 'From the Matched Play Guide. May also use Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"chance-encounter"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 5: A Chance Encounter', 'normal', 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter', 'Scenario 5: A Chance Encounter', 'From the Matched Play Guide. May also use Baggage Trains or Domination: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"chance-encounter"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-5-a-chance-encounter');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Scenario 6: Encirclement', 'https://images.ctfassets.net/0v8db9sevlqj/Si4zrpWkeLusTso2jPfX5/f86e3f51d942b5756debc00fee2768bd/matched-play-scenario-6.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/scenario-6-encirclement'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-6-encirclement');
update missions set name = 'Scenario 6: Encirclement', mode = 'normal', deployment_type = 'Scenario 6: Encirclement', description = 'From the Matched Play Guide. May also use Special Feature or Baggage Trains: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"strategic-locations","count":4}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"encirclement"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-6-encirclement';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Scenario 6: Encirclement', 'normal', 'https://tow.whfb.app/matched-play/scenario-6-encirclement', 'Scenario 6: Encirclement', 'From the Matched Play Guide. May also use Special Feature or Baggage Trains: switch them on when you set up the battle. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"strategic-locations","count":4}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"encirclement"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/scenario-6-encirclement');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Doubles 1: Double Envelopment', 'https://images.ctfassets.net/0v8db9sevlqj/UUrx4PZ8LMpoBbLrVcMgP/95881f3d7d13718a7e32a473cc522e92/matched-play-doubles-scenario-1.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment');
update missions set name = 'Doubles 1: Double Envelopment', mode = 'normal', deployment_type = 'Doubles 1: Double Envelopment', description = 'From the Matched Play Guide. May also use Strategic Locations, Special Feature, Baggage Trains or Domination: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"flank-attack"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 1: Double Envelopment', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment', 'Doubles 1: Double Envelopment', 'From the Matched Play Guide. May also use Strategic Locations, Special Feature, Baggage Trains or Domination: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reserves**: see the full rules."]'::jsonb, '{"deployment":"flank-attack"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-1-double-envelopment');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Doubles 2: Forward Battlelines', 'https://images.ctfassets.net/0v8db9sevlqj/1sEA4Y6QJCctKLeYicKuX6/5ed870f0931354cadb0912e98b3fc006/matched-play-doubles-scenario-2.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines');
update missions set name = 'Doubles 2: Forward Battlelines', mode = 'normal', deployment_type = 'Doubles 2: Forward Battlelines', description = 'From the Matched Play Guide. May also use Strategic Locations or Baggage Trains: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 2: Forward Battlelines', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines', 'Doubles 2: Forward Battlelines', 'From the Matched Play Guide. May also use Strategic Locations or Baggage Trains: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-2-forward-battlelines');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Doubles 3: The Old Outpost', 'https://images.ctfassets.net/0v8db9sevlqj/2Scce5Zy92DXrCI7fuoKzA/3f057004529b43a42eb40a9c6648f4e7/matched-play-doubles-scenario-3.jpg', null, 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost');
update missions set name = 'Doubles 3: The Old Outpost', mode = 'normal', deployment_type = 'Doubles 3: The Old Outpost', description = 'From the Matched Play Guide. May also use Strategic Locations or Baggage Trains: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Doubles 3: The Old Outpost', 'normal', 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost', 'Doubles 3: The Old Outpost', 'From the Matched Play Guide. May also use Strategic Locations or Baggage Trains: switch them on when you set up the battle. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/matched-play/doubles-scenario-3-the-old-outpost');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'A Timely Arrival', 'https://images.ctfassets.net/0v8db9sevlqj/78BN3empgHD7b3JfK4MxFG/ae98e40a7c259efee210a10720765aa1/a-timely-arrival.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/a-timely-arrival'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/a-timely-arrival');
update missions set name = 'A Timely Arrival', mode = 'normal', deployment_type = 'A Timely Arrival', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/a-timely-arrival';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'A Timely Arrival', 'normal', 'https://tow.whfb.app/narrative-battles/a-timely-arrival', 'A Timely Arrival', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/a-timely-arrival');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Ambush at Winter''s Teeth Pass', 'https://images.ctfassets.net/0v8db9sevlqj/3bxcEtoIpjLnZPRpIujDsA/13d58f3b049f48be9494b06d43eb230b/ambush-at-winters-teeth-pass.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass');
update missions set name = 'Ambush at Winter''s Teeth Pass', mode = 'normal', deployment_type = 'Ambush at Winter''s Teeth Pass', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Late Snows**: see the full rules.","**Fleeing to Safety**: see the full rules."]'::jsonb, terrain = '{"deployment":"flank-attack"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Ambush at Winter''s Teeth Pass', 'normal', 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass', 'Ambush at Winter''s Teeth Pass', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Late Snows**: see the full rules.","**Fleeing to Safety**: see the full rules."]'::jsonb, '{"deployment":"flank-attack"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/ambush-at-winters-teeth-pass');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Assault on Leonen', 'https://images.ctfassets.net/0v8db9sevlqj/6Xolp5BBcxiCzpVDCtcTCj/53cf9bb9db6d7e5d67a6fcf4303c97a6/assault-on-leonen.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/assault-on-leonen'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/assault-on-leonen');
update missions set name = 'Assault on Leonen', mode = 'normal', deployment_type = 'Assault on Leonen', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Gods Watch On!**: see the full rules.","**The Might of Grand Cathay**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/assault-on-leonen';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Assault on Leonen', 'normal', 'https://tow.whfb.app/narrative-battles/assault-on-leonen', 'Assault on Leonen', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Gods Watch On!**: see the full rules.","**The Might of Grand Cathay**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/assault-on-leonen');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Clash at the Northern Crossroads', 'https://images.ctfassets.net/0v8db9sevlqj/3T9bynn7vLr2X8ZlALHM0k/d85452113c87341e6a888a3173d9ea35/clash-at-the-northern-crossroads.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads');
update missions set name = 'Clash at the Northern Crossroads', mode = 'normal', deployment_type = 'Clash at the Northern Crossroads', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Break Point**: see the full rules.","**Heavy Snowfall**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash at the Northern Crossroads', 'normal', 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads', 'Clash at the Northern Crossroads', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', null, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Break Point**: see the full rules.","**Heavy Snowfall**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-at-the-northern-crossroads');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Clash on the Zandri Road', 'https://images.ctfassets.net/0v8db9sevlqj/6FWeyEzXjI5CZ9lWEQNg9o/afbcb5ce90792b2165ac0f3f29fca241/clash-on-the-zandri-road.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road');
update missions set name = 'Clash on the Zandri Road', mode = 'normal', deployment_type = 'Clash on the Zandri Road', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash on the Zandri Road', 'normal', 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road', 'Clash on the Zandri Road', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/clash-on-the-zandri-road');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'First Linked Battle', 'https://images.ctfassets.net/0v8db9sevlqj/439wy8OAc03a0xa2CEs239/c870f6e848ff0a796c73d28377d9ea8e/surprise-encounter.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/first-linked-battle'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/first-linked-battle');
update missions set name = 'First Linked Battle', mode = 'normal', deployment_type = 'First Linked Battle', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Surprise Battle**: see the full rules.","**Reserves**: see the full rules."]'::jsonb, terrain = '{"deployment":"chance-encounter"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/first-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'First Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/first-linked-battle', 'First Linked Battle', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Surprise Battle**: see the full rules.","**Reserves**: see the full rules."]'::jsonb, '{"deployment":"chance-encounter"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/first-linked-battle');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Second Linked Battle', 'https://images.ctfassets.net/0v8db9sevlqj/5FFzchiKzWWtcqc1KL91yi/f0595a0b9d0cb6ad91dce281e21a69eb/the-dark-monolith.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/second-linked-battle'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/second-linked-battle');
update missions set name = 'Second Linked Battle', mode = 'normal', deployment_type = 'Second Linked Battle', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = null, random_length = true, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[{"key":"special-feature"}]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"king-of-the-hill"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/second-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Second Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/second-linked-battle', 'Second Linked Battle', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', null, true, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[{"key":"special-feature"}]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"king-of-the-hill"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/second-linked-battle');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Third Linked Battle', 'https://images.ctfassets.net/0v8db9sevlqj/4yvvRuTRxzHpfGnKeQYmDs/4075d35caa2ce7db0668b37e04cf108e/heroic-last-stand.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/third-linked-battle'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/third-linked-battle');
update missions set name = 'Third Linked Battle', mode = 'normal', deployment_type = 'Third Linked Battle', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '[]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/third-linked-battle';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Third Linked Battle', 'normal', 'https://tow.whfb.app/narrative-battles/third-linked-battle', 'Third Linked Battle', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/third-linked-battle');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Hallowed Ground', 'https://images.ctfassets.net/0v8db9sevlqj/1yEC7L4s45q84yV2q3QeZq/659ca9c96f2800783878c683dce30fc4/hallowed-ground.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/hallowed-ground'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/hallowed-ground');
update missions set name = 'Hallowed Ground', mode = 'normal', deployment_type = 'Hallowed Ground', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Landmark**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/hallowed-ground';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Hallowed Ground', 'normal', 'https://tow.whfb.app/narrative-battles/hallowed-ground', 'Hallowed Ground', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Landmark**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/hallowed-ground');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Looting & Pillaging', 'https://images.ctfassets.net/0v8db9sevlqj/3tI6ukjyBUlQDfSdiZDt9j/36f3b37b8084a2f081a5f84e7ff2e2df/looting-and-pillaging.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/looting-and-pillaging'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/looting-and-pillaging');
update missions set name = 'Looting & Pillaging', mode = 'normal', deployment_type = 'Looting & Pillaging', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 4, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Controlling the Baggage Train**: see the full rules.","**Looting the Baggage Train**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/looting-and-pillaging';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Looting & Pillaging', 'normal', 'https://tow.whfb.app/narrative-battles/looting-and-pillaging', 'Looting & Pillaging', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 4, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Controlling the Baggage Train**: see the full rules.","**Looting the Baggage Train**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/looting-and-pillaging');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Reclamation of Hollum', 'https://images.ctfassets.net/0v8db9sevlqj/5nf8x9BpJVRZZCdrUHGbrq/f578d7eb792f8ac665da6ac9689e4eb3/reclamation-of-hollum.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum');
update missions set name = 'Reclamation of Hollum', mode = 'normal', deployment_type = 'Reclamation of Hollum', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Judgement of the Gods**: see the full rules.","**The Storm Dragon''s Triumph**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Reclamation of Hollum', 'normal', 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum', 'Reclamation of Hollum', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Judgement of the Gods**: see the full rules.","**The Storm Dragon''s Triumph**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/reclamation-of-hollum');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Ruins of Hollum', 'https://images.ctfassets.net/0v8db9sevlqj/jmXDTGH8kb3Q1YdrtsJmJ/2895e996f09b9871eb88688281f9c727/ruins-of-hollum.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum');
update missions set name = 'The Ruins of Hollum', mode = 'normal', deployment_type = 'The Ruins of Hollum', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Judgement of the Gods**: see the full rules.","**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Ruins of Hollum', 'normal', 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum', 'The Ruins of Hollum', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Judgement of the Gods**: see the full rules.","**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-ruins-of-hollum');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Battle of Châlons', 'https://images.ctfassets.net/0v8db9sevlqj/7tbbCM3Qi6WeVuNqAoZqJ6/3c12c5346e85656a997ef6f341a037e6/battle-of-chalons.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons');
update missions set name = 'The Battle of Châlons', mode = 'normal', deployment_type = 'The Battle of Châlons', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Drawn To Battle**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Châlons', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons', 'The Battle of Châlons', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Drawn To Battle**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-chalons');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Battle of Fort Nordenschloss', 'https://images.ctfassets.net/0v8db9sevlqj/6FyOg8y2Q2lJbehpWgzdmU/6549fd90f689ea94309b94de734a063d/the-battle-of-fort-nordenschloss.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss');
update missions set name = 'The Battle of Fort Nordenschloss', mode = 'normal', deployment_type = 'The Battle of Fort Nordenschloss', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Fort Nordenschloss', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss', 'The Battle of Fort Nordenschloss', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-fort-nordenschloss');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Battle of Matorea', 'https://images.ctfassets.net/0v8db9sevlqj/6RQO55ydEERIvrRudY1FdO/b7edeb56d36c472a7f8e5d620ba378bd/the-battle-of-matorea.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea');
update missions set name = 'The Battle of Matorea', mode = 'normal', deployment_type = 'The Battle of Matorea', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules.","**Staked Defences**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Matorea', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea', 'The Battle of Matorea', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules.","**Staked Defences**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-matorea');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Battle of Nan-Li', 'https://images.ctfassets.net/0v8db9sevlqj/2oYX9tyhaTePGlh5FRCJ1n/48324a884f2cf9ce06374fa7a8add802/the-battle-of-nan-li.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li');
update missions set name = 'The Battle of Nan-Li', mode = 'normal', deployment_type = 'The Battle of Nan-Li', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Steadfast Presence**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Nan-Li', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li', 'The Battle of Nan-Li', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Steadfast Presence**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-nan-li');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Battle of Stirhügel Hills', 'https://images.ctfassets.net/0v8db9sevlqj/4Cqp7d2BTJKUlIqVSXRgP7/a87c1e65afb4e187404431608620c1dd/the-battle-of-stirhuegel-hills.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills');
update missions set name = 'The Battle of Stirhügel Hills', mode = 'normal', deployment_type = 'The Battle of Stirhügel Hills', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Reinforcements**: see the full rules."]'::jsonb, terrain = '{"deployment":"chance-encounter"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Battle of Stirhügel Hills', 'normal', 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills', 'The Battle of Stirhügel Hills', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Reinforcements**: see the full rules."]'::jsonb, '{"deployment":"chance-encounter"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-battle-of-stirhuegel-hills');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Prophet & The Hunter', 'https://images.ctfassets.net/0v8db9sevlqj/2PHgovYQq0XBKnPdR1IxWs/4cd4a7ccf1b48204d174652a8d1c109e/the-prophet-and-the-hunter-battle.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter');
update missions set name = 'The Prophet & The Hunter', mode = 'normal', deployment_type = 'The Prophet & The Hunter', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Roaming Warherds**: see the full rules.","**Fighting to Safety**: see the full rules.","**Vengeful Wrath**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Prophet & The Hunter', 'normal', 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter', 'The Prophet & The Hunter', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Roaming Warherds**: see the full rules.","**Fighting to Safety**: see the full rules.","**Vengeful Wrath**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-prophet-and-the-hunter');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Storming of Khazid Vosk', 'https://images.ctfassets.net/0v8db9sevlqj/6XhYKe9bcSNnNELdmSkDEa/06cf337394afb7c0f654fbc887e3c7fb/the-storming-of-khazid-vosk.png', null, 'normal', 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk');
update missions set name = 'The Storming of Khazid Vosk', mode = 'normal', deployment_type = 'The Storming of Khazid Vosk', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**The Mountains Are Crawling With ''Em**: see the full rules.","**Entrenched Besiegers**: see the full rules.","**The Gatehouse**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Storming of Khazid Vosk', 'normal', 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk', 'The Storming of Khazid Vosk', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**The Mountains Are Crawling With ''Em**: see the full rules.","**Entrenched Besiegers**: see the full rules.","**The Gatehouse**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/the-storming-of-khazid-vosk');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'War in the Shadowlands', 'https://images.ctfassets.net/0v8db9sevlqj/5VzcWbuW4gmaR0BskVbNxM/66a6945c55fdff46950b0f6aa630b3bb/war-in-shadowlands.jpg', null, 'normal', 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands');
update missions set name = 'War in the Shadowlands', mode = 'normal', deployment_type = 'War in the Shadowlands', description = 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Warrior''s Duel**: see the full rules."]'::jsonb, terrain = '{"deployment":"open-battle"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'War in the Shadowlands', 'normal', 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands', 'War in the Shadowlands', 'A narrative battle from the Warhammer: the Old World rules. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war', 'breaking-the-enemy']::text[], '[]'::jsonb, '{}'::jsonb, '["**Warrior''s Duel**: see the full rules."]'::jsonb, '{"deployment":"open-battle"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/narrative-battles/war-in-the-shadowlands');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Weisnicht Bridge', 'https://images.ctfassets.net/0v8db9sevlqj/5X13x9gYhBPfkO6WSJ6aj0/83968387c5d903fa7f18a6d09e461555/01-the-weisnicht-bridge.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/the-weisnicht-bridge'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-weisnicht-bridge');
update missions set name = 'The Weisnicht Bridge', mode = 'battle-march', deployment_type = 'The Weisnicht Bridge', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Clash of Steel**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-weisnicht-bridge';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Weisnicht Bridge', 'battle-march', 'https://tow.whfb.app/battle-march/the-weisnicht-bridge', 'The Weisnicht Bridge', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Clash of Steel**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-weisnicht-bridge');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Ambush of Bel-Cedas', 'https://images.ctfassets.net/0v8db9sevlqj/SuO3bX5oO5aB0INE79nPu/2de977268d430cabfc343f2eb7ccf09a/02-ambush-of-bel-cedas.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas');
update missions set name = 'The Ambush of Bel-Cedas', mode = 'battle-march', deployment_type = 'The Ambush of Bel-Cedas', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**It''s an Ambush!**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Ambush of Bel-Cedas', 'battle-march', 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas', 'The Ambush of Bel-Cedas', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**It''s an Ambush!**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-ambush-of-bel-cedas');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Drazgog''s Raiders', 'https://images.ctfassets.net/0v8db9sevlqj/2njmxER2TiEaF6vCAQZhJ/3717ca8c204a1347e2b310b266e0260d/03-drazgogs-raiders.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/drazgogs-raiders'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/drazgogs-raiders');
update missions set name = 'Drazgog''s Raiders', mode = 'battle-march', deployment_type = 'Drazgog''s Raiders', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Loot the Barn**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/drazgogs-raiders';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Drazgog''s Raiders', 'battle-march', 'https://tow.whfb.app/battle-march/drazgogs-raiders', 'Drazgog''s Raiders', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Loot the Barn**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/drazgogs-raiders');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'The Forges of Karak Ziflin', 'https://images.ctfassets.net/0v8db9sevlqj/7MU10DDlZrP2jEG9DqWu4O/f29891f22bb351999bf171ee378ea97b/04-forges-of-karak-ziflin.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin');
update missions set name = 'The Forges of Karak Ziflin', mode = 'battle-march', deployment_type = 'The Forges of Karak Ziflin', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{"objectives":[{"key":"strategic-landmark"}]}'::jsonb, special_rules = '["**Plenty o'' Sharp Stuff**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'The Forges of Karak Ziflin', 'battle-march', 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin', 'The Forges of Karak Ziflin', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{"objectives":[{"key":"strategic-landmark"}]}'::jsonb, '["**Plenty o'' Sharp Stuff**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/the-forges-of-karak-ziflin');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Clash at Sturdham', 'https://images.ctfassets.net/0v8db9sevlqj/2QzDiym24j8GE1Q9bLEo8R/c591a146a3d51570e321467ef76f70d9/05-clash-at-sturdham.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/clash-at-sturdham'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/clash-at-sturdham');
update missions set name = 'Clash at Sturdham', mode = 'battle-march', deployment_type = 'Clash at Sturdham', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 5, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Secure the Livestock!**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/clash-at-sturdham';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Clash at Sturdham', 'battle-march', 'https://tow.whfb.app/battle-march/clash-at-sturdham', 'Clash at Sturdham', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 5, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Secure the Livestock!**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/clash-at-sturdham');

insert into maps (name, image_path, campaign_id, mode, rules_url)
select 'Defence of Gemelwald', 'https://images.ctfassets.net/0v8db9sevlqj/5wNppw72TgWlzloxAjr07m/e17224a53f6b8993b4c76a3561895b65/06-defence-of-gemelward.jpg', null, 'battle-march', 'https://tow.whfb.app/battle-march/defence-of-gemelwald'
where not exists (select 1 from maps where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/defence-of-gemelwald');
update missions set name = 'Defence of Gemelwald', mode = 'battle-march', deployment_type = 'Defence of Gemelwald', description = 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.',
    turn_limit = 6, random_length = false, common_objectives = array['king-is-dead', 'trophies-of-war']::text[], secondary_objectives = '[]'::jsonb,
    battle_march = '{}'::jsonb, special_rules = '["**Hold Fast!**: see the full rules.","**Ours for the Taking!**: see the full rules."]'::jsonb, terrain = '{"deployment":"bm-lines"}'::jsonb
  where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/defence-of-gemelwald';
insert into missions (name, mode, rules_url, deployment_type, description, turn_limit, random_length, common_objectives, secondary_objectives, battle_march, special_rules, terrain, campaign_id)
select 'Defence of Gemelwald', 'battle-march', 'https://tow.whfb.app/battle-march/defence-of-gemelwald', 'Defence of Gemelwald', 'From the Battle March: Axe Bite Pass. The table here is an approximation: the rules’ own map is shown with it. Read the full rules for set-up, deployment and victory conditions.', 6, false, array['king-is-dead', 'trophies-of-war']::text[], '[]'::jsonb, '{}'::jsonb, '["**Hold Fast!**: see the full rules.","**Ours for the Taking!**: see the full rules."]'::jsonb, '{"deployment":"bm-lines"}'::jsonb, null
where not exists (select 1 from missions where campaign_id is null and rules_url = 'https://tow.whfb.app/battle-march/defence-of-gemelwald');

