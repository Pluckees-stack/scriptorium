-- ============================================================================
-- 050_game_credits_and_standings.sql
--
-- Part 2 of the VP-vs-Campaign-Points split (see 048/049 for the schema and
-- confirmation RPCs). player_standings/alliance_standings (most recently
-- redefined in 025/030) have only ever credited the LOGGING player's side of
-- a game (joining games.player_id). Now that a single row represents both
-- sides of a real battle, standings need to credit whichever side each row
-- belongs to -- and only once a row has actually been agreed (confirmed) or
-- predates this system entirely (legacy); a pending or disputed game must
-- stay invisible to standings until it's resolved.
--
-- game_credits does that expansion once, in one place, rather than
-- duplicating the confirmation-status filter and the win/loss inversion
-- logic inside every downstream view. security_invoker = true matches the
-- hardening already applied to player_standings/alliance_standings
-- themselves (012/044/045) -- skipping it here would reopen exactly the
-- cross-campaign leak class those migrations closed.
--
-- player_standings/alliance_standings keep their exact external shape
-- (column names/order unchanged) so every existing consumer
-- (renderTopGenerals, renderStandings, CSV exports) keeps working
-- unchanged -- only the numbers become correct. CREATE OR REPLACE VIEW is
-- safe here (no column rename, only the underlying join changes) -- but
-- 044's own lesson applies: CREATE OR REPLACE VIEW resets security_invoker,
-- so it's re-applied immediately after both, in this same file, rather than
-- assumed to persist.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace view game_credits as
select player_id as user_id, campaign_id, campaign_points, result, id as game_id
  from games
 where confirmation_status in ('confirmed', 'legacy')
union all
select opponent_id as user_id, campaign_id, opponent_campaign_points as campaign_points,
       case result
         when 'win' then 'loss'::game_result
         when 'loss' then 'win'::game_result
         else result
       end as result,
       id as game_id
  from games
 where confirmation_status in ('confirmed', 'legacy') and opponent_id is not null;

alter view game_credits set (security_invoker = true);
grant select on game_credits to authenticated;

comment on view game_credits is 'Expands each games row into one row per side (player_id and, if present, opponent_id), crediting each their own campaign_points and result -- the single place standings views read from, so the confirmation-status gate and win/loss inversion for the opponent side aren''t duplicated in every downstream query. Only confirmed/legacy games are visible here; pending/disputed rows are excluded entirely until resolved.';

create or replace view player_standings as
select cm.user_id as id,
       p.display_name,
       cm.faction_id,
       cm.alliance_id,
       coalesce(sum(gc.campaign_points), 0::bigint) as campaign_points,
       count(gc.game_id) as games_played,
       count(gc.game_id) filter (where gc.result = 'win'::game_result) as wins,
       count(gc.game_id) filter (where gc.result = 'loss'::game_result) as losses,
       count(gc.game_id) filter (where gc.result = 'draw'::game_result) as draws,
       cm.campaign_id
  from campaign_members cm
  join players p on p.id = cm.user_id
  left join game_credits gc on gc.user_id = cm.user_id and gc.campaign_id = cm.campaign_id
 group by cm.user_id, cm.campaign_id, p.display_name, cm.faction_id, cm.alliance_id;

alter view player_standings set (security_invoker = true);
grant select on player_standings to authenticated;

create or replace view alliance_standings as
select a.id,
       a.name,
       a.colour,
       count(distinct cm.user_id) as members,
       coalesce(sum(gc.campaign_points), 0::bigint) as campaign_points,
       count(gc.game_id) filter (where gc.result = 'win'::game_result) as wins,
       count(gc.game_id) filter (where gc.result = 'loss'::game_result) as losses,
       count(gc.game_id) filter (where gc.result = 'draw'::game_result) as draws,
       a.campaign_id,
       a.emblem_url
  from alliances a
  left join campaign_members cm on cm.alliance_id = a.id and cm.campaign_id = a.campaign_id
  left join game_credits gc on gc.user_id = cm.user_id and gc.campaign_id = a.campaign_id
 group by a.id
 order by coalesce(sum(gc.campaign_points), 0::bigint) desc;

alter view alliance_standings set (security_invoker = true);
grant select on alliance_standings to authenticated;
