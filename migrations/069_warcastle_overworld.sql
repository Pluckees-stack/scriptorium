-- ============================================================================
-- 069_warcastle_overworld.sql
--
-- Warcastle: a tournament format built around the Fortenhaf overworld map.
-- The map, its 13 areas and their borders live in index.html (WARCASTLE);
-- this migration only adds the storage the format needs.
--
-- The core idea: each map area is a fixed table, so a round's pairings ARE
-- the army positions. tournament_pairings.table_number = the area's table
-- (1..13, see WARCASTLE.areas). Moving an army between rounds is just
-- swapping which pairing row a player sits in on the next round's draft --
-- no separate positions table.
--
--   tournaments.format             adds 'warcastle'.
--   tournaments.warcastle          jsonb config set from Tournament Setup:
--                                  { areaMissions: { "<table>": "<missions.id>" } }
--                                  -- each area's scenario, applied to that
--                                  table in every round.
--   tournament_entrants.warcastle_role
--                                  which tracker an army feeds: 'chaos'
--                                  (corruption), 'waaagh' (Waaagh! energy),
--                                  'order' (an Order win takes corruption
--                                  off), or 'other'. Null = inferred from
--                                  faction/alliance in index.html.
--   tournament_rounds.moves        the organiser's move log for a draft
--                                  round, in the order entered:
--                                  [{ mover, target, from, to, stay, at }]
--                                  (player ids / table numbers). Drives the
--                                  "who's moved" checklist and Undo.
--   warcastle_tracker_entries      every corruption / Waaagh! scoring event:
--                                  per-game battle points, feature bonuses
--                                  (Manor, World Roots, Shard), the Tzeentch
--                                  ritual, and manual adjustments. Totals,
--                                  the ritual doubling, the Order penalty and
--                                  the Waaagh! ladder are all computed live
--                                  in index.html from these rows plus
--                                  pairing results -- nothing is stored as a
--                                  running total, same principle as the
--                                  standings views.
--
-- RLS follows 039 exactly: campaign members read, organisers manage.
--
-- Idempotent: safe to re-run. Run after 068.
-- ============================================================================

alter table tournaments drop constraint if exists tournaments_format_check;
alter table tournaments add constraint tournaments_format_check
  check (format in ('swiss', 'single_elim', 'round_robin', 'warcastle'));

alter table tournaments add column if not exists warcastle jsonb not null default '{}'::jsonb;
comment on column tournaments.warcastle is 'Warcastle-format config (index.html): { areaMissions: { "<table_number>": "<missions.id>" } }. Ignored by every other format.';

alter table tournament_entrants add column if not exists warcastle_role text;
alter table tournament_entrants drop constraint if exists tournament_entrants_warcastle_role_check;
alter table tournament_entrants add constraint tournament_entrants_warcastle_role_check
  check (warcastle_role is null or warcastle_role in ('chaos', 'waaagh', 'order', 'other'));
comment on column tournament_entrants.warcastle_role is 'Warcastle only: which tracker this army feeds. Null = inferred from faction/alliance in index.html.';

alter table tournament_rounds add column if not exists moves jsonb not null default '[]'::jsonb;
comment on column tournament_rounds.moves is 'Warcastle only: the organiser''s move log for this round''s draft, in entry order -- [{ mover, target, from, to, stay, at }].';

-- ---------------------------------------------------------------------------
-- warcastle_tracker_entries
-- ---------------------------------------------------------------------------
create table if not exists warcastle_tracker_entries (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  round_id      uuid not null references tournament_rounds(id) on delete cascade,
  player_id     uuid references players(id) on delete set null,
  track         text not null check (track in ('corruption', 'waaagh')),
  kind          text not null check (kind in ('battle', 'manor', 'tree', 'shard', 'ritual', 'adjustment')),
  points        integer not null default 0,
  note          text,
  created_by    uuid references players(id) on delete set null,
  created_at    timestamptz not null default now()
);

comment on table warcastle_tracker_entries is 'Warcastle scoring events. battle = a player''s tracker points for one game (one row per player per round, kept unique by index.html). manor/tree/shard = feature bonuses (points stored at the value in force when logged). ritual = the Tzeentch ritual (points 0; doubles corruption for the next two rounds, applied in index.html). adjustment = manual correction.';

create index if not exists warcastle_tracker_entries_tournament_id_idx on warcastle_tracker_entries (tournament_id);
create index if not exists warcastle_tracker_entries_round_id_idx on warcastle_tracker_entries (round_id);
create index if not exists warcastle_tracker_entries_campaign_id_idx on warcastle_tracker_entries (campaign_id);

alter table warcastle_tracker_entries enable row level security;

drop policy if exists "campaign members can read warcastle tracker" on warcastle_tracker_entries;
drop policy if exists "organisers manage warcastle tracker" on warcastle_tracker_entries;

create policy "campaign members can read warcastle tracker" on warcastle_tracker_entries
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage warcastle tracker" on warcastle_tracker_entries
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
