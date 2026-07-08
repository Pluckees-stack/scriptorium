-- ============================================================================
-- 006_trait_objectives_hybrid.sql
--
-- Phase 1, part 6 of 7.
--
-- trait_objectives gets the same hybrid treatment as missions
-- (005_missions_table.sql): campaign_id NULL = official sourcebook
-- objective (readable by all, writable by a superadmin or platform admin --
-- see 002_platform_admin_tier.sql); campaign_id NOT NULL =
-- a campaign's own custom narrative objective for the same faction
-- (readable by that campaign's members, writable by that campaign's
-- organisers).
--
-- All existing rows are official sourcebook content, so they're left with
-- campaign_id NULL -- no backfill needed, unlike 003/004. This is the one
-- table in Phase 1 where "existing rows become the official half of a
-- hybrid table" rather than "existing rows get assigned to the seed
-- campaign".
--
-- This table already has RLS enabled with a read-only policy (anyone
-- signed in can read, nobody but the dashboard can write) -- that policy is
-- untouched here and is actually still *correct* for the existing NULL
-- rows under the hybrid model. It becomes too permissive only once a
-- campaign-custom (non-NULL) row exists, which can't happen until Phase 2
-- adds an organiser-write policy for that case. So there's no exposure gap
-- to worry about between this file and Phase 2, unlike the brand-new
-- tables in 001/005.
--
-- Phase 4 will need the trait-objective dropdown query in index.html
-- (currently `.eq('faction_id', currentFactionId)`) to become
-- `.eq('faction_id', currentFactionId).or('campaign_id.is.null,campaign_id.eq.' + currentCampaignId)`
-- once a campaign context exists -- flagging here since this file is what
-- makes that change necessary.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table trait_objectives add column if not exists campaign_id uuid references campaigns(id);
alter table trait_objectives add column if not exists created_by uuid references players(id) on delete set null;

comment on table trait_objectives is 'Per-faction campaign objectives. Hybrid: campaign_id NULL = official sourcebook objective (superadmin/admin-writable). campaign_id NOT NULL = a campaign''s own custom objective for that faction (organiser-writable). See Phase 2 for policies.';

create index if not exists trait_objectives_campaign_id_idx on trait_objectives (campaign_id);
