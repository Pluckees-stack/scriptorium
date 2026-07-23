-- ============================================================================
-- 039_tournaments.sql
--
-- Tournaments: a self-contained bracket/Swiss/round-robin event scoped to a
-- campaign. Two use cases share the same schema:
--   1. A "mini tournament" running alongside an active narrative campaign
--      (a subset of members opt in, plays a few rounds, campaign carries on
--      regardless) -- this is why tournament_rounds is its own table rather
--      than reusing campaign_phases: a phase going 'active' would otherwise
--      block the narrative phase from being active at the same time
--      (one_active_phase_per_campaign in 020), which breaks the "alongside"
--      case entirely.
--   2. A whole campaign run as a tournament instead of a narrative campaign
--      (campaigns.format = 'tournament') -- just a campaign whose organiser
--      creates one tournament that spans it; no separate code path.
--
-- Pairings are the new primitive here: games is single-sided (each player
-- logs their own perspective, no linked "other side" row), so it can't
-- represent "who plays whom this round". tournament_pairings does that, and
-- results are recorded directly by the organiser (tournament_pairings.result)
-- rather than derived from games -- keeps round advancement deterministic
-- instead of depending on both sides separately logging and agreeing.
--
-- Follows the exact RLS helper convention from 009_rls_helper_functions.sql
-- (is_campaign_member / is_campaign_organiser / is_platform_admin), same as
-- campaign_phases in 020 -- a tournament is always campaign-scoped, never
-- global/official like missions or maps.
--
-- Idempotent: safe to re-run. Run after 038.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- campaigns.format -- narrative (default, today's behaviour) or tournament.
-- Set once at creation; not exposed as an editable toggle afterwards.
-- ---------------------------------------------------------------------------
alter table campaigns add column if not exists format text not null default 'narrative';
alter table campaigns drop constraint if exists campaigns_format_check;
alter table campaigns add constraint campaigns_format_check check (format in ('narrative', 'tournament'));

-- ---------------------------------------------------------------------------
-- tournaments
-- ---------------------------------------------------------------------------
create table if not exists tournaments (
  id             uuid primary key default gen_random_uuid(),
  campaign_id    uuid not null references campaigns(id) on delete cascade,
  name           text not null,
  format         text not null check (format in ('swiss', 'single_elim', 'round_robin')),
  status         text not null default 'setup' check (status in ('setup', 'active', 'completed')),
  rounds_planned integer,
  current_round  integer not null default 0,
  created_by     uuid references players(id) on delete set null,
  created_at     timestamptz not null default now()
);

comment on table tournaments is 'A self-contained bracket/Swiss/round-robin event within a campaign. rounds_planned is organiser-set for swiss (suggested default, editable) and null (computed from entrant count) for single_elim/round_robin.';

create index if not exists tournaments_campaign_id_idx on tournaments (campaign_id);

alter table tournaments enable row level security;

drop policy if exists "campaign members can read tournaments" on tournaments;
drop policy if exists "organisers manage tournaments" on tournaments;

create policy "campaign members can read tournaments" on tournaments
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage tournaments" on tournaments
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- tournament_entrants
-- ---------------------------------------------------------------------------
create table if not exists tournament_entrants (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  player_id     uuid not null references players(id) on delete cascade,
  seed          integer,
  status        text not null default 'active' check (status in ('active', 'eliminated', 'withdrawn')),
  joined_at     timestamptz not null default now(),
  unique (tournament_id, player_id)
);

comment on table tournament_entrants is 'campaign_id is denormalized from tournaments.campaign_id for direct RLS predicates without a join, same pattern as games.campaign_id/phase_id. seed is used for single_elim bracket seeding and optionally round_robin ordering.';

create index if not exists tournament_entrants_tournament_id_idx on tournament_entrants (tournament_id);
create index if not exists tournament_entrants_campaign_id_idx on tournament_entrants (campaign_id);

alter table tournament_entrants enable row level security;

drop policy if exists "campaign members can read tournament entrants" on tournament_entrants;
drop policy if exists "organisers manage tournament entrants" on tournament_entrants;

create policy "campaign members can read tournament entrants" on tournament_entrants
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage tournament entrants" on tournament_entrants
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- tournament_rounds
-- ---------------------------------------------------------------------------
create table if not exists tournament_rounds (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  round_number  integer not null,
  status        text not null default 'draft' check (status in ('draft', 'active', 'completed')),
  mission_id    uuid references missions(id) on delete set null,
  created_at    timestamptz not null default now(),
  activated_at  timestamptz,
  completed_at  timestamptz,
  unique (tournament_id, round_number)
);

comment on table tournament_rounds is 'Deliberately separate from campaign_phases -- a tournament round going ''active'' must not block the campaign''s own narrative phase from being active at the same time. See one_active_round_per_tournament for the per-tournament equivalent of campaign_phases'' one_active_phase_per_campaign.';

create index if not exists tournament_rounds_tournament_id_idx on tournament_rounds (tournament_id);
create index if not exists tournament_rounds_campaign_id_idx on tournament_rounds (campaign_id);

drop index if exists one_active_round_per_tournament;
create unique index one_active_round_per_tournament on tournament_rounds (tournament_id) where status = 'active';

alter table tournament_rounds enable row level security;

drop policy if exists "campaign members can read tournament rounds" on tournament_rounds;
drop policy if exists "organisers manage tournament rounds" on tournament_rounds;

create policy "campaign members can read tournament rounds" on tournament_rounds
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage tournament rounds" on tournament_rounds
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- tournament_pairings -- who plays whom each round, and the organiser-
-- recorded result. player_b_id null = player_a has a bye.
-- ---------------------------------------------------------------------------
create table if not exists tournament_pairings (
  id            uuid primary key default gen_random_uuid(),
  round_id      uuid not null references tournament_rounds(id) on delete cascade,
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  player_a_id   uuid references players(id) on delete set null,
  player_b_id   uuid references players(id) on delete set null,
  table_number  integer,
  result        text check (result in ('a_win', 'b_win', 'draw')),
  created_at    timestamptz not null default now()
);

comment on table tournament_pairings is 'result is organiser-recorded directly (Tournament Admin), not derived from games -- games stays single-sided and optional per-player logging, unrelated to tournament round advancement.';

create index if not exists tournament_pairings_round_id_idx on tournament_pairings (round_id);
create index if not exists tournament_pairings_tournament_id_idx on tournament_pairings (tournament_id);
create index if not exists tournament_pairings_campaign_id_idx on tournament_pairings (campaign_id);

alter table tournament_pairings enable row level security;

drop policy if exists "campaign members can read tournament pairings" on tournament_pairings;
drop policy if exists "organisers manage tournament pairings" on tournament_pairings;

create policy "campaign members can read tournament pairings" on tournament_pairings
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage tournament pairings" on tournament_pairings
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
