-- ============================================================================
-- 110_warcastle_quests.sql
--
-- WarCastle quests (Grant, 28 Oct 2026): each player's own briefing and
-- quest, written by an organiser in Set up › Entrants and read by the player
-- from Your quest on Play. Both are text with simple formatting (bold,
-- italic, headings, lists, quotes), kept as the campaign story keeps it.
--
-- Secret: a player reads only their own, and only once the organiser has
-- sent the quests (campaigns.settings.warcastle.quests_sent_at, set by Send
-- to players, or the Quests sent out switch in Set up › Start). Organisers
-- read and change everyone's, at any time.
--
-- index.html works without it (Set up › Entrants shows the error; Your
-- quest says it couldn't be read).
--
-- Idempotent: safe to re-run. Run after 100.
--
-- To undo:
--   drop table if exists warcastle_quests;
-- ============================================================================

create table if not exists warcastle_quests (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  player_id   uuid not null references players(id) on delete cascade,
  briefing    text not null default '' check (length(briefing) <= 20000),
  quest       text not null default '' check (length(quest) <= 20000),
  updated_by  uuid references players(id) on delete set null,
  updated_at  timestamptz not null default now(),
  unique (campaign_id, player_id)
);

comment on table warcastle_quests is 'WarCastle: each player''s secret briefing and quest (110), written by an organiser. A player reads their own once campaigns.settings.warcastle.quests_sent_at is set.';

alter table warcastle_quests enable row level security;

drop policy if exists "players read their own quest once sent" on warcastle_quests;
drop policy if exists "organisers manage quests" on warcastle_quests;

create policy "players read their own quest once sent" on warcastle_quests
  for select to authenticated
  using (
    player_id = auth.uid()
    and exists (
      select 1 from campaigns c
      where c.id = warcastle_quests.campaign_id
        and nullif(c.settings -> 'warcastle' ->> 'quests_sent_at', '') is not null
    )
  );

create policy "organisers manage quests" on warcastle_quests
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
