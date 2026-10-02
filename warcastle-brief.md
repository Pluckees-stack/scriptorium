# WarCastle — working brief

A one-off event, run as its own campaign inside Scriptorium. This file is the
running brief: decisions settled, what we get for free, and what's still open.
Grant can add to it from a phone; nothing here is built yet.

## Decided

- **Lives as a new campaign in the existing app**, not a separate deployment.
  Everything in Scriptorium is already campaign-scoped and enforced by RLS, so
  a WarCastle campaign is fully sealed off from Season of Skulls — own players,
  rosters, battles, standings, scenarios and admin. Players keep one login, and
  every fix we make applies to both.
- **A third campaign format, `warcastle`**, drives the different interface —
  exactly how `tournament` already reshapes terminology, tabs and flows via
  `applyCampaignFormatScope()`. Needs a one-line migration to the
  `campaigns_format_check` constraint.
- **Game view is reused as-is** — battle logging, rosters, wound tracking, the
  two-sided confirm flow. No changes needed there.
- **Two things get built**: a player-facing interface focused on "what do I do
  next", and a bespoke organiser console for running the day.

## What already exists that we can build on

Worth knowing before designing anything new — a lot of the event-running
machinery is already there from the tournament work:

| Already built | Where |
|---|---|
| Rounds with status (draft → active → completed), organiser-driven | `tournament_rounds` (039) |
| Pairings, including table numbers and per-table scenarios | `tournament_pairings` (039, 061) |
| Swiss / elimination / round-robin pairing generation | `generateSwissPairings` etc., `index.html` |
| "Play this game" prompt telling a player their opponent, table and scenario | `refreshTournamentGameCta` |
| Live standings, and holding back the final round until revealed | `tournamentStandingsHtml`, 064 |
| Organiser announcements to all players | `announcements` (032) |
| Story/info pages as a click-through book | `narrative_pages` (026) |
| Scenarios with objectives, VP values and custom objectives | `missions` (005, 024, 038) |
| Manually entering a result, including multi-player games | `admin_log_manual_game` (068) |

If WarCastle is round-and-pairing shaped, most of the back end exists and this
becomes largely a **presentation and admin-console job** — which is also the
part that's safe to build and ship while Grant is away, since it needs no
schema changes.

## Open questions

Answer any of these in any order — rough notes are fine.

1. **Is it round-based with pairings?** i.e. players get told "round 2, table 5,
   vs X, scenario Y". If yes, the tournament machinery above mostly applies and
   this gets much smaller. If it's something else (one big battle, free-roaming
   challenges, teams), say roughly how play is structured.
2. **How is a winner decided?** Per-player score, two sides each contributing,
   teams, objectives ticked off? This decides whether `games` as it stands fits.
3. **What should a player see on their phone during the event?** The "clean,
   easy to follow" bit — presumably always-visible "here's what you do next",
   but say what else matters (schedule, map of tables, scores, rules reminders).
4. **What does pushing info out look like?** Announcements that appear on their
   screen, a schedule that updates as rounds change, both?
5. **What do you need to do fastest on the day?** The organiser console should
   be built around whatever you'll be doing under time pressure with people
   waiting — starting rounds, entering results, re-pairing, answering "where do
   I go".
6. **Scale and shape of the day** — how many players, how many rounds, how long?

## Constraints while Grant is away

- **Anything needing a migration can't go live** — migrations run by hand in the
  Supabase SQL editor. Possible from a phone for a one-liner, painful for
  anything bigger. Schema work will be written and left ready, not merged.
- **No one can test against a real campaign**, so the more something touches a
  live workflow, the more it should wait. Pure front-end work is safe.

## Built: map movement and trackers (branch `warcastle-map-movement`)

Answers questions 1, 3 and 5 for the map side of the event. Built as a
**tournament format** (`tournaments.format = 'warcastle'`) rather than a new
campaign format, so it reuses rounds, pairings, per-table scenarios, results
and the "play your pairing" prompt unchanged. Run it in a campaign whose format
is `tournament`. If a `warcastle` *campaign* format is still wanted for the
wider interface, it can sit on top of this.

- **Shape**: 26 armies, 13 map areas, two per area, about 6 rounds. Each area is
  a fixed table with a fixed scenario; a round's pairings are the positions.
- **Movement**: swap rule. Winners, then draws, then losers may swap with an
  army in a neighbouring area that did no better. The organiser enters every
  move on the map; the app flags rule breaks (moving too far, swapping with a
  better result, moving twice, allies together, rematches) but never moves
  anyone itself.
- **Special features** (Manor, World Roots, Shard, ritual altar) only score on
  even rounds.
- **Trackers**: Chaos corruption (milestones 200 and 400, peak 650; Order wins
  take 2 per Order player off; the Tzeentch ritual doubles the next two rounds)
  and Waaagh! energy (a ladder of 80-point rungs to 550; miss a rung and it
  collapses to 0; round 1 is a free climb).
- **Players see**: their area, opponent, table, scenario and deployment map,
  the overworld map and both trackers, on the Standings tab.
- **Needs migration 069** before the format can be used.
