-- ============================================================================
-- 001_campaigns_and_membership.sql
--
-- Phase 1 (multi-tenant schema), part 1 of 6.
--
-- Creates the two tables that make campaigns a first-class concept:
--   - campaigns          one row per campaign (a TO's season)
--   - campaign_members   who belongs to which campaign, in what role, and
--                        (moved off `players` here) their per-campaign
--                        competitive state: faction, alliance, tier, and
--                        whether they've completed onboarding for THIS
--                        campaign.
--
-- Why faction/alliance/tier/onboarded move off `players`: those are facts
-- about a player's participation in one specific campaign, not about their
-- account. A player in two campaigns needs a different faction in each, and
-- needs to onboard separately into each -- but their display name, theme
-- and accessibility preferences should stay one set of values across all of
-- them. Splitting this now avoids duplicating (and desyncing) account-level
-- prefs across N rows later, at the cost of the index.html player-record
-- query, onboarding wizard, and theme logic needing to read these four
-- fields from campaign_members instead (Phase 4).
--
-- The actual columns are DROPPED from `players` in
-- 008_players_decommission_campaign_columns.sql, once this file has copied
-- their values across. Do not run 006 before this file, and read its header
-- comment before running it -- it can fail loudly (safely) if the standings
-- views still depend on the columns being dropped.
--
-- Also adds `players.is_superadmin` -- the platform-owner flag. Campaign
-- organiser powers never come from this flag; they come from
-- campaign_members.role = 'organiser'. This flag is only for platform-wide
-- actions (creating new campaigns, managing official mission templates).
--
-- campaigns and campaign_members are brand new tables with no prior
-- exposure to preserve, so RLS is enabled on both with ZERO policies at the
-- end of this file -- fully locked to client access until Phase 2 defines
-- real policies. This does not block the seed data below: SQL-editor
-- statements run as the table owner, which bypasses RLS.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create extension if not exists pgcrypto; -- gen_random_uuid(), harmless no-op on PG13+ where it's built in

-- ---------------------------------------------------------------------------
-- campaigns
-- ---------------------------------------------------------------------------
create table if not exists campaigns (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  status      text not null default 'active'
                check (status in ('setup', 'active', 'archived', 'completed')),
  join_code   text not null unique,
  settings    jsonb not null default '{}'::jsonb,
  created_by  uuid references players(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table campaigns is 'One row per campaign (a TO''s season). settings is reserved for future ruleset/event-mode config -- empty object for now.';
comment on column campaigns.join_code is 'Short human-typeable code players enter to join, e.g. SKULL-7XK2. Keep it easy to read aloud and type on a phone at the table.';

-- keep updated_at honest without relying on every caller to set it --
-- shared by every table in this migration set that has one
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists campaigns_set_updated_at on campaigns;
create trigger campaigns_set_updated_at
  before update on campaigns
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------------
-- campaign_members
-- ---------------------------------------------------------------------------
create table if not exists campaign_members (
  user_id      uuid not null references players(id) on delete cascade,
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  role         text not null default 'player' check (role in ('organiser', 'player')),

  -- per-campaign competitive state, moved off `players` -- see file header.
  -- factions.id and alliances.id are both `text` (OWB army slugs and
  -- free-form team names, not generated uuids), and tier is the same
  -- Postgres enum (`player_tier`) players.tier already used -- confirmed
  -- against the live schema, not assumed.
  faction_id   text references factions(id),
  alliance_id  text references alliances(id),
  tier         player_tier,
  onboarded    boolean not null default false,

  joined_at    timestamptz not null default now(),

  primary key (user_id, campaign_id)
);

comment on table campaign_members is 'Who belongs to which campaign, their role, and their per-campaign faction/alliance/tier/onboarding state. One row per (player, campaign) they''ve joined.';

create index if not exists campaign_members_campaign_id_idx on campaign_members (campaign_id);
create index if not exists campaign_members_alliance_id_idx on campaign_members (alliance_id) where alliance_id is not null;

-- ---------------------------------------------------------------------------
-- players: platform-superadmin flag only (see header -- NOT campaign powers)
-- ---------------------------------------------------------------------------
alter table players add column if not exists is_superadmin boolean not null default false;

comment on column players.is_superadmin is 'Platform owner only. Grants cross-campaign admin actions (creating campaigns, managing official mission templates). Campaign-level TO powers come from campaign_members.role, never from this.';

-- `players` already has an owner-write RLS policy letting a signed-in user
-- update their OWN row (that's how the theme/display-name/dark-mode
-- settings screens work) -- and RLS is row-scoped, not column-scoped, so
-- without this, that same policy would let any player set their own
-- is_superadmin to true via a raw API call. Column-level privilege sits
-- underneath RLS and closes that off regardless of what Phase 2's row
-- policies end up looking like.
revoke update (is_superadmin) on players from authenticated;

-- ---------------------------------------------------------------------------
-- Seed: one test campaign, with every existing player copied in as a member
-- (their current players.faction_id/alliance_id/tier/onboarded values carry
-- across so nothing is lost). One arbitrary existing player is made
-- organiser purely so there's someone who can log into the Admin Console
-- once it exists -- there's no reliable "first" player to pick since this
-- is test data, so don't read anything into which one it picked. Check who
-- it was afterwards and adjust with the commented statements below.
-- ---------------------------------------------------------------------------
insert into campaigns (name, status, join_code, created_by)
select 'Season of Skulls (Test)',
       'active',
       'SKULL-0001',
       (select id from players limit 1)
where not exists (select 1 from campaigns where join_code = 'SKULL-0001');

with seed_campaign as (
  select id from campaigns where join_code = 'SKULL-0001'
),
organiser_pick as (
  select id from players limit 1
)
insert into campaign_members (user_id, campaign_id, role, faction_id, alliance_id, tier, onboarded)
select p.id,
       sc.id,
       case when p.id = (select id from organiser_pick) then 'organiser' else 'player' end,
       p.faction_id,
       p.alliance_id,
       p.tier,
       coalesce(p.onboarded, false)
  from players p, seed_campaign sc
on conflict (user_id, campaign_id) do nothing;

-- Find out who got picked as organiser:
--   select p.display_name from players p
--     join campaign_members cm on cm.user_id = p.id
--    where cm.role = 'organiser';
--
-- To hand organiser/superadmin to a specific account instead:
--   update campaign_members set role = 'player'
--    where campaign_id = (select id from campaigns where join_code = 'SKULL-0001');
--   update campaign_members set role = 'organiser'
--    where user_id = (select id from players where display_name = 'YOUR_USERNAME')
--      and campaign_id = (select id from campaigns where join_code = 'SKULL-0001');
--   update players set is_superadmin = true where display_name = 'YOUR_USERNAME';

-- ---------------------------------------------------------------------------
-- Lock both new tables down until Phase 2 writes real policies
-- ---------------------------------------------------------------------------
alter table campaigns enable row level security;
alter table campaign_members enable row level security;
