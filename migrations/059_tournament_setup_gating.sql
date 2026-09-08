-- ============================================================================
-- 059_tournament_setup_gating.sql
--
-- Tightens tournament / campaign setup so a live season can't be run
-- half-configured:
--
-- 1. campaigns.player_cap -- an optional hard limit on how many players can
--    self-join a campaign (via the join code / link). null = unlimited.
--    Platform admins are exempt (an organiser must always be able to get in
--    to run things). Enforced in the same "users can join a campaign as a
--    player" policy that already gates on campaign status -- re-stated in
--    full here (its current form is in 045, on top of 036/025).
--
-- 2. tournaments.entrants_locked_at -- marks the point in setup where the
--    entrant list is frozen and the organiser is assigning a scenario to
--    each round. No new status value: the "assigning scenarios" phase is
--    `status = 'setup' AND entrants_locked_at IS NOT NULL`. All the round
--    rows exist from this point (index.html creates them on lock), so the
--    round count is fixed and every round can be given its scenario before
--    the tournament starts.
--
-- Idempotent: safe to re-run. Run after 058.
-- ============================================================================

alter table campaigns add column if not exists player_cap integer;
comment on column campaigns.player_cap is 'Optional hard limit on self-service joins (join code/link). null = unlimited. Platform admins bypass it; enforced in the "users can join a campaign as a player" policy.';

alter table tournaments add column if not exists entrants_locked_at timestamptz;
comment on column tournaments.entrants_locked_at is 'Set when the organiser locks the entrant list during setup; from then the round rows exist and the organiser assigns each round a scenario before Start. Cleared by "Unlock entrants".';

-- ---------------------------------------------------------------------------
-- player cap on self-service joins (extends 045's form of this policy)
-- ---------------------------------------------------------------------------
alter policy "users can join a campaign as a player" on campaign_members
  with check (
    (user_id = (select auth.uid()))
    and (role = 'player'::text)
    and (alliance_id is null)
    and (exists (
      select 1 from campaigns c
      where c.id = campaign_members.campaign_id and c.status = 'active'::text
    ))
    and (
      is_platform_admin()
      or (select c.player_cap from campaigns c where c.id = campaign_members.campaign_id) is null
      or (select count(*) from campaign_members m where m.campaign_id = campaign_members.campaign_id)
           < (select c.player_cap from campaigns c where c.id = campaign_members.campaign_id)
    )
  );
