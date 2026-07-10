-- ============================================================================
-- 023_rename_glory_to_campaign_points.sql
--
-- Renames the "Glory Points"/"Glory" scoring metric to "Campaign Points"
-- throughout the schema, at Grant's explicit request (not to be confused
-- with Old World's own "Path to Glory" veteran mechanic, which is unrelated
-- and untouched by this migration):
--
--   games.glory_points      -> games.campaign_points
--   missions.glory_reward   -> missions.campaign_points_reward
--
-- A plain rename (ALTER TABLE ... RENAME COLUMN) is enough for the base
-- tables, but alliance_standings/player_standings expose glory_points as an
-- *output* column name, and CREATE OR REPLACE VIEW cannot rename an output
-- column (only append new ones -- see 007's own header comment). Both views
-- are dropped and recreated here instead, which loses their existing
-- `security_invoker` setting (012) and GRANT SELECT (never itself captured
-- in a migration -- per 007, it predates this repo's tracked migration
-- history) unless both are explicitly redone below, which they are.
--
-- log_game_with_xp (most recently redefined in 020) is recreated to read
-- p_game->>'campaign_points' instead of 'glory_points'.
--
-- IMPORTANT: like 019 before it, a migration merged to main is not the same
-- as a migration run against the live database -- run this file in the
-- Supabase SQL editor and confirm it actually applied before relying on it.
--
-- Idempotent: safe to re-run. Run after 022.
-- ============================================================================

-- Guarded so a second run (the column already renamed) doesn't error --
-- plain RENAME COLUMN has no IF EXISTS form of its own.
do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'games' and column_name = 'glory_points') then
    alter table games rename column glory_points to campaign_points;
  end if;
end $$;

do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'missions' and column_name = 'glory_reward') then
    alter table missions rename column glory_reward to campaign_points_reward;
  end if;
end $$;

drop view if exists alliance_standings;
create view alliance_standings as
select a.id,
       a.name,
       a.colour,
       count(distinct cm.user_id) as members,
       coalesce(sum(g.campaign_points), 0::bigint) as campaign_points,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       a.campaign_id
  from alliances a
  left join campaign_members cm on cm.alliance_id = a.id and cm.campaign_id = a.campaign_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = a.campaign_id
 group by a.id
 order by coalesce(sum(g.campaign_points), 0::bigint) desc;

alter view alliance_standings set (security_invoker = true);
grant select on alliance_standings to authenticated;

comment on view alliance_standings is 'One row per alliance, scoped by that alliance''s own campaign_id (appended as the last column -- filter on it once more than one campaign exists). Members/campaign_points/wins/losses/draws are confined to games played within that same campaign.';

drop view if exists player_standings;
create view player_standings as
select cm.user_id as id,
       p.display_name,
       cm.faction_id,
       cm.alliance_id,
       cm.tier,
       coalesce(sum(g.campaign_points), 0::bigint) as campaign_points,
       count(g.id) as games_played,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       cm.campaign_id
  from campaign_members cm
  join players p on p.id = cm.user_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = cm.campaign_id
 group by cm.user_id, cm.campaign_id, p.display_name, cm.faction_id, cm.alliance_id, cm.tier;

alter view player_standings set (security_invoker = true);
grant select on player_standings to authenticated;

comment on view player_standings is 'One row per (player, campaign) -- callers must filter by campaign_id. faction_id/alliance_id/tier come from campaign_members.';

create or replace function log_game_with_xp(p_game jsonb)
returns bigint
language plpgsql
security invoker
as $function$
declare
  new_game_id bigint;
  credit jsonb;
  v_campaign_id uuid;
begin
  v_campaign_id := nullif(p_game->>'campaign_id', '')::uuid;

  if v_campaign_id is null then
    raise exception 'campaign_id is required to log a battle.';
  end if;

  if not is_campaign_member(v_campaign_id) then
    raise exception 'You are not a member of that campaign.';
  end if;

  insert into games (
    campaign_id, player_id, opponent_id, opponent_name, result, campaign_points,
    scenario, mission_id, phase_id, trait_objective_id, trait_objective_met, played_on, notes,
    opponent_unit_outcomes, kill_credits
  )
  values (
    v_campaign_id,
    auth.uid(),
    nullif(p_game->>'opponent_id', '')::uuid,
    nullif(p_game->>'opponent_name', ''),
    (p_game->>'result')::game_result,
    coalesce((p_game->>'campaign_points')::integer, 0),
    nullif(p_game->>'scenario', ''),
    nullif(p_game->>'mission_id', '')::uuid,
    nullif(p_game->>'phase_id', '')::uuid,
    nullif(p_game->>'trait_objective_id', '')::bigint,
    coalesce((p_game->>'trait_objective_met')::boolean, false),
    coalesce(nullif(p_game->>'played_on', '')::date, current_date),
    nullif(p_game->>'notes', ''),
    case when jsonb_typeof(p_game->'opponent_unit_outcomes') = 'array'
         then p_game->'opponent_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'kill_credits') = 'array'
         then p_game->'kill_credits' else null end
  )
  returning id into new_game_id;

  -- 1 XP per credited kill, applied to the logger's own units. Row level
  -- security means an update against anyone else's unit simply matches
  -- nothing -- it cannot award XP across players.
  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_game->'kill_credits') = 'array'
           then p_game->'kill_credits' else '[]'::jsonb end)
  loop
    update units
       set experience = experience + coalesce((credit->>'amount')::integer, 0),
           updated_at = now()
     where id = (credit->>'unitId')::bigint;
  end loop;

  return new_game_id;
end;
$function$;
