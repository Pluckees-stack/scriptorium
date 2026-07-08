# Migrations

Run these in order, in the Supabase SQL editor. Each file is idempotent (safe
to re-run) except where noted.

## Phase 1 — schema

| File | Does | Notes |
|---|---|---|
| `001_campaigns_and_membership.sql` | Creates `campaigns` and `campaign_members`; adds `players.is_superadmin` (superseded by `002`); seeds one test campaign (join code `SKULL-0001`) and copies every existing player into it as a member, carrying their current faction/alliance/tier/onboarded across. Locks both new tables with RLS enabled, zero policies. | **Run.** |
| `002_platform_admin_tier.sql` | Replaces `players.is_superadmin` with a ranked `platform_role` (`player` < `admin` < `superadmin`). Admins are platform-wide (any campaign, not a `campaign_members` grant): can assign organisers and manage missions/objectives (official or campaign-custom) anywhere; only a superadmin can create campaigns or mint new admins. | **Run.** |
| `003_scope_alliances_rosters_games.sql` | Adds `campaign_id` to `alliances`, `rosters`, `games`; backfills to the seed campaign. | **Run.** |
| `004_scope_units_and_unit_advances.sql` | Adds `campaign_id` to `units` and `unit_advances`, denormalized from their parent row rather than the seed campaign directly. | **Run.** |
| `005_missions_table.sql` | New `missions` table — hybrid (`campaign_id` NULL = official template, non-null = campaign custom). Locked with RLS, zero policies. | **Run.** |
| `006_trait_objectives_hybrid.sql` | Adds nullable `campaign_id` + `created_by` to `trait_objectives`, same hybrid pattern as missions. Existing rows stay NULL (official). | **Run.** |
| `007_rewrite_standings_views.sql` | Rewrites `alliance_standings` and `player_standings` off `campaign_members` instead of the `players` columns `008` removes, and fixes a real bug in both: neither filtered `games` by campaign, so a player in two campaigns would have leaked glory/wins across both. | **Run.** |
| `008_players_decommission_campaign_columns.sql` | Drops `faction_id`/`alliance_id`/`tier`/`onboarded` from `players` now that they live on `campaign_members`. | **Run.** |

## Phase 2 — RLS rewrite

