-- ============================================================================
-- 004_scope_units_and_unit_advances.sql
--
-- Phase 1, part 4 of 7.
--
-- Denormalizes campaign_id onto `units` and `unit_advances` too, rather than
-- relying on RLS joining up through roster_id/unit_id on every read. These
-- two tables are read on every roster render and every wound/XP change, so
-- the simpler, faster policy is worth the (small) write-side risk of the
-- copy drifting from its parent roster's campaign_id -- nothing in the app
-- ever moves a unit between rosters, so that risk is theoretical, not a
-- realistic write path. (If it ever becomes one, a trigger enforcing
-- unit.campaign_id = roster.campaign_id on insert/update is the natural
-- next step -- not added now, to keep this phase reviewable.)
--
-- Backfilled from each row's own parent (units <- rosters, unit_advances <-
-- units), not from the seed campaign directly, so this stays correct even
-- if 003 had backfilled different rosters into different campaigns by the
-- time this runs.
--
-- Run after 003_scope_alliances_rosters_games.sql. Idempotent: safe to
-- re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- units
-- ---------------------------------------------------------------------------
alter table units add column if not exists campaign_id uuid references campaigns(id);

update units u
   set campaign_id = r.campaign_id
  from rosters r
 where u.roster_id = r.id
   and (u.campaign_id is null or u.campaign_id <> r.campaign_id);

alter table units alter column campaign_id set not null;

create index if not exists units_campaign_id_idx on units (campaign_id);

-- ---------------------------------------------------------------------------
-- unit_advances
-- ---------------------------------------------------------------------------
alter table unit_advances add column if not exists campaign_id uuid references campaigns(id);

update unit_advances ua
   set campaign_id = u.campaign_id
  from units u
 where ua.unit_id = u.id
   and (ua.campaign_id is null or ua.campaign_id <> u.campaign_id);

alter table unit_advances alter column campaign_id set not null;

create index if not exists unit_advances_campaign_id_idx on unit_advances (campaign_id);
