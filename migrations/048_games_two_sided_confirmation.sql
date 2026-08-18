-- ============================================================================
-- 048_games_two_sided_confirmation.sql
--
-- Part 1 of the VP-vs-Campaign-Points split (see 050 for the standings side).
--
-- games.campaign_points has always actually held the raw Victory Points (VP)
-- tally from computeVpTally() -- points-value of enemy units destroyed/
-- routed, plus mission objective bonuses. 023_rename_glory_to_campaign_
-- points.sql renamed the column from glory_points purely cosmetically, at
-- Grant's own request, to avoid confusion with the tabletop's "Path to
-- Glory" mechanic -- nothing about what the number represented ever changed.
-- So the campaign leaderboard has always ranked players by "how much of the
-- enemy army did you wreck" rather than a real campaign score.
--
-- From this migration forward, campaign_points genuinely means a small
-- (1-5) meta-currency derived from the VP MARGIN between both players, per
-- Grant's own campaign rules pack:
--   Crushing Victory (margin 1000+):  5 to the winner
--   Major Victory    (margin 500-1000): 4 to the winner
--   Minor Victory    (margin 200-500):  3 to the winner
--   Draw              (margin <200):    2 to each
--   Defeat (any losing margin):         1 to the loser
--
-- This requires knowing BOTH sides' VP, which requires knowing what happened
-- to the LOGGING player's own units too -- something the app never tracked
-- before (only the opponent's units, via opponent_unit_outcomes). And since
-- two players separately logging "the same" battle today produces two
-- completely unrelated, unlinked rows (see 039_tournaments.sql's own header
-- for this exact limitation), the only sound design is ONE row per real
-- battle, captured by whichever player logs it (now including both sides),
-- confirmed or disputed by the other side (opponent_id, which -- confirmed
-- live -- always points to a real registered campaign member; there is no
-- free-text-opponent path in the current UI at all) before it counts.
--
-- campaign_points itself is repurposed IN PLACE, not renamed -- every
-- existing consumer (player_standings, alliance_standings, CSV exports, the
-- admin override form) already treats it as an opaque summed number, so this
-- is compatible; only the scale of the number changes going forward.
--
-- Historical games are LEFT UNTOUCHED (Grant's explicit choice): their old,
-- large VP-based campaign_points values keep exactly the numbers they
-- already have -- just tagged 'legacy' below so they're distinguishable from
-- genuinely-scored new games. This does mean the leaderboard sums old large
-- numbers and new small numbers together going forward; an accepted
-- tradeoff, not a bug to fix here.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table games add column if not exists confirmation_status text not null default 'pending';
alter table games add constraint games_confirmation_status_check
  check (confirmation_status in ('pending', 'confirmed', 'disputed', 'legacy'))
  not valid;
alter table games validate constraint games_confirmation_status_check;

alter table games add column if not exists confirmed_at timestamptz;
alter table games add column if not exists disputed_at timestamptz;
alter table games add column if not exists dispute_reason text;

alter table games add column if not exists player_vp integer not null default 0;
alter table games add column if not exists opponent_vp integer not null default 0;
alter table games add column if not exists opponent_campaign_points integer not null default 0;

alter table games add column if not exists own_unit_outcomes jsonb;
alter table games add column if not exists opponent_kill_credits jsonb;

alter table games add column if not exists opponent_standards_captured integer not null default 0;
alter table games add column if not exists opponent_special_feature boolean not null default false;
alter table games add column if not exists opponent_domination_quarters integer not null default 0;
alter table games add column if not exists opponent_domination_double_strength integer not null default 0;
alter table games add column if not exists opponent_domination_uncontested integer not null default 0;

comment on column games.confirmation_status is 'pending: logged, awaiting the opponent''s review. confirmed: opponent agreed, counts toward standings/XP. disputed: opponent flagged a problem, needs organiser resolution (admin_resolve_game). legacy: existed before this column, campaign_points kept as its old VP-based value on purpose, counts toward standings same as confirmed.';
comment on column games.player_vp is 'The LOGGING player''s own raw VP for this battle (computeVpTally() output) -- 0 for legacy rows, nothing honest to backfill there.';
comment on column games.opponent_vp is 'The OPPONENT''s raw VP for this battle, computed from the mirrored "your own units" tracker -- 0 for legacy rows (never captured before this migration).';
comment on column games.opponent_campaign_points is 'The derived 1-5 campaign points credited to opponent_id from this one row.';
comment on column games.opponent_kill_credits is 'Mirrors kill_credits, but crediting the OPPONENT''s own units for kills made against the logging player''s roster.';

-- Every row that existed before this migration ran predates two-sided
-- tracking entirely -- tag as legacy, leave campaign_points exactly as-is.
update games set confirmation_status = 'legacy' where confirmation_status = 'pending';

-- Both already implicitly needed today (loadPendingLossPrompts already
-- filters games by opponent_id with no index) and load-bearing now that
-- "do I have anything pending to confirm" runs on every login.
create index if not exists games_opponent_id_idx on games (opponent_id);
create index if not exists games_pending_confirmation_idx on games (opponent_id, confirmation_status)
  where confirmation_status = 'pending';
