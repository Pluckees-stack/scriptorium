-- ============================================================================
-- 038_custom_objectives.sql
--
-- Backs Mission Admin's new "Custom objectives" picker/creator (step 3 of
-- the mission wizard): bespoke objectives with their own name, description
-- and reward (VP / XP / Campaign points, any combination), same
-- official/campaign-custom hybrid as maps/missions/trait_objectives
-- (campaign_id null = official, visible in every campaign).
--
-- Definition only for now -- rewards are recorded as data but nothing pays
-- them out yet. Actually awarding XP/VP/CP when a battle is logged (End
-- Game UI, scoring changes) is a separate, larger follow-up.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists custom_objectives (
  id                      uuid primary key default gen_random_uuid(),
  name                    text not null,
  description             text not null,
  category                text not null check (category in ('common', 'secondary')),
  faction_id              text references factions(id),   -- null = any faction
  reward_vp               integer,
  reward_xp               integer,
  reward_campaign_points  integer,
  campaign_id             uuid references campaigns(id) on delete cascade,
  created_by              uuid references players(id) on delete set null,
  created_at              timestamptz not null default now()
);
create index if not exists custom_objectives_campaign_id_idx on custom_objectives (campaign_id);
alter table custom_objectives enable row level security;

drop policy if exists "read official or own-campaign custom objectives" on custom_objectives;
create policy "read official or own-campaign custom objectives" on custom_objectives
  for select to authenticated
  using (campaign_id is null or is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "admins manage official custom objectives" on custom_objectives;
create policy "admins manage official custom objectives" on custom_objectives
  for all to authenticated
  using (campaign_id is null and is_platform_admin())
  with check (campaign_id is null and is_platform_admin());

drop policy if exists "organisers manage campaign custom objectives" on custom_objectives;
create policy "organisers manage campaign custom objectives" on custom_objectives
  for all to authenticated
  using (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()))
  with check (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()));

alter table missions add column if not exists custom_objective_ids uuid[] not null default '{}';
