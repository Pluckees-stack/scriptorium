-- ============================================================================
-- 005_missions_table.sql
--
-- Phase 1, part 5 of 7.
--
-- New table. Missions are hybrid: campaign_id NULL = an official/global
-- scenario template (readable by every authenticated user, writable by a
-- superadmin or platform admin -- see 002_platform_admin_tier.sql);
-- campaign_id NOT NULL = a campaign's own custom mission (readable by that
-- campaign's members, writable by that campaign's organisers, and also by
-- any admin/superadmin). Read/write policies are Phase 2 -- this file only
-- creates the shape.
--
-- Deliberately self-contained: no foreign keys into campaign-specific
-- tables, so a mission row (official or custom) can be freely copied
-- between scopes later -- e.g. the Admin Console's planned "copy this
-- official template into my campaign as a custom mission" action -- without
-- ever having to rewrite foreign keys.
--
-- Structured columns cover the fields the mission builder form (Phase 5)
-- edits directly: deployment, victory conditions, special rules, turn
-- limit, and the two reward currencies this app already tracks (XP and
-- glory points). `rules` jsonb is for whatever doesn't deserve its own
-- column -- e.g. per-deployment-zone objectives, one-off scenario twists.
--
-- Idempotent: safe to re-run. RLS is enabled with ZERO policies at the end
-- -- fully locked to client access until Phase 2.
-- ============================================================================

create table if not exists missions (
  id                          uuid primary key default gen_random_uuid(),
  campaign_id                 uuid references campaigns(id) on delete cascade,

  name                        text not null,
  deployment_type             text,
  victory_conditions_summary  text,
  special_rules               text,
  turn_limit                  integer,
  xp_reward                   integer not null default 0,
  glory_reward                integer not null default 0,

  rules                       jsonb not null default '{}'::jsonb,

  created_by                  uuid references players(id) on delete set null,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

comment on table missions is 'Hybrid: campaign_id NULL = official template (readable by all, superadmin/admin-writable). campaign_id NOT NULL = campaign custom mission (readable by members, writable by that campaign''s organisers, plus any admin/superadmin). See Phase 2 for the actual policies.';
comment on column missions.rules is 'Free-form scenario content that doesn''t warrant a first-class column (e.g. per-deployment-zone objectives, one-off twists).';

drop trigger if exists missions_set_updated_at on missions;
create trigger missions_set_updated_at
  before update on missions
  for each row execute function set_updated_at(); -- defined in 001_campaigns_and_membership.sql

create index if not exists missions_campaign_id_idx on missions (campaign_id);

alter table missions enable row level security;
