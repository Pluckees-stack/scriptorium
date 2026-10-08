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
| `026_narrative_updates.sql` | Adds `campaigns.narrative_enabled` (organiser on/off switch) and a new `narrative_pages` table — a click-through book of story pages (title, body, optional image) shown in a player-facing "Narrative updates" tab. Same campaign-scoped table + RLS shape as `020`. | **Run after 025.** |
| `020_campaign_phases_and_free_play.sql` | Two features at once: `campaign_phases` + `campaign_phase_missions` (an organiser-locked round with a fixed pool of scenario slots, one active phase per campaign), and free play — an unscored game that bypasses the phase gate entirely. Adds `games.phase_id` so a logged battle records which round it belonged to. | **Run.** |
| `021_add_phase_max_games.sql` | Adds campaign_phases.max_games -- an organiser-set cap (1-5, or NULL for "Uncapped") on how many scoring games a player may submit within that phase, independent of how many missions are in its pool. | **Run.** |
| `022_allow_phase_mission_repeats_when_capped.sql` | Bug found live: a phase with a 1-mission pool and max_games = 2 locked the player out after their first game, because "no unused missions left in the pool" was an unconditional lock -- it never gave max_games a chance to be the more permissive limit. | **Run.** |
| `023_rename_glory_to_campaign_points.sql` | Renames the "Glory Points" scoring metric to "Campaign Points" throughout the schema — columns, views and RPCs — at Grant's explicit request, to stop it being confused with Old World's own unrelated "Path to Glory" veteran mechanic (untouched here). | **Run.** |
| `024_add_mission_objective_vp.sql` | Adds missions.objective_vp jsonb -- per-mission overrides of the VP value awarded for each common/secondary objective (King is Dead, Trophies of War, Breaking the Enemy, Special Feature, Baggage Trains, Domination, Strategic Locations). | **Run.** |
| `025_remove_tier.sql` | Removes the player "tier" mechanism entirely: campaign_members.tier, the player_tier enum, the set_campaign_member_tier() RPC that wrote it, and every reference to it in player_standings / RLS. | **Run.** |
| `027_path_to_glory_toggle.sql` | campaigns.path_to_glory_enabled -- organiser on/off switch for the Path to Glory mechanic (XP, Veteran Abilities/Seasoned Commander, Battlefield Losses/Death & Dishonour). | **Run.** |
| `028_admin_game_log_override.sql` | Reverses part of the "no organiser override on player-owned data" decision from 010_rls_policies_all_tables.sql, for games specifically. | **Run.** |
| `029_admin_audit_log.sql` | admin_audit_log -- who did what, campaign-scoped, for the admin tables that can only be written by an organiser/platform admin in the first place (alliances, missions, trait_objectives, campaign_phases, campaigns), plus the two places where an organiser now acts on data that isn't theirs: campaign_members (promote/demote/alliance-assign/remove -- via 011's SECURITY DEFINER functions) and games (the migrations/028 admin override). | **Run.** |
| `030_alliance_emblem.sql` | alliances.emblem_url -- optional image for an alliance, shown as a small roundel next to its name in Player Admin and on the standings hub. | **Run.** |
| `031_platform_admin_games_read.sql` | Extends games' SELECT policy to platform admins/superadmins, read-only. | **Run.** |
| `032_announcements.sql` | announcements -- short, dated, logistics posts from an organiser ("round 3 starts Friday"), distinct from narrative_pages (026): that's ongoing story content read as a click-through book, opt-in per campaign via a toggle. | **Run.** |
| `033_games_battle_stats.sql` | Three new columns on games, captured at log time, for the Admin Overview's campaign-wide "fun stats" (total models killed/fled, baggage carts destroyed) -- confirmed with Grant 2026-07-22 that these only need to count forward from whenever this ships, not backfill history that was never captured. | **Run.** |
| `034_games_slain_fled_split.sql` | Splits migrations/033's combined models_removed into two separate counts — the Admin Overview now shows "Models Slain" and "Cowards" (fled) as their own stat tiles rather than one merged "killed or fled" figure. | **Run.** |
| `035_games_standards_captured.sql` | Adds standards_captured (enemy banners/standards taken as trophies) to games, for the Top Generals detail popup's "Banners captured" stat. | **Run.** |
| `036_end_campaign_gating.sql` | "Archive campaign" is being relabelled "End campaign" in the UI, and Grant wants it to actually mean something rather than just a cosmetic status flag: while ended, no new players can join and no new battles can be logged. | **Run.** |
| `037_mission_maps.sql` | Backs the new "Deployment map" step of the Mission Admin creation wizard: maps become a real table (name + image) instead of the hardcoded MISSION_MAPS/MISSION_MAP_IMAGES lists in index.html, so organisers can upload their own custom maps alongside the 11 built-in ones. | **Run.** |
| `038_custom_objectives.sql` | Backs Mission Admin's new "Custom objectives" picker/creator (step 3 of the mission wizard): bespoke objectives with their own name, description and reward (VP / XP / Campaign points, any combination), same official/campaign-custom hybrid as maps/missions/trait_objectives (campaign_id null = official, visible in every campaign). | **Run.** |
| `039_tournaments.sql` | Tournaments: a self-contained Swiss / single-elimination / round-robin event scoped to a campaign. Adds `tournaments`, `tournament_entrants`, `tournament_rounds` and `tournament_pairings`, all organiser-managed, serving both a standalone tournament campaign and a one-off event inside a narrative season. | **Run.** |
| `040_rosters_locked.sql` | Gates the Membership roster browser (added in the previous migration-less change): nobody should be able to browse another player's muster list until an organiser explicitly locks lists in for the round, matching real tournament list-lock semantics (submissions close, then everyone's list becomes visible at once) rather than lists leaking out piecemeal. | **Run.** |
| `041_fix_audit_log_campaign_id_lookup.sql` | Fixes: removing a player from a campaign (and any other write to campaign_members) fails with "record 'new' has no field 'id'". | **Run.** |
| `042_fix_map_upload_storage_rls.sql` | Fixes: uploading a map image can fail silently for a platform admin/ superadmin who isn't *also* specifically an organiser of the campaign they're currently viewing. | **Run.** |
| `043_alliance_point_adjustments.sql` | Lets an organiser hand out (or claw back) campaign points to a whole alliance directly, for event rules that award points outside of normal battle logging (e.g. "the alliance holding the most territory at the end of the day gets +50"). | **Run.** |
| `044_fix_alliance_standings_security_invoker.sql` | Fixes: Supabase's security advisor flags alliance_standings as a "Security Definer View" (critical) -- it runs with the view owner's permissions rather than the querying user's, bypassing the underlying tables' RLS for whoever queries it. | **Run.** |
| `045_rls_auth_uid_init_plan.sql` | Fixes: Supabase's advisor flags 10 policies across 6 tables with "Auth RLS Initialization Plan" warnings -- each embeds a raw auth.uid() call in its USING/WITH CHECK expression, which Postgres re-evaluates once per row instead of once per query. | **Run.** |
| `046_security_advisor_warnings.sql` | Clears the batch of WARN-level items Supabase's security advisor surfaced once the earlier CRITICAL view/RLS issues (044, 045) were fixed — pinning `search_path` on SECURITY DEFINER functions and tightening who may execute them. | **Run.** |
| `047_email_for_username_lookup.sql` | Supports the move from synthetic (`username@seasonofskulls.app`, see index.html's toEmail()) to real player emails. | **Run.** |
| `048_games_two_sided_confirmation.sql` | Part 1 of the VP-vs-Campaign-Points split (see 050 for the standings side). | **Run.** |
| `049_game_confirmation_rpcs.sql` | Rewrites log_game_with_xp so logging a battle only ever inserts a pending row -- no XP is granted at insert time any more. | **Run.** |
| `050_game_credits_and_standings.sql` | Part 2 of the VP-vs-Campaign-Points split (see 048/049 for the schema and confirmation RPCs). player_standings/alliance_standings (most recently redefined in 025/030) have only ever credited the LOGGING player's side of a game (joining games.player_id). | **Run.** |
| `051_fix_self_delete_game_xp.sql` | delete_game_with_xp (the player-facing "remove this battle" button, predates migration tracking) had two problems once 048/049 introduced two-sided, held-until-confirmed XP: | **Run.** |
| `052_game_invites.sql` | Today, picking an opponent in Game View starts tracking their roster immediately -- they have no say and may not even know a "game" has started against them. | **Run.** |
| `053_game_invite_readiness.sql` | migrations/052 got B a say in whether a game starts at all (accept/ decline), but once accepted, B had no further part to play -- only A went through spell-picking before Playing began. | **Run.** |
| `054_game_session_state.sql` | Extends game_invites (052) again, same pattern as 053's from_ready_at/ to_ready_at: the accepted invite row keeps carrying more facts about the live game it coordinates, rather than a new table. | **Run.** |
| `055_game_invite_completed_status.sql` | Adds 'completed' to game_invites.status (052). | **Run.** |
| `056_player_alliance_selection.sql` | Alliances (team groupings for campaign standings) could previously only be assigned by an organiser, via set_campaign_member_alliance (migrations/011). | **Run.** |
| `057_tournament_pairing_games.sql` | Stage 2b of tournament-format support: wire a tournament pairing to the real two-sided game the two players log for it, so the pairing's result fills itself in once that game is confirmed -- instead of the organiser re-typing every result (migration 039 deliberately decoupled the two; that predated the two-sided confirm/XP system from 048-050, and a *confirmed* game is now a solid enough record to derive a result from). | **Run.** |
| `058_campaign_point_tiers_and_bulk_confirm.sql` | Two campaign-management fixes prompted by the live season: `campaigns.campaign_point_tiers` (the CP awarded per result tier, now editable per campaign instead of hardcoded), and `admin_confirm_pending_games()` so an organiser can clear a backlog of unconfirmed battles in one go. | **Run.** |
| `059_tournament_setup_gating.sql` | Tightens tournament/campaign setup so a live season can't run half-configured: `campaigns.player_cap` (an optional hard limit on self-service joins, which platform admins bypass) and `tournaments.entrants_locked_at` (marks the point where the entrant list freezes and every round exists to be given a scenario). | **Run.** |
| `060_tournament_round_scenarios_preset.sql` | 059 gated round-scenario assignment behind "Lock entrants" (the step that creates the tournament_rounds rows the scenario picker writes to). | **Run.** |
| `061_tournament_table_scenarios.sql` | Lets a round use a different scenario per table instead of one scenario for everyone. | **Run.** |
| `062_tournament_points_limit.sql` | A tournament can now declare a max army points value (e.g. 2000pts). Purely informational at the DB layer -- index.html uses it to flag a submitted muster list that's over, and to auto-check an entrant in the Entrants picker only once they have a list at or under it. | **Run.** |
| `063_auto_create_players_row.sql` | Durable fix for the recurring "insert or update on table campaign_members violates foreign key constraint campaign_members_user_id_fkey" join/login failure (alexjclark 2026-09-02, synners 2026-09-11). | **Run.** |
| `064_tournament_final_reveal.sql` | Lets an organiser hold back a tournament's final-round result/standings from players until they're ready to reveal it -- e.g. an in-person prize ceremony, where the organiser wants to do something dramatic before everyone finds out who won. | **Run.** |
| `065_unit_archived_flag.sql` | Lets a unit be retired/archived without deleting it -- the row and its XP/kill/wound history stay forever (unit_advances.unit_id and every games.kill_credits/opponent_kill_credits jsonb reference to it keep resolving), it just stops being offered as a live pick in Game View. | **Run.** |
| `066_alliance_rank_perks.sql` | Awards a narrative rule to the top 3 alliances (by Campaign Points) when a phase/round is marked completed -- e.g. 1st place gets "Quenched" (a special rule), 2nd "Thirsty", 3rd "Parched". | **Run.** |
| `067_mission_special_rules_list.sql` | missions.special_rules was a single free-text blob -- fine for one rule, unreadable for several (no line breaks survive into the rendered <p>). | **Run.** |
| `068_admin_manual_game.sql` | Lets an organiser record a battle that nobody logged through Game View -- a game that just never got entered, or a 3+ player game, which the two-sided Game View flow can't represent at all. | **Run.** |
| `070_lock_games_and_private_helpers.sql` | **Security fix.** Players could edit their own `games` rows directly (e.g. mark a battle confirmed and set their own campaign points), and three private XP/pairing helpers were callable by anyone. Makes `log_game_with_xp` `SECURITY DEFINER`, drops the "players manage their own games" write policy, and revokes the helpers from `anon`/`authenticated`. No `index.html` change. (`069` is WarCastle, still on its branch; independent.) | Not yet run. |

## Status

Every migration in this folder, `001` through `068`, has been run against the
live database and confirmed. `PHASE2_TEST_PLAN.md` sections A–F have all been
run and pass; two real policy bugs were found and fixed along the way — `015`
(test B7, column privileges) and `016` (test C3, own-row USING clauses) — both
resolved and re-verified.

When adding a migration: run it in the Supabase SQL editor, then add its row
above. Anything not listed here has not been applied.

## What's still open

- **Gotcha worth remembering**: joining a campaign via a plain
  `insert into campaign_members (...)` works correctly, but chaining a
  `RETURNING`/`.select()` onto that same insert throws a spurious RLS
  violation — `campaign_members`'s `SELECT` policy calls
  `is_campaign_member()`, a `SECURITY DEFINER` function that queries
  `campaign_members` itself, and checking that against a row inserted by the
  very same command hits a snapshot-timing quirk. The insert itself is
  correct and secure; just don't chain `.select()` onto the join-by-code
  insert in `index.html` — do the insert plain, then a separate `.select()`
  afterwards if the row is needed back.
- One open design point, deliberately left as-is: platform admins get **no
  read access** to player-owned data (rosters/units/games) in campaigns they
  aren't a member of, even though they can administer those campaigns'
  alliances/missions/members. Easy to change later (`010`'s "campaign members
  can read rosters/units/games" policies) if it ever proves needed.
- The July-2026 synthetic-email accounts (`<name>@seasonofskulls.app`) can
  still collide with a later real-email signup, since the old row squats the
  `display_name` (unique on `lower(display_name)`, `047`). `063`'s trigger
  stops *new* accounts ever lacking a `players` row, but it can't resolve that
  collision — those are still fixed per-user as they surface, by design.
