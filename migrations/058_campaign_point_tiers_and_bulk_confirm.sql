-- ============================================================================
-- 058_campaign_point_tiers_and_bulk_confirm.sql
--
-- Two campaign-management fixes prompted by the live Path to Glory season:
--
-- 1. campaigns.campaign_point_tiers -- the VP-margin -> Campaign Points table
--    (deriveCampaignResult in index.html) was hardcoded 5/4/3/2/1 at margins
--    1000/500/200. Organisers need to tune it per campaign, so it moves into
--    a jsonb column with those exact numbers as the default (nothing changes
--    for an existing campaign until its organiser edits it).
--
--      { "crushing": {"margin": 1000, "cp": 5},   -- margin >= 1000
--        "major":    {"margin": 500,  "cp": 4},   -- 500..999
--        "minor":    {"margin": 200,  "cp": 3},   -- 200..499
--        "draw":     {"cp": 2},                    -- margin < 200, both sides
--        "defeat":   {"cp": 1} }                   -- the losing side, any margin
--
--    Editable only through the existing "organisers and admins update their
--    campaign" row policy (010) -- no column-level lock needed, it isn't
--    sensitive and a non-organiser can't update a campaigns row at all.
--
-- 2. admin_confirm_pending_games -- on the live season 25 of 47 games were
--    logged but never confirmed by the opponent, so their CP counted for
--    nobody (game_credits only sees confirmed/legacy, migration 050). This
--    lets an organiser clear the backlog: confirm every pending game in
--    their campaign (or a chosen subset), granting XP and syncing any
--    linked tournament pairing for each, exactly as a player confirming
--    would (apply_game_kill_credits + sync_tournament_pairing_for_game,
--    049/057). Disputed games are left alone -- those need real resolution.
--
-- Idempotent: safe to re-run. Run after 057.
-- ============================================================================

alter table campaigns add column if not exists campaign_point_tiers jsonb not null default
  '{"crushing":{"margin":1000,"cp":5},"major":{"margin":500,"cp":4},"minor":{"margin":200,"cp":3},"draw":{"cp":2},"defeat":{"cp":1}}'::jsonb;

comment on column campaigns.campaign_point_tiers is 'VP-margin -> Campaign Points tiers for this campaign, read by deriveCampaignResult. Keys crushing/major/minor carry {margin, cp}; draw/defeat carry {cp}. Defaults to the standard 5/4/3/2/1 at 1000/500/200.';

-- ---------------------------------------------------------------------------
-- admin_confirm_pending_games -- organiser/admin bulk confirm; see header
-- ---------------------------------------------------------------------------
create or replace function admin_confirm_pending_games(p_campaign_id uuid, p_game_ids bigint[] default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id    bigint;
  v_count integer := 0;
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can bulk-confirm battles.';
  end if;

  for v_id in
    select id from games
     where campaign_id = p_campaign_id
       and confirmation_status = 'pending'
       and (p_game_ids is null or id = any(p_game_ids))
  loop
    update games set confirmation_status = 'confirmed', confirmed_at = now() where id = v_id;
    perform apply_game_kill_credits(v_id);
    perform sync_tournament_pairing_for_game(v_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function admin_confirm_pending_games(uuid, bigint[]) from public;
grant execute on function admin_confirm_pending_games(uuid, bigint[]) to authenticated;
