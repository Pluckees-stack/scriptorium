-- ============================================================================
-- 010_rls_policies_all_tables.sql
--
-- Phase 2, part 2.
--
-- Replaces every pre-multi-tenant policy with a campaign-scoped one.
-- Existing policy names/logic (below) were pulled from pg_policies on the
-- live database, not guessed -- each DROP targets a real policy, not an
-- assumed one. Where a table already only had a read-only policy (no write
-- policy existed at all), there's nothing to drop for writes, only add.
--
-- Decisions baked into this file (confirmed in conversation, not assumed):
--   - Organisers get NO override on player-owned data: rosters, units,
--     unit_advances, and games stay strictly owner-write, exactly as
--     before, just now also campaign-scoped. Organiser/admin power is
--     confined to campaign administration: alliances, missions,
--     trait_objectives, campaign_members, and the campaigns row itself.
--   - Campaign metadata (name, join_code, status) is readable by any
--     signed-in user, not just members -- needed so a join code can be
--     looked up before joining, and campaign names/join codes aren't
--     treated as secret in practice.
--   - Platform admin/superadmin gets read+write on every "campaign
--     administration" table (campaigns, campaign_members, alliances,
--     missions, trait_objectives) platform-wide, but deliberately NOT on
--     player-owned data (rosters/units/unit_advances/games) -- consistent
--     with "no organiser override" above; admins don't get something
--     organisers themselves don't have.
--
-- ============================================================================
-- SUMMARY -- every table and its policies after this migration:
--
-- campaigns          SELECT: any authenticated user.
--                    INSERT: superadmin only.
--                    UPDATE: organiser of that campaign, or platform admin/superadmin.
--                    DELETE: superadmin only (not exposed in any UI yet; deliberately conservative).
--
-- campaign_members   SELECT: any member of that campaign, or platform admin/superadmin.
--                    INSERT: self only, forced role='player', alliance_id/tier NULL -- this is how joining works.
--                    UPDATE: self, but only faction_id/onboarded -- role/alliance_id/tier
--                            are REVOKEd from `authenticated` entirely; changing them
--                            requires the SECURITY DEFINER functions in
--                            011_campaign_membership_admin_functions.sql, callable only
--                            by that campaign's organiser or a platform admin/superadmin.
--                    DELETE: self only (leaving a campaign). Removing OTHERS requires
--                            011's remove_campaign_member(), organiser/admin only.
--
-- rosters            SELECT: any member of that roster's campaign.
--                    ALL:    owner (player_id = auth.uid()); INSERT/UPDATE additionally
--                            requires is_campaign_member(campaign_id).
--
-- units              SELECT: any member of that unit's campaign.
--                    ALL:    owner via roster chain, same shape as before; INSERT/UPDATE
--                            additionally requires units.campaign_id to match its
--                            roster's actual campaign_id (closes a spoofing gap the
--                            denormalized column would otherwise allow).
--
-- unit_advances      SELECT: any member of that row's campaign.
--                    ALL:    owner via unit->roster chain, same shape as before;
--                            INSERT/UPDATE additionally requires unit_advances.campaign_id
--                            to match its unit's actual campaign_id.
--
-- games              SELECT: any member of that game's campaign.
--                    ALL:    owner (player_id = auth.uid()); INSERT/UPDATE additionally
--                            requires is_campaign_member(campaign_id). No organiser
--                            override, per decision above.
--
-- alliances          SELECT: any member of that alliance's campaign, or platform admin/superadmin.
--                    ALL:    organiser of that campaign, or platform admin/superadmin.
--
-- missions           SELECT: campaign_id IS NULL (official, visible to everyone),
--                            OR is_campaign_member(campaign_id), OR platform admin/superadmin.
--                    ALL (official):  campaign_id IS NULL AND platform admin/superadmin.
--                    ALL (custom):    campaign_id IS NOT NULL AND (organiser of that
--                                     campaign OR platform admin/superadmin).
--
-- trait_objectives   Same hybrid shape as missions.
--
-- players            UNCHANGED. Stays all-read / owner-write, campaign-agnostic (pure
--                    account identity). Its one sensitive column (platform_role) was
--                    already locked at the column-privilege level in 002, independent
--                    of this row policy -- no row policy could expose it regardless.
-- factions           UNCHANGED -- global reference data, read-only.
-- catalog_units      UNCHANGED -- global reference data, read-only, unused by the app.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- campaigns (new table, no existing policies)
-- ---------------------------------------------------------------------------
create policy "campaigns are readable by any signed-in user" on campaigns
  for select to authenticated
  using (true);

create policy "superadmin creates campaigns" on campaigns
  for insert to authenticated
  with check (is_superadmin());

create policy "organisers and admins update their campaign" on campaigns
  for update to authenticated
  using (is_campaign_organiser(id) or is_platform_admin())
  with check (is_campaign_organiser(id) or is_platform_admin());

create policy "superadmin deletes campaigns" on campaigns
  for delete to authenticated
  using (is_superadmin());

