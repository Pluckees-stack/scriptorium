-- ============================================================================
-- 081_scenario_editor.sql
--
-- The one-page scenario editor in Admin > Scenarios: Normal battles or
-- Battle March, battle sizes, composition, and the scenario's own set-up,
-- deployment and first turn text (filled in from the online rules when you
-- start from a rules scenario).
--
-- 1. missions gains:
--      mode             'normal' or 'battle-march'
--      game_sizes       battle sizes it's for, e.g. {0-499,500-750} (Battle March is 750 points at most)
--      composition      'standard' or 'square-based' (Square Based Comp)
--      rules_url        the scenario's page on tow.whfb.app, if any
--      description      the scenario's introduction
--      setup_text, deployment_text, first_turn_text
--      battle_march     Battle March options: {"objectives":[{"key":..,"count":..}],
--                       "secondary":[..], "secret_objectives":bool,
--                       "random_happenings":[..]}
--    Existing scenarios are Normal battles with nothing else set.
-- 2. maps gains mode ('normal' or 'battle-march') and rules_url, and the
--    six Battle March deployment maps are added as official maps (images
--    from the online rules).
--
-- Run before merging the scenario editor index.html.
--
-- To undo:
--   delete from maps where campaign_id is null and mode = 'battle-march';
--   alter table maps drop column if exists mode, drop column if exists rules_url;
--   alter table missions drop column if exists mode, drop column if exists game_sizes,
--     drop column if exists composition, drop column if exists rules_url,
--     drop column if exists description, drop column if exists setup_text,
--     drop column if exists deployment_text, drop column if exists first_turn_text,
--     drop column if exists battle_march;
-- ============================================================================

alter table missions add column if not exists mode text not null default 'normal';
alter table missions add column if not exists game_sizes text[] not null default '{}';
alter table missions add column if not exists composition text not null default 'standard';
alter table missions add column if not exists rules_url text;
alter table missions add column if not exists description text;
alter table missions add column if not exists setup_text text;
alter table missions add column if not exists deployment_text text;
alter table missions add column if not exists first_turn_text text;
alter table missions add column if not exists battle_march jsonb not null default '{}'::jsonb;

alter table missions drop constraint if exists missions_mode_check;
alter table missions add constraint missions_mode_check check (mode in ('normal', 'battle-march'));
alter table missions drop constraint if exists missions_composition_check;
alter table missions add constraint missions_composition_check check (composition in ('standard', 'square-based'));

alter table maps add column if not exists mode text not null default 'normal';
alter table maps add column if not exists rules_url text;
alter table maps drop constraint if exists maps_mode_check;
alter table maps add constraint maps_mode_check check (mode in ('normal', 'battle-march'));

insert into maps (name, image_path, campaign_id, mode, rules_url)
select v.name, v.image_path, null, 'battle-march', 'https://tow.whfb.app/battle-march/battle-march-deployment-maps'
  from (values
    ('Battle March 1: Pitched Battle',      'https://images.ctfassets.net/0v8db9sevlqj/4kfT32oecstgXeinKI3BpO/2716f7e4a87522f06324a27a8d1d4d4b/battle-march-deployment-01.jpg'),
    ('Battle March 2: Close Encounter',     'https://images.ctfassets.net/0v8db9sevlqj/76x0bcOt80N3hXmuNGrDZB/a24e2aff33886c2f240a35dace45b413/battle-march-deployment-02.jpg'),
    ('Battle March 3: Opposed Flanks',      'https://images.ctfassets.net/0v8db9sevlqj/1OJKBm2ajYk9mHVw1AY7f4/99b410019010885f3f48c00b75b49d0a/battle-march-deployment-03.jpg'),
    ('Battle March 4: Meeting Engagement',  'https://images.ctfassets.net/0v8db9sevlqj/7lMC989fnoIdrF01kwIttW/df41568da051944257f4727a4288ac5b/battle-march-deployment-04.jpg'),
    ('Battle March 5: Mountain Pass',       'https://images.ctfassets.net/0v8db9sevlqj/DkznBSsAQGaQawMEreSNu/27c8253b31c4d67711777bd997e6af84/battle-march-deployment-05.jpg'),
    ('Battle March 6: Outflank',            'https://images.ctfassets.net/0v8db9sevlqj/41FXryfDNBkDi3NoDa9AV2/8052bd7bb3d48c61e5d4a62d98b159a4/battle-march-deployment-06.jpg')
  ) as v(name, image_path)
 where not exists (select 1 from maps m where m.campaign_id is null and m.name = v.name);
