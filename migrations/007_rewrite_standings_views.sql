-- ============================================================================
-- 007_rewrite_standings_views.sql
--
-- Phase 1, part 7 of 8.
--
-- Rewrites `alliance_standings` and `player_standings` (definitions pulled
-- via pg_get_viewdef() and confirmed against the live database, not
-- guessed) for two reasons:
--
-- 1. Both currently read players.faction_id/alliance_id/tier directly.
--    008_players_decommission_campaign_columns.sql drops those columns --
--    this file has to land first, or that drop fails (deliberately, since
--    it doesn't use CASCADE).
--
-- 2. Both have a real bug independent of the column rename: neither filters
--    `games` by campaign. `alliance_standings` joined games through
--    `players`, and `player_standings` didn't scope games at all. Once a
--    player can belong to more than one campaign, every game they've ever
--    played in *any* campaign would count toward *every* campaign's
--    standings they appear in -- Campaign B's battles silently inflating
--    Campaign A's totals. Confirmed as a real bug to fix, not a hypothetical.
--
-- IMPORTANT -- player_standings changes grain. It used to be one row per
-- player (players.id was the whole story). Now that faction/alliance/tier
-- live on campaign_members instead, a player in two campaigns needs two
-- rows -- one per campaign, each with that campaign's own faction/alliance/
-- tier/glory. The view's true key is now (id, campaign_id), not just id.
-- Nothing in index.html queries this view today (confirmed -- only
-- alliance_standings is used), so nothing breaks, but any future caller
-- MUST filter `where campaign_id = :current_campaign` to get one row per
-- player, the same way alliance_standings callers must filter by
-- campaign_id (or, for alliance_standings specifically, get it for free by
-- filtering to alliances already scoped to one campaign).
--
-- Uses CREATE OR REPLACE VIEW, not DROP + CREATE, specifically so the
-- existing `GRANT SELECT ... TO authenticated` (or whatever the original
-- setup script granted) carries over automatically -- a drop would lose
-- it, and I can't see the original grants to redo them correctly. This
-- means every pre-existing column must keep its exact name, type, and
-- position; campaign_id is appended at the end of each view rather than
-- placed where it'd read more naturally, since Postgres only allows
-- CREATE OR REPLACE VIEW to append columns, never reorder or insert them.
--
-- Idempotent: safe to re-run. Run after 006, before 008.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- alliance_standings
--
-- Original:
--   SELECT a.id, a.name, a.colour,
--          count(DISTINCT p.id) AS members,
--          COALESCE(sum(g.glory_points), 0::bigint) AS glory_points,
--          count(g.id) FILTER (WHERE g.result = 'win'::game_result) AS wins,
--          count(g.id) FILTER (WHERE g.result = 'loss'::game_result) AS losses,
--          count(g.id) FILTER (WHERE g.result = 'draw'::game_result) AS draws
--     FROM alliances a
--     LEFT JOIN players p ON p.alliance_id = a.id
--     LEFT JOIN games g ON g.player_id = p.id
--    GROUP BY a.id
--    ORDER BY (COALESCE(sum(g.glory_points), 0::bigint)) DESC;
--
-- players.alliance_id -> campaign_members.alliance_id, joined on the same
-- campaign as the alliance itself (defensive -- nothing enforces a
-- membership's alliance_id belongs to its own campaign at the DB level, so
-- this join condition guards against that rather than assuming it). games
-- is now also filtered to the alliance's own campaign, fixing the
-- cross-campaign leak described above.
-- ---------------------------------------------------------------------------
create or replace view alliance_standings as
select a.id,
       a.name,
       a.colour,
       count(distinct cm.user_id) as members,
       coalesce(sum(g.glory_points), 0::bigint) as glory_points,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       a.campaign_id
  from alliances a
  left join campaign_members cm on cm.alliance_id = a.id and cm.campaign_id = a.campaign_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = a.campaign_id
 group by a.id
 order by coalesce(sum(g.glory_points), 0::bigint) desc;

comment on view alliance_standings is 'One row per alliance, scoped by that alliance''s own campaign_id (appended as the last column -- filter on it once more than one campaign exists). Members/glory/wins/losses/draws are now correctly confined to games played within that same campaign.';

-- ---------------------------------------------------------------------------
-- player_standings
--
-- Original:
--   SELECT p.id, p.display_name, p.faction_id, p.alliance_id, p.tier,
--          COALESCE(sum(g.glory_points), 0::bigint) AS glory_points,
--          count(g.id) AS games_played,
--          count(g.id) FILTER (WHERE g.result = 'win'::game_result) AS wins,
--          count(g.id) FILTER (WHERE g.result = 'loss'::game_result) AS losses,
--          count(g.id) FILTER (WHERE g.result = 'draw'::game_result) AS draws
--     FROM players p
--     LEFT JOIN games g ON g.player_id = p.id
--    GROUP BY p.id;
--
-- Rebuilt from campaign_members instead of players directly -- see the
-- grain change explained in the file header. p.display_name is pulled in
-- via the join and included in GROUP BY explicitly rather than relying on
-- Postgres inferring it's functionally dependent on cm.user_id (that
-- inference only applies to columns from the table whose own primary key
-- is in the GROUP BY, which here is campaign_members' (user_id,
-- campaign_id), not players' id).
-- ---------------------------------------------------------------------------
create or replace view player_standings as
select cm.user_id as id,
       p.display_name,
       cm.faction_id,
       cm.alliance_id,
       cm.tier,
       coalesce(sum(g.glory_points), 0::bigint) as glory_points,
       count(g.id) as games_played,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       cm.campaign_id
  from campaign_members cm
  join players p on p.id = cm.user_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = cm.campaign_id
 group by cm.user_id, cm.campaign_id, p.display_name, cm.faction_id, cm.alliance_id, cm.tier;

comment on view player_standings is 'One row per (player, campaign) -- id alone is no longer unique, unlike before this migration. Callers must filter by campaign_id. faction_id/alliance_id/tier now come from campaign_members, matching the columns 008 removes from players.';
