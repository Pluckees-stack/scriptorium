-- ============================================================================
-- 100_warcastle.sql
--
-- WarCastle (warcastle-brief.md): a tournament-format event played on the
-- Fortenhaf map. The map itself (areas, crossings, directions) lives in
-- index.html (WARCASTLE); a WarCastle event is a tournament campaign whose
-- campaigns.settings.template is 'warcastle'. This adds the storage the
-- event needs on top of the tournament tables (039):
--
-- 1. warcastle_moves: where each army goes, round by round, as the
--    organiser mirrors the physical map. round_number is the round the army
--    fights in after the move; from_area null = placed by the organiser
--    (round 1); from_area = to_area = stayed put. seq is the order the moves
--    were entered: the last army to move into an area is its attacker. One
--    move per army per round (a corrected move is deleted and entered
--    again, so it counts as the latest).
-- 2. tournament_pairings.warcastle: a table's deployment, set when the
--    round's pairings are made from the map:
--    { attacker: player id, came_from: 'n' | 'ne' | ... | null,
--      ambush: true | false }. Organisers write it through the existing
--    "organisers manage tournament pairings" policy (039).
-- 3. warcastle_allegiances, and tournament_entrants.warcastle_allegiance:
--    the alliances players form and break during Diplomacy. Organisers set
--    an entrant's allegiance through the existing "organisers manage
--    tournament entrants" policy (039). Null = no allegiance (neutral).
--
-- RLS follows 039: campaign members read, organisers manage.
--
-- To undo:
--   alter table tournament_entrants drop column if exists warcastle_allegiance;
--   drop table if exists warcastle_allegiances;
--   alter table tournament_pairings drop column if exists warcastle;
--   drop table if exists warcastle_moves;
--
-- Idempotent: safe to re-run. Run after 099.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- warcastle_moves
-- ---------------------------------------------------------------------------
create table if not exists warcastle_moves (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  round_number  integer not null check (round_number >= 1),
  player_id     uuid not null references players(id) on delete cascade,
  from_area     smallint check (from_area between 1 and 13),
  to_area       smallint not null check (to_area between 1 and 13),
  seq           bigint generated always as identity,
  created_by    uuid references players(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (tournament_id, round_number, player_id)
);

comment on table warcastle_moves is 'WarCastle: each army''s move into a round, as the organiser enters it (100). from_area null = placed; from_area = to_area = stayed. seq orders the moves: the last army into an area attacks.';

create index if not exists warcastle_moves_tournament_id_idx on warcastle_moves (tournament_id);
create index if not exists warcastle_moves_campaign_id_idx on warcastle_moves (campaign_id);

alter table warcastle_moves enable row level security;

drop policy if exists "campaign members can read warcastle moves" on warcastle_moves;
drop policy if exists "organisers manage warcastle moves" on warcastle_moves;

create policy "campaign members can read warcastle moves" on warcastle_moves
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage warcastle moves" on warcastle_moves
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- tournament_pairings.warcastle
-- ---------------------------------------------------------------------------
alter table tournament_pairings add column if not exists warcastle jsonb;
comment on column tournament_pairings.warcastle is 'WarCastle only: the table''s deployment, { attacker: player id, came_from: direction key or null, ambush: boolean } (100).';

-- ---------------------------------------------------------------------------
-- warcastle_allegiances
-- ---------------------------------------------------------------------------
create table if not exists warcastle_allegiances (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  name          text not null check (length(trim(name)) between 1 and 60),
  colour        text,
  created_at    timestamptz not null default now()
);

comment on table warcastle_allegiances is 'WarCastle: the alliances players form during Diplomacy (100). Members are tournament_entrants.warcastle_allegiance.';

create index if not exists warcastle_allegiances_tournament_id_idx on warcastle_allegiances (tournament_id);

alter table warcastle_allegiances enable row level security;

drop policy if exists "campaign members can read warcastle allegiances" on warcastle_allegiances;
drop policy if exists "organisers manage warcastle allegiances" on warcastle_allegiances;

create policy "campaign members can read warcastle allegiances" on warcastle_allegiances
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage warcastle allegiances" on warcastle_allegiances
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

alter table tournament_entrants add column if not exists warcastle_allegiance uuid references warcastle_allegiances(id) on delete set null;
comment on column tournament_entrants.warcastle_allegiance is 'WarCastle only: the allegiance this army is in; null = none (100).';