-- ---------------------------------------------------------------------------
-- campaign_members (new table, no existing policies)
-- ---------------------------------------------------------------------------
create policy "members can read their campaign's membership" on campaign_members
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "users can join a campaign as a player" on campaign_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'player'
    and alliance_id is null
    and tier is null
  );

create policy "members can update their own faction and onboarded flag" on campaign_members
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "members can leave a campaign" on campaign_members
  for delete to authenticated
  using (user_id = auth.uid());

-- role/alliance_id/tier changes must go through 011's SECURITY DEFINER
-- functions -- see that file's header for why this can't be expressed as a
-- plain RLS policy.
revoke update (role, alliance_id, tier) on campaign_members from authenticated;

-- ---------------------------------------------------------------------------
-- alliances
-- Existing: "read alliances" (select, true). No write policy existed.
-- ---------------------------------------------------------------------------
drop policy if exists "read alliances" on alliances;

create policy "campaign members can read alliances" on alliances
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage alliances" on alliances
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- rosters
-- Existing: "read rosters" (select, true), "own rosters" (all, auth.uid() = player_id).
-- ---------------------------------------------------------------------------
drop policy if exists "read rosters" on rosters;
drop policy if exists "own rosters" on rosters;

create policy "campaign members can read rosters" on rosters
  for select to authenticated
  using (is_campaign_member(campaign_id));

create policy "players manage their own rosters" on rosters
  for all to authenticated
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id and is_campaign_member(campaign_id));

-- ---------------------------------------------------------------------------
-- units
-- Existing: "read units" (select, true),
--           "own units" (all, exists (...rosters... r.player_id = auth.uid())).
-- ---------------------------------------------------------------------------
drop policy if exists "read units" on units;
drop policy if exists "own units" on units;

create policy "campaign members can read units" on units
  for select to authenticated
  using (is_campaign_member(campaign_id));

create policy "players manage their own units" on units
  for all to authenticated
  using (
    exists (select 1 from rosters r where r.id = units.roster_id and r.player_id = auth.uid())
  )
  with check (
    exists (
      select 1 from rosters r
       where r.id = units.roster_id
         and r.player_id = auth.uid()
         and r.campaign_id = units.campaign_id
    )
  );

-- ---------------------------------------------------------------------------
-- unit_advances
-- Existing: "read advances" (select, true),
--           "own advances" (all, exists (...units join rosters... r.player_id = auth.uid())).
-- ---------------------------------------------------------------------------
drop policy if exists "read advances" on unit_advances;
drop policy if exists "own advances" on unit_advances;

create policy "campaign members can read advances" on unit_advances
  for select to authenticated
  using (is_campaign_member(campaign_id));

create policy "players manage their own advances" on unit_advances
  for all to authenticated
  using (
    exists (
      select 1 from units u join rosters r on r.id = u.roster_id
       where u.id = unit_advances.unit_id and r.player_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from units u join rosters r on r.id = u.roster_id
       where u.id = unit_advances.unit_id
         and r.player_id = auth.uid()
         and u.campaign_id = unit_advances.campaign_id
    )
  );

-- ---------------------------------------------------------------------------
-- games
-- Existing: "read games" (select, true), "own games" (all, auth.uid() = player_id).
-- ---------------------------------------------------------------------------
drop policy if exists "read games" on games;
drop policy if exists "own games" on games;

create policy "campaign members can read games" on games
  for select to authenticated
  using (is_campaign_member(campaign_id));

create policy "players manage their own games" on games
  for all to authenticated
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id and is_campaign_member(campaign_id));

-- ---------------------------------------------------------------------------
-- missions (new table, no existing policies)
-- ---------------------------------------------------------------------------
create policy "read official or own-campaign missions" on missions
  for select to authenticated
  using (campaign_id is null or is_campaign_member(campaign_id) or is_platform_admin());

create policy "admins manage official missions" on missions
  for all to authenticated
  using (campaign_id is null and is_platform_admin())
  with check (campaign_id is null and is_platform_admin());

create policy "organisers manage campaign missions" on missions
  for all to authenticated
  using (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()))
  with check (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()));

-- ---------------------------------------------------------------------------
-- trait_objectives
-- Existing: "read traits" (select, true). No write policy existed.
-- ---------------------------------------------------------------------------
drop policy if exists "read traits" on trait_objectives;

create policy "read official or own-campaign trait objectives" on trait_objectives
  for select to authenticated
  using (campaign_id is null or is_campaign_member(campaign_id) or is_platform_admin());

create policy "admins manage official trait objectives" on trait_objectives
  for all to authenticated
  using (campaign_id is null and is_platform_admin())
  with check (campaign_id is null and is_platform_admin());

create policy "organisers manage campaign trait objectives" on trait_objectives
  for all to authenticated
  using (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()))
  with check (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()));

-- ---------------------------------------------------------------------------
-- players, factions, catalog_units: no changes -- see SUMMARY above.
-- ---------------------------------------------------------------------------
