-- ============================================================================
-- 003_scope_alliances_rosters_games.sql
--
-- Phase 1, part 3 of 7.
--
-- Adds campaign_id to the three tables that can't be scoped by inference:
--   - alliances   the "teams" on the standings hub. These only mean
--                 something inside one campaign -- two different campaigns
--                 could each have an alliance called "The Iron Covenant"
--                 and they must not be treated as the same team. Was global
--                 admin-write reference data pre-multi-tenancy; becomes
--                 organiser-writable per campaign in Phase 2.
--   - rosters     a player's army list. Needs disambiguating once a player
--                 can belong to more than one campaign.
--   - games       a logged battle. Needs disambiguating for the same
--                 reason -- two players who happen to share two campaigns
--                 together would otherwise produce an ambiguous game row.
--
-- All existing rows are backfilled onto the seed campaign created in
-- 001_campaigns_and_membership.sql. Run that file first.
--
-- Existing RLS policies on these three tables are untouched by this file --
-- they'll keep granting the same (pre-multi-tenant, effectively "global")
-- access they do today until Phase 2 rewrites them. The app keeps working
-- exactly as it does now after this migration; it just also has the new
-- column, unused until Phase 4.
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- alliances
-- ---------------------------------------------------------------------------
alter table alliances add column if not exists campaign_id uuid references campaigns(id);

update alliances
   set campaign_id = (select id from campaigns where join_code = 'SKULL-0001')
 where campaign_id is null;

alter table alliances alter column campaign_id set not null;

create index if not exists alliances_campaign_id_idx on alliances (campaign_id);

comment on table alliances is 'The teams players fight for on the standings hub, scoped to one campaign. Organiser-writable per campaign as of Phase 2 -- was global admin-only reference data before.';

-- ---------------------------------------------------------------------------
-- rosters
-- ---------------------------------------------------------------------------
alter table rosters add column if not exists campaign_id uuid references campaigns(id);

update rosters
   set campaign_id = (select id from campaigns where join_code = 'SKULL-0001')
 where campaign_id is null;

alter table rosters alter column campaign_id set not null;

create index if not exists rosters_campaign_id_idx on rosters (campaign_id);
-- every query that loads "my roster" already filters by player_id; this
-- composite index keeps "my roster in this campaign" (the Phase 4 shape)
-- equally cheap
create index if not exists rosters_player_campaign_idx on rosters (player_id, campaign_id);

-- ---------------------------------------------------------------------------
-- games
-- ---------------------------------------------------------------------------
alter table games add column if not exists campaign_id uuid references campaigns(id);

update games
   set campaign_id = (select id from campaigns where join_code = 'SKULL-0001')
 where campaign_id is null;

alter table games alter column campaign_id set not null;

create index if not exists games_campaign_id_idx on games (campaign_id);
