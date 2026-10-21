# Working notes

Read this at the start of each session. Update it before ending one.

## How we work
- Work on a branch, push it and open a PR. Merge only when Grant says "merge",
  except: a PR with no migration may be merged by Claude once its tests and
  browser checks pass (Grant, 19 Oct 2026).
- Several sessions run at once: fetch main before each PR, and in this file
  edit only your own lines and sections.
- Grant runs SQL migrations and seeds himself. Mark each migration "Run" in
  migrations/README.md once he confirms.
- Keep sessions short: one piece of work per session, then update this file.
- Avoid parallel agents and heavy screenshot checks unless asked; they use a
  lot of tokens.

## Open PRs
- Players restructure done (P1 #121, P2 charts; chart view: data points at the top, list filters hidden in Chart, Export CSV of the chart beside Pin to Home), branch claude/festive-ride-0y0cvh. Charts also: By Scenario, measures VP scored / conceded / winning margin, As average per battle or biggest in one battle. Also By Unit / Magic item (Lists taking it, Points spent; a unit by Kills or Times wiped out, the latter Path to Glory only); Lore chart dropped (Grant). Chart options fold away (details.admin-section). Buttons now follow CLAUDE.md UI components (steppers, closes, follow, photo toggle, carousel arrows merged; .pm-btn and .x-btn gone); campaign Set up is Event details / Phases (opens on Phases, and on the phase being played); scenario rows reworked. Home: once the setup checklist is finished (or hidden) it stays put; later gaps join "Needs your attention" (was "Waiting on you"). Storytelling for campaigns to discuss with Grant. Merged: A–E2 (#102–#116), C1–C3 (#117–#119), #120.
- #152 (archived units left out of list points totals: phone roster deck, alliance members' lists, tournament entrants) merged.
- #98 (rules scenarios drawn exactly, seed re-run) merged.
- #100 (scenario editor shows a rules scenario's drawn map once) merged.
- #101 (Play shows the set-up table under the scenario picker, "Edit set-up") merged.

- Account and import (Grant, 21 Oct; no migration) merged (#157): Import is its own panel within Lists: a small Import option to the left of Yours on the Lists switch (Import · Yours · Other players); Lists still opens on Yours, a finished replace import goes back to Yours, onboarding opens Import (an overlay at first, made a normal tab at Grant's ask, 21 Oct). The Account tab is the settings page itself (no Account settings overlay): swipeable cards (drawSwipeCards, with its own .scope-switch.admin-subnav tabs via data-own-tabs) for Profile (name and club, one Save), Campaigns (list, current campaign, join with a code, Run a tournament), Display (theme, dark mode, text size, fun extras), Security (password, two-factor, Sign out). On wider screens the Lists switch's slide is a short nudge and fade (#160). Display also has Font (Classic / Clear = Atkinson Hyperlegible / OpenDyslexic, via data-font on :root swapping the font variables; web font loaded only once picked) and, for organisers and site admins, Admin colour (fold-out: Opposite of my theme, the default, five admin-only colours, or any faction's); both kept on the device only (localStorage scriptorium.font / scriptorium.adminColour), by Grant's choice, 21 Oct. Could move to players columns later. The logo (h1, The Scriptorium) keeps Old London whatever the font (#163). Accessibility (Grant, 21 Oct): every theme is kept readable by readableAccent (pale text on the main colour and dark-or-pale text on gold, both 4.5:1; colours nudged only as far as needed; --on-gold replaces fixed #171a1c on gold); Display has High contrast and Reduce motion switches (data-contrast / data-motion on :root, set in <head> from the device, else the phone's own settings; reduceMotion() replaces the matchMedia checks); Skip to content link. Faction themes have their own names on Account › Display (FACTION_ACCENTS[].theme, a place and its colour: Athel Loren emerald, Warpstone green, Hashut rust, Naggaroth violet, …; the gods likewise, Khorne red …; .label stays the faction name everywhere else); the four Chaos gods are themes too (EXTRA_THEMES god-khorne/-nurgle/-tzeentch/-slaanesh, also offered as admin colours). Chaos Black (white on black, the black page) and White Scar (black on white, the white page; swapped at Grant's ask) are EXTRA_THEMES with page:'light'/'dark' (they ignore dark mode), onOxblood and panelInput; --brand is the theme colour as text on the page (logo, eyebrows, links), set to the ink for these two (Chaos Black and White Scar). Every theme swatch is a gradient of its palette (main colour to gold). Flag themes, named subtly for their colours (EXTRA_THEMES: Rainbow, Sky and rose = trans, Dusk = bi, Amethyst = non-binary; keys flag-pride/-trans/-bi/-nonbinary) sit after the factions; swatch and active tab bar show a soft left-to-right gradient, not the full flag (Grant, 21 Oct). Next from the accessibility list, not started: colour-only signals (charts, map), larger tap targets, a screen-reader pass of battle flows. Explainer lines and hint placeholders there removed; saves confirm with a toast. Open play's separate join box merged into Campaigns. The Old World Builder export steps in the import overlay stay as written (Grant wrote them for there).

## WarCastle (Grant, 20 Oct 2026)
- Brief, plan and settled questions in warcastle-brief.md. Steps 1 to 6
  merged (#150 map; #151 moves, seeds, manoeuvre with draggable pieces,
  tables and deployment, allegiances; migration 100 and both seeds run).
  WarCastle (test) has 26 dummies (wc-test-NN@example.com; password from
  Grant); re-run seeds/warcastle-test.sql to reset it.
- A tournament event's entrants are in Set up › Entrants (check-in, lock,
  Start event); Run has no Entrants step. WarCastle can start once all 13
  tables have a scenario (its rounds have no plan of their own).
- WarCastle's starting places are in Set up › Map (Grant, 21 Oct): placed
  any time before the start, even before the lock (the night before).
  Start event needs every army placed, makes round 1's pairings from the
  map, and round 1 is then fixed; moves are in Run from round 2. A table
  with no attack to follow (round 1, or both stayed) is a roll-off: the
  players decide who attacks (deploys first), not the app.
- Tables have no deployment (the attack sets it): Set up › Tables opens the
  builder with no Deployment step (shape 'none', saved deployment null).
- seeds/warcastle-tables.sql: 13 dummy table set-ups ("Dummy N: …") made
  that way: terrain, strategic locations on all, a special feature on 4, 6,
  7 and 13. Run it, then re-run warcastle-test.sql to copy them across.
- Next: Play's drawn table to use the turned deployment; account photos for
  .player-icon; then quests and the trackers once Grant has finalised them.

## Event builder plan (agreed with Grant, 19 Oct 2026)
- PR 1 (done, #96), builder shape: "Great for…" as a bullet on each type box; drop the
  saved-on-device, "choose the type…" and max-players notes; no type ticked
  at the start, numbered steps appear once one is picked; Blank removed, so
  the type sets the format and Format and rules has no format boxes;
  "Story pages"; Story sharing always on (no switch); Alliances step renamed,
  with an on/off switch on Format and rules (step only shows when on);
  Seasons instead of Phases for a League; scenarios as a short list per
  phase with "Add a scenario" instead of the long tick list; tournament
  pairings and points limit on Format and rules, number of rounds on Rounds;
  Invite and open unnumbered, after Create event.
- PR 2, differential scoring for tournaments (Grant to send references).
- PR 3, Square Based Comp with kill point modifiers (Grant to send links).
  The scenario builder already has a Square Based Comp composition option.
- PR 4 (done, #97), campaign points: on/off switch (off ranks by wins, draws, fewest
  losses and hides CP across the app), and custom result types including
  negative points for heavy defeats.
- PR 5 (done, #99), the scenario builder inside the event builder (new scenarios held
  until Create event, saved with the event; needs a migration).

## Admin console plan (tournament organiser; agreed with Grant, 19 Oct 2026)
Tournament tab bar becomes Home · Players · Set up · Run (Campaign tab
dropped for tournaments). PRs, in order where it matters (C before D, F
and E's soft-score entry):
- A, Home (done, #102): setup checklist alone until done or hidden; then a
  tournament card (top 3, current round, battles in progress, round timer;
  tap a tile for its detail); fun stats (models slain, biggest wins,
  baggage, cowards, factions); "Waiting on you" (was "Needs you"), hidden
  when empty. No migration.
- B, Players (done, #103; club field, under-18 flag and SBC tier picker moved to C/F,
  where they're used): invite (join code, link, QR, add a player); players list;
  lists review with per-player status and Checked, 500+ point unit flag;
  players set their Square Based Comp tier on Lists, organiser can correct
  it; lists lock and reveal; check-in on the day with "drop no-shows", then
  Lock entrants; drop out before lock (frees the slot) and withdraw after;
  waiting list (first in line gets a freed slot, notified); player notes;
  club field; under-18 flag. Migration.
- C, Set up, split in two. C1 (done, #104): tab, event details, round cards, battle type.
  C2 (done, #105): scoring, byes, tiebreaks, soft scores, Square Based Comp, club field.
  Not recorded per battle yet, so not offered as tiebreaks: secondary-objective
  VP and Generals slain. Soft score entry and Best Overall standings come in E.
  (was Scenarios): event details (date, start/finish and
  registration times, venue, address, Google Maps link, notes, max players,
  end/delete); normal battles or Battle March chosen in the event builder,
  filtering scenarios and the scenario builder; tournament summary;
  round cards (map, scenario, objectives; select existing or create/edit in
  the scenario builder overlay, editing a library scenario saves a copy;
  x to remove with "Are you sure? This will delete the round."; Add round);
  library link below. Scoring presets: official matched play (6-0, bands by
  points size, from tow.whfb.app), 20-0 (10-10, one step per 250 VP, 20-0 at
  2,500+), win/draw/loss with draw margin, custom. Byes (points; count as
  win, draw or neither). Tiebreaks (default official: total VP, secondary
  VP, Generals slain; also SoS, VP difference, head-to-head; reorderable).
  Final ranking Best General or Best Overall. Round 1 random or seeded;
  random or ranked tables; same-club and same-faction avoidance. Soft
  scores (painting, sportsmanship, favourite army) with weighting into
  Overall. Square Based Comp: editable tier table (extra points, kill point
  modifier: opponent's kill points x modifier), 500-point single unit or
  character limit (not the Arachnarok). Migration.
- D, Finalise and send (done, #106): Finalise is a soft lock (Unlock) and makes a
  player pack .docx; Send to players publishes to Play and notifies; never
  a hard lock, later changes notify players with what changed. Lists can be
  revealed only once lists are locked and set-up is sent. Migration.
  Also: the scenario editor, opened for an event, no longer asks type of
  battle, battle size or comp; they come from the event.
- D2, One scenario maker (done, no migration): Set up › Rounds (Create and
  Edit), the tournament scenario library and the event builder's "Build a new
  scenario" all open Play's scenario builder (openScenarioMaker), with the
  event's type of battle, points and comp fixed. Saved as an ordinary
  missions row, with the builder's own state in missions.terrain.builder, so
  it reopens as drawn and Play sets up the same table. The old form remains
  only for campaign libraries and platform admins' official scenarios.
- D3 (Grant: "any scenario building thing anywhere on Scriptorium should now
  use the scenario builder"): campaign libraries and official scenarios
  (platform admins, Official switch) moved over too, so the old scenario form
  is unreachable; its code (#missionWizard and helpers) can be deleted.
  Event details: rows grouped (The event / Scoring and ranking / Pairings
  and extras), one-line values, an (i) on every row.
  Grant: type of battle, army size and comp are event-wide, never per round.
- E1 (Run, part one; migration 097): tournaments' Events tab is Run, with no
  game nights; Run opens on the tournament (no Scenarios step: that's Set up ›
  Rounds); rounds as swipeable cards with tabs (the round in play holds its
  controls; done rounds show results); a clock with Pause/Resume, +5 and +15
  min, everywhere the timer shows; Results › Score changes (audit trail).
  E2 (done, no migration): Best Overall standings (withBestOverall: each part
  as a share of the best in the field, weighted; soft scores entered by the
  organiser in Run › Results, kept in campaigns.settings.soft_results);
  printing (pairings, table sheets, standings) from a hidden frame; "Remind
  players" on the round in play (notify_event_players, 096, to everyone,
  naming the tables still to report); results picked in Run while offline
  wait in localStorage and send when back online; the battle log is a Run
  step for tournaments (moved from Players).
  To do (Grant, 20 Oct): the awards (best sportsman, best painted, best
  chronicler: campaign_awards and award_votes already exist) should be
  switched on ("checked on") by default rather than added by hand. Not
  doing: per-player reminders ("Remind players" to everyone is enough).
  Not doing: an automatic results deadline (Grant, 20 Oct).
  Phone check of Run done (20 Oct): numbers not ticks on the steps, the
  "what's next" box hidden where it repeats the round card, entrants'
  Withdraw in the ··· menu (asked first), battle log lines without empty
  parts and VP for tournaments, Delete in danger red, Needs your attention
  links to the battle log in Run.
  Rounds reworked (Grant, 20 Oct): the clock sits in the bar at the top
  while a round's played (the round named there only on other steps);
  the round strip is ‹ Round 2 of 3 › arrows (.deck-nav); the tables are
  the card (alternate rows shaded, result under the names), and tapping one
  opens the amend overlay (result-only changes still wait offline); a round
  not started is just its match-ups (two dropdowns and a × each), its
  scenario left to Set up; Print and the rarely used fold away. No Edit
  details in a tournament event's Run (it's in Set up); the status chip
  hides while a round's played. Then (Grant): the timer's − / + 5 min (.wound-btn) and Pause / Resume (before a round, the same − / + sets round_minutes)
  live in the (i) pop-out at the bar's top right; the round switcher sits
  under the card and its ends go on to the steps either side (‹ Entrants,
  Results ›), replacing the step's Back / Next on Rounds. Then (Grant):
  each table opens its score overlay (scores filled in, its battle's
  status and dispute reason shown, a › on the row), so a tournament has
  no Battle log step; disputed / quiet battles in Needs your attention go
  to Rounds. Possible follow-up: saving a disputed table could also settle
  its battle (admin_resolve_game) so it leaves Needs your attention.
  Then (Grant): the score overlay shows each side's VP element by element
  (Units destroyed, plus each objective on for the table's scenario, and
  Other for anything unaccounted), editable, totals live. Needs 099 (PR
  waiting on Grant): stores each battle's breakdown and the organiser's
  corrections (vp_detail). Before 099 / for older battles the whole total
  sits in Other. 099 run (Grant). Then: with Square Based Comp on, each side
  has a Tier picker (set_sbc_tier on save: the army's tier, every battle)
  and "After X's tier (× k)" with the modified total; the modifier stays on
  the whole VP, as the standings apply it (Grant). SBC tiers are A to D (Grant):
  choosing Square Based Comp starts with A, B, C, D (extra 0, × 1, for the
  organiser to fill in), fixed: no adding, removing or renaming. Tiers only show
  anywhere when the comp is Square Based Comp. Saving a disputed table also
  settles its battle (admin_resolve_game: confirmed, result from its
  logger's side), so it leaves Needs your attention; the knockout "result
  is decided" line is gone (Grant).
- Storytelling (Grant, 20 Oct): happy with it as is; two additions, done:
  a formatting toolbar (Bold, Italic, Heading, List, Quote, Photo; Ctrl/⌘+B
  and I) with Write / Preview, and photos: a cover photo picker (was an
  image URL) and photos in the story (uploaded to the organiser's own
  chronicle-photos folder, written as ![photo](story:{uid}/story-{n}.webp)).
  storyBodyHtml renders headings, lists, quotes and photos (own storage only).
- E, Run (was Events): swipeable round cards (start round, timer with
  pause/add time, pairings and swaps, results, amend score, penalties, end
  round); battle log; score audit trail; printables (pairings, table
  sheets, scoresheets, standings); offline results queue; results deadline
  nudges; soft score entry. Game nights screen goes for tournaments (date
  and venue live in Set up). Migration.
- F, Public pages: shareable event page (details, map link, format, points,
  comp, spaces left, scenarios once sent, notes, Join button with code and
  QR); opt-in names on it; opt-in public player profiles (factions, avatar,
  unit photos, awards, events); under-18 never public; per-photo hiding.
  Off until the organiser switches it on. Migration.
- G, Data and export: Delete my account (name becomes "Former player" in
  results); results export for Old World Rankings. Migration.
- Not doing for now: Old World Rankings' Battle March scoring template.
- Campaign/league parity (Grant, 19 Oct: "duplicate what we have here" for
  league and campaign; a round/phase can be a one-day tournament that opens
  the tournament editor inside the campaign, rather than shoe-horning it in;
  storytelling improvements to discuss on 20 Oct):
  - C1 (no migration): nav for campaigns is Home · Players · Set up (Event
    details | Phases | Scenarios) · Run (Phases | Game nights | Tournaments)
    · Story. Phases (a league's seasons) are swipeable cards in Set up (their
    scenarios with drawn maps; add existing, Create scenario in Play's
    builder, Edit, take out; Edit phase, move, delete) and in Run (how it's
    going; Start, Finish with rank perks). Awards moved to Run › Phases.
    Shared helper drawSwipeCards for card strips.
  - C2 (done, no migration): Finalise and send for campaigns: the section sits
    under Set up › Phases; the pack and Play card list phases (seasons) with
    their scenarios and maps, campaign points and Path to Glory; finalising
    locks the phase cards too.
  - C3 (migration 098): a phase can be a tournament day: "Make it a tournament
    day" on its Set up card gives it a tournament of its own
    (tournaments.phase_id); its cards in Set up and Run say so and open the
    tournament editor (Run › Tournaments); a campaign holding any
    tournament shows the Scoring and Pairings cards in Event details.

## Players tab (agreed with Grant, 20 Oct 2026)
- P1 (no migration): the tab is Invite · Players · Alliances (Alliances in
  its own section, not for tournaments). Players is a summary and a button
  (or a search) opening the players overlay: everyone, with filters
  (set up, played this phase, alliance, faction, list status), sort, the
  row menu (View as player lives only there), each player's list (status,
  500+ flags, tier, List checked) and View list (the read-only unit card
  viewer), ticking several, and CSV export of what's shown. Lock and Reveal
  lists moved to Set up (above Finalise and send). Battles in progress and
  the battle log moved to Run (a campaign's Run › Battles; a tournament's
  Battle log step). A tournament's check-in moved to Run › Entrants;
  campaigns and leagues have none.
- P2 (done, no migration): Chart view in the overlay: a measure (battles,
  wins, campaign points, list points, players) across, by faction, alliance
  or player down, as a total or average, of whoever the filters leave;
  hover/focus tooltips; Pin to Home (up to six, everyone counted), with
  Unpin, kept in campaigns.settings.dashboard_charts.
- P3 (no migration): Find a player is a lookup (names drop down as you
  type; the one chosen shows as a card under it, with the same actions);
  "Detail view" opens the overlay. Filters: Faction, then Army type (from
  the list file: Grand Army, or the Army of Infamy / Renegade / Legacy
  composition). Charts: Bars, Columns or Donut (totals only), coloured by
  faction (or alliance) or one colour. Buttons app-wide are ovals, filled,
  with a shadow (secondary a softer fill; never just an outline).
- P4 (no migration): charts over time (By: Week): battles, wins or campaign
  points each week or as a running total, one line or a line per faction or
  alliance (confirmed battles, both sides, from games.played_on; last 26
  weeks; crosshair tooltip). Faction bars of totals are split into their
  army types (Grand Army in the faction's colour, each other in a lighter
  shade, no list palest), unless the army type is filtered to one.
- P5 (no migration): chart data points (chips with × and a + to add:
  Everyone, a player, a faction, an army type in its faction, an alliance;
  each a bar, or a line over time; none = everyone by "By") and a From/To
  date range (battle measures counted from confirmed battles in range).
  Pins keep both.
- Later: game night check-in (ticks for bookings on the night, paid flag;
  needs a column on bookings).

## Conventions (Grant)
- Maps: only ever show the scenario builder's drawn maps (ownDeploymentMap
  with deploymentThumbSvg). Uploaded map images are old, kept for reference
  only, and never shown as a scenario's map.

## Grant's to-dos
- Check Netlify billing/usage; consider turning off deploy previews.

## Decisions waiting on Grant
- Hallowed Ground, Looting & Pillaging and War in the Shadowlands are
  44" x 30" in their own rules, so they're drawn and set up on that table
  (like Battle March), not 72" x 48". Change if you'd rather full size.
- Clash at Sturdham's map labels the hamlet 20" x 18", which can't fit
  between zones 15" apart; it's drawn 20" x 12" as the picture shows.
- Should grudges settle automatically when a battle is confirmed?
- Should award winners be locked once given?

## Backlog
- Merge the duplicate controls listed under "Still to merge" in CLAUDE.md
  (UI components), then delete the old classes. No migration. Also delete
  the unused folder-tab look in the base .tab-btn rules (Grant, 20 Oct: the
  icon bar everywhere, which both phone and wide screens already show).
- Move hosting from Netlify to GitHub Pages (CNAME is already in the repo).
- Team tournaments.
- Player home screen.
- Public events list.
- "See it as a player" preview for organisers.
- Clear stale drafts.
- "Learn to use" overlay.
- Contact Old World Rankings.
- Game night admin booking rows are still busy; tidy them.

## Testing tips
- Unit tests: `for f in tests/*/run.mjs; do node "$f"; done`
- Browser checks: Playwright with Chromium at /opt/pw-browsers/chromium,
  stubbing Supabase. tests/browser/ has a fake Supabase (fake-supabase.mjs,
  an in-memory database) and app.cjs to open the real index.html with a
  world of rows; serve the repo root on 8765, then
  `NODE_PATH=$(npm root -g) node tests/browser/warcastle.cjs`.
