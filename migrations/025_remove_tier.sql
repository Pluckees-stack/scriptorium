-- ============================================================================
-- 025_remove_tier.sql
--
-- Removes the player "tier" mechanism entirely: campaign_members.tier, the
-- player_tier enum, the set_campaign_member_tier() RPC that wrote it, and
-- every reference to it in player_standings / RLS.
--
-- This was never a finished feature -- 011_campaign_membership_admin_
-- functions.sql added a SECURITY DEFINER RPC to set it, but no admin UI was
-- ever built to call it (the admin console's own header comment lists
-- "tier assignment" as deliberately out of scope, since player_tier's real
-- enum values were never confirmed). A stray 'challenger' value turned up
-- on a live campaign_members row with no code path that could have written
-- it, and rather than chase where that came from, Grant asked to remove the
-- mechanism outright as redundant.
--
-- Not to be confused with 002_platform_admin_tier.sql, which is an
-- unrelated concept (platform-wide admin/superadmin role tiers) and is
-- untouched by this migration.
--
-- Idempotent: safe to re-run. Run after 024.
-- ============================================================================

drop function if exists set_campaign_member_tier(uuid, uuid, player_tier);

-- player_standings (most recently redefined in 023) loses its tier column.
-- CREATE OR REPLACE VIEW can't drop an output column, so drop + recreate,
-- same as 023 had to do for its own rename -- security_invoker and the
-- authenticated grant are redone below since dropping the view loses both.
drop view if exists player_standings;
create view player_standings as
select cm.user_id as id,
       p.display_name,
       cm.faction_id,
       cm.alliance_id,
       coalesce(sum(g.campaign_points), 0::bigint) as campaign_points,
       count(g.id) as games_played,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       cm.campaign_id
  from campaign_members cm
  join players p on p.id = cm.user_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = cm.campaign_id
 group by cm.user_id, cm.campaign_id, p.display_name, cm.faction_id, cm.alliance_id;

alter view player_standings set (security_invoker = true);
grant select on player_standings to authenticated;

comment on view player_standings is 'One row per (player, campaign) -- callers must filter by campaign_id. faction_id/alliance_id come from campaign_members.';

-- The join-a-campaign insert policy (010) checked "tier is null" on the new
-- row; that clause would dangle once the column below is gone, so the
-- policy is recreated without it.
drop policy if exists "users can join a campaign as a player" on campaign_members;
create policy "users can join a campaign as a player" on campaign_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'player'
    and alliance_id is null
  );

alter table campaign_members drop column if exists tier;

drop type if exists player_tier;
