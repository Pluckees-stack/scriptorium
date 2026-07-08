-- ============================================================================
-- 016_fix_own_row_policies_membership_gap.sql
--
-- Phase 2 bug fix, found during PHASE2_TEST_PLAN.md test C3.
--
-- 010_rls_policies_all_tables.sql gave rosters/units/unit_advances/games two
-- permissive policies each: a "campaign members can read X" SELECT policy
-- gated on is_campaign_member(), and a "players manage their own X" ALL
-- policy gated on ownership. Permissive policies are OR'd together, so a
-- row is visible/writable if EITHER policy allows it.
--
-- The "own X" policies' WITH CHECK clauses correctly required
-- is_campaign_member(campaign_id) in addition to ownership -- but their
-- USING clauses (which govern visibility of EXISTING rows, including for
-- UPDATE/DELETE targeting and plain SELECT via the "for all" grant) only
-- checked ownership, not membership. Net effect: once a player has ever
-- owned a roster/unit/advance/game row in a campaign, they retain read AND
-- write access to it forever via the "own X" policy, even after leaving or
-- being removed from that campaign -- completely bypassing the campaign
-- isolation model.
--
-- Confirmed live: test C3 (an "outsider" with no campaign_members row
-- anywhere) could still see their own pre-existing roster in SKULL-0001
-- after being removed from it, purely through "players manage their own
-- rosters"'s ownership-only USING clause.
--
-- Fix: USING now requires is_campaign_member(campaign_id) in addition to
-- ownership, matching the WITH CHECK that was already correct. units and
-- unit_advances phrase this as an extra top-level AND rather than folding
-- it into their EXISTS subqueries, since is_campaign_member() takes the
-- row's own campaign_id column directly (denormalized in 004) and doesn't
-- need the join.
--
-- Idempotent: safe to re-run. Run after 009/010.
-- ============================================================================

drop policy if exists "players manage their own rosters" on rosters;
create policy "players manage their own rosters" on rosters
  for all to authenticated
  using (auth.uid() = player_id and is_campaign_member(campaign_id))
  with check (auth.uid() = player_id and is_campaign_member(campaign_id));

drop policy if exists "players manage their own units" on units;
create policy "players manage their own units" on units
  for all to authenticated
  using (
    is_campaign_member(units.campaign_id)
    and exists (select 1 from rosters r where r.id = units.roster_id and r.player_id = auth.uid())
  )
  with check (
    is_campaign_member(units.campaign_id)
    and exists (
      select 1 from rosters r
       where r.id = units.roster_id
         and r.player_id = auth.uid()
         and r.campaign_id = units.campaign_id
    )
  );

drop policy if exists "players manage their own advances" on unit_advances;
create policy "players manage their own advances" on unit_advances
  for all to authenticated
  using (
    is_campaign_member(unit_advances.campaign_id)
    and exists (
      select 1 from units u join rosters r on r.id = u.roster_id
       where u.id = unit_advances.unit_id and r.player_id = auth.uid()
    )
  )
  with check (
    is_campaign_member(unit_advances.campaign_id)
    and exists (
      select 1 from units u join rosters r on r.id = u.roster_id
       where u.id = unit_advances.unit_id
         and r.player_id = auth.uid()
         and u.campaign_id = unit_advances.campaign_id
    )
  );

drop policy if exists "players manage their own games" on games;
create policy "players manage their own games" on games
  for all to authenticated
  using (auth.uid() = player_id and is_campaign_member(campaign_id))
  with check (auth.uid() = player_id and is_campaign_member(campaign_id));
