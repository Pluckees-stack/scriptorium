-- ============================================================================
-- 045_rls_auth_uid_init_plan.sql
--
-- Fixes: Supabase's advisor flags 10 policies across 6 tables with "Auth RLS
-- Initialization Plan" warnings -- each embeds a raw auth.uid() call in its
-- USING/WITH CHECK expression, which Postgres re-evaluates once per row
-- instead of once per query. Wrapping it as (select auth.uid()) lets the
-- planner hoist it into an InitPlan, evaluated a single time.
--
-- Confirmed against a live dump of pg_policies (not reconstructed from
-- migration history -- several of these, e.g. players' "own player" policy,
-- predate this repo's migration tracking and aren't defined in any file
-- here). Every other public-schema policy only calls the is_campaign_member/
-- is_campaign_organiser/is_platform_admin helper functions, which the
-- advisor doesn't flag (no raw auth.*() text in the policy itself), so
-- they're left untouched.
--
-- ALTER POLICY only changes USING/WITH CHECK -- roles, command type and
-- everything else are unaffected. No behaviour change, purely the auth.uid()
-- wrapping.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter policy "members can leave a campaign" on campaign_members
  using (user_id = (select auth.uid()));

alter policy "members can update their own faction and onboarded flag" on campaign_members
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy "users can join a campaign as a player" on campaign_members
  with check (
    (user_id = (select auth.uid()))
    and (role = 'player'::text)
    and (alliance_id is null)
    and (exists (
      select 1 from campaigns c
      where c.id = campaign_members.campaign_id and c.status = 'active'::text
    ))
  );

alter policy "players add their own free play log" on free_play_log
  with check ((user_id = (select auth.uid())) and is_campaign_member(campaign_id));

alter policy "players delete their own free play log" on free_play_log
  using (user_id = (select auth.uid()));

alter policy "players manage their own games" on games
  using (((select auth.uid()) = player_id) and is_campaign_member(campaign_id))
  with check (((select auth.uid()) = player_id) and is_campaign_member(campaign_id));

alter policy "own player" on players
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

alter policy "players manage their own rosters" on rosters
  using (((select auth.uid()) = player_id) and is_campaign_member(campaign_id))
  with check (((select auth.uid()) = player_id) and is_campaign_member(campaign_id));

alter policy "players manage their own advances" on unit_advances
  using (
    is_campaign_member(campaign_id) and exists (
      select 1 from units u join rosters r on r.id = u.roster_id
      where u.id = unit_advances.unit_id and r.player_id = (select auth.uid())
    )
  )
  with check (
    is_campaign_member(campaign_id) and exists (
      select 1 from units u join rosters r on r.id = u.roster_id
      where u.id = unit_advances.unit_id
        and r.player_id = (select auth.uid())
        and u.campaign_id = unit_advances.campaign_id
    )
  );

alter policy "players manage their own units" on units
  using (
    is_campaign_member(campaign_id) and exists (
      select 1 from rosters r
      where r.id = units.roster_id and r.player_id = (select auth.uid())
    )
  )
  with check (
    is_campaign_member(campaign_id) and exists (
      select 1 from rosters r
      where r.id = units.roster_id
        and r.player_id = (select auth.uid())
        and r.campaign_id = units.campaign_id
    )
  );
