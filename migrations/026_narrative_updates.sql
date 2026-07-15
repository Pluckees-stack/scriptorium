-- ============================================================================
-- 026_narrative_updates.sql
--
-- "Narrative updates" -- a click-through book of story pages (title, body
-- text, optional image) shown to players in their own tab. campaigns.
-- narrative_enabled is an organiser-only on/off switch for that tab, kept
-- separate from the pages existing so an organiser can draft pages ahead of
-- time before switching it on for players.
--
-- Follows the exact table/RLS shape of 020_campaign_phases_and_free_play.sql:
-- campaign-scoped table, is_campaign_member/is_campaign_organiser/
-- is_platform_admin from 009_rls_helper_functions.sql, and the shared
-- set_updated_at() trigger fn from 001_campaigns_and_membership.sql.
--
-- No RLS change needed on campaigns itself -- 010_rls_policies_all_tables.sql's
-- "organisers and admins update their campaign" policy is row-level, not
-- column-restricted, so organisers can already write narrative_enabled the
-- same way campaignNameSaveBtn already writes name.
--
-- Idempotent: safe to re-run. Run after 025.
-- ============================================================================

alter table campaigns add column if not exists narrative_enabled boolean not null default false;

comment on column campaigns.narrative_enabled is 'Organiser toggle -- shows/hides the player-facing Narrative updates tab. Pages can exist and be authored while this is off.';

-- ---------------------------------------------------------------------------
-- narrative_pages
-- ---------------------------------------------------------------------------
create table if not exists narrative_pages (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  sequence    integer not null,
  title       text not null,
  body        text not null default '',
  image_url   text,
  created_by  uuid references players(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table narrative_pages is 'One page of a campaign''s ongoing story, shown as a click-through book in the player-facing Narrative updates tab. Ordered by sequence.';

create index if not exists narrative_pages_campaign_id_idx on narrative_pages (campaign_id);

drop trigger if exists narrative_pages_set_updated_at on narrative_pages;
create trigger narrative_pages_set_updated_at
  before update on narrative_pages
  for each row execute function set_updated_at();

alter table narrative_pages enable row level security;

drop policy if exists "campaign members can read narrative pages" on narrative_pages;
drop policy if exists "organisers manage narrative pages" on narrative_pages;

create policy "campaign members can read narrative pages" on narrative_pages
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage narrative pages" on narrative_pages
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