| File | Does | Notes |
|---|---|---|
| `009_rls_helper_functions.sql` | `is_campaign_member()`, `is_campaign_organiser()`, `is_superadmin()`, `is_platform_admin()` — all `SECURITY DEFINER`, used throughout every policy below. | **Run.** |
| `010_rls_policies_all_tables.sql` | Drops every pre-multi-tenant policy (real names pulled from `pg_policies`, not guessed) and replaces them with campaign-scoped versions. Full table-by-table enumeration in its header. | **Run — confirmed working.** |
| `011_campaign_membership_admin_functions.sql` | `set_campaign_member_role`/`_alliance`/`_tier`, `remove_campaign_member` — the only way to change those three `campaign_members` columns, since `010` revokes direct `UPDATE` on them (RLS can't express "self writes column A, organiser writes A+B+C, same row, same DB role"). | Run after `009`/`010`. |
| `012_standings_views_security_invoker.sql` | Sets `security_invoker = true` on both standings views (confirmed PG 17.6 supports it) so campaign isolation is enforced by the underlying tables' RLS, not by client-side filtering convention. | Run after `010`. |
| `013_set_platform_role_function.sql` | `set_platform_role()` — gap found while writing the test plan: `002` revoked self-promotion but never gave a superadmin a client-facing way to promote someone to admin. This is that path. | Run after `009`. |
| `014_rewrite_xp_functions.sql` | Rewrites `log_game_with_xp` to accept and validate `campaign_id` (required now that the column is `NOT NULL`). `increment_unit_xp` and `delete_game_with_xp` need no changes — confirmed from their actual bodies, not assumed; both already work purely through RLS ownership checks that carry over unchanged. | Run after `009`. |
| `015_fix_campaign_members_column_privileges.sql` | **Security fix.** `010`'s column-specific `revoke update (role, alliance_id, tier) ... from authenticated` was a no-op — Supabase's default blanket table-level `UPDATE` grant to `authenticated` overrides a column-specific revoke layered on top of it in Postgres. Any player could update their own `role`/`alliance_id`/`tier` directly, bypassing `011`'s admin functions entirely (e.g. self-promoting to `organiser`). Found live during `PHASE2_TEST_PLAN.md` test B7. Revokes `UPDATE` on the whole table from `authenticated`, then grants it back only on `faction_id`/`onboarded`. | **Run this before continuing past B7.** |
| `016_fix_own_row_policies_membership_gap.sql` | **Security fix.** `010`'s "players manage their own X" policies on `rosters`/`units`/`unit_advances`/`games` had a `WITH CHECK` requiring campaign membership but a `USING` clause that checked ownership only — so once a player owned a row in a campaign, they kept read/write access to it forever via that policy, even after leaving the campaign, completely bypassing isolation. Found live during test C3 (outsider persona still seeing their old `SKULL-0001` roster). Adds the missing `is_campaign_member()` check to all four `USING` clauses. | **Run this before continuing past C3.** |
| `PHASE2_TEST_PLAN.md` | Impersonation technique + concrete allow/deny test cases for organiser, player, outsider, admin, and superadmin personas, plus the three XP functions and both standings views. | Run through this before considering Phase 2 done. |

## Feature migrations (post Phase 2)

| File | Does | Notes |
|---|---|---|
| `017_add_unit_nicknames.sql` | Adds nullable `units.nickname`. No RLS changes — already covered by `016`'s own-unit policy. | **Run.** |
| `018_add_mission_scenario_fields.sql` | Adds `missions.random_length`, `common_objectives` (text[]), `secondary_objectives` (jsonb) for the Mission Admin form's Scenario/Map/objectives pickers. No new `map` column — reuses `deployment_type`. No RLS changes — already covered by `010`'s missions policies. | **Run.** |
| `019_add_mission_to_games.sql` | Adds `games.mission_id` (FK, `ON DELETE SET NULL`) so Game View's new mission picker can be recorded on a logged battle. Re-creates `log_game_with_xp` (014's body, `+mission_id`) to accept it — also finally populates the pre-existing but previously-unused `games.scenario` text column, as a name snapshot (same twin-column pattern as `opponent_id`/`opponent_name`). Selection only — not yet wired into VP scoring. | **Run after 018.** |

## Status

Phase 1 (`001`–`008`) and Phase 2 (`009`–`016`) are fully run and confirmed.
`PHASE2_TEST_PLAN.md` sections A–F have all been run and pass. Two real
policy bugs were found and fixed along the way — `015` (test B7, column
privileges) and `016` (test C3, own-row USING clauses) — both are resolved
and re-verified. **Phase 2 is done.**

## What's still open

- **Phase 4 gotcha found during B13**: joining a campaign via a plain
  `insert into campaign_members (...)` works correctly, but chaining a
  `RETURNING`/`.select()` onto that same insert throws a spurious RLS
  violation — `campaign_members`'s `SELECT` policy calls
  `is_campaign_member()`, a `SECURITY DEFINER` function that queries
  `campaign_members` itself, and checking that against a row inserted by
  the very same command hits a snapshot-timing quirk. The insert itself is
  correct and secure; just don't chain `.select()` onto the join-by-code
  insert in `index.html` — do the insert plain, then a separate `.select()`
  afterwards if the row is needed back.
- One open design point, deliberately left as-is pending testing: platform
  admins currently get **no read access** to player-owned data (rosters/
  units/games) in campaigns they're not a member of, even though they can
  administer those campaigns' alliances/missions/members. Easy to change
  later (`010`'s "campaign members can read rosters/units/games" policies)
  if testing shows it's needed.
- "Pairing players" (mentioned alongside admin's other powers) — not yet
  scoped. Unclear if it needs a new table (rounds/brackets) or is just an
  Admin Console UI feature over the existing `games` table. Deferred.
- Phase 3 (Google OAuth) and Phase 4 (`index.html` multi-tenancy) per the
  original brief. Phase 4 in particular now has a concrete list of required
  changes: the opponent picker, trait-objective dropdown, onboarding
  wizard, and player-record query all need to become campaign-aware; the
  battle-logging call needs to pass `campaign_id` into `log_game_with_xp`;
  and any future caller of `player_standings`/`alliance_standings` needs to
  filter by `campaign_id` (`player_standings` is now one row per
  (player, campaign), not per player).
