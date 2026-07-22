-- ============================================================================
-- 032_announcements.sql
--
-- announcements -- short, dated, logistics posts from an organiser ("round 3
-- starts Friday"), distinct from narrative_pages (026): that's ongoing story
-- content read as a click-through book, opt-in per campaign via a toggle.
-- Announcements are the opposite shape -- always on, reverse-chronological,
-- meant to be seen without hunting for them -- so there's no enabled toggle
-- here; an empty list already renders as nothing.
--
-- RLS mirrors narrative_pages: any campaign member can read, only that
-- campaign's organiser or a platform admin can write.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists announcements (
  id          bigint generated always as identity primary key,
  campaign_id uuid not null references campaigns(id) on delete cascade,
  title       text not null,
  body        text not null,
  created_by  uuid references players(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index if not exists announcements_campaign_id_idx on announcements (campaign_id, created_at desc);

alter table announcements enable row level security;

drop policy if exists "campaign members can read announcements" on announcements;
create policy "campaign members can read announcements" on announcements
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "organisers manage their campaign's announcements" on announcements;
create policy "organisers manage their campaign's announcements" on announcements
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
