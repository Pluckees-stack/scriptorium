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
- Admin console PR B (Players), branch claude/festive-ride-0y0cvh. Needs migration 093. PR A merged (#102).
- #98 (rules scenarios drawn exactly, seed re-run) merged.
- #100 (scenario editor shows a rules scenario's drawn map once) merged.
- #101 (Play shows the set-up table under the scenario picker, "Edit set-up") merged.

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
- B, Players (open; club field, under-18 flag and SBC tier picker moved to C/F,
  where they're used): invite (join code, link, QR, add a player); players list;
  lists review with per-player status and Checked, 500+ point unit flag;
  players set their Square Based Comp tier on Lists, organiser can correct
  it; lists lock and reveal; check-in on the day with "drop no-shows", then
  Lock entrants; drop out before lock (frees the slot) and withdraw after;
  waiting list (first in line gets a freed slot, notified); player notes;
  club field; under-18 flag. Migration.
- C, Set up (was Scenarios): event details (date, start/finish and
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
- D, Finalise and send: Finalise is a soft lock (Unlock) and makes a
  player pack .docx; Send to players publishes to Play and notifies; never
  a hard lock, later changes notify players with what changed. Lists can be
  revealed only once lists are locked and set-up is sent. Migration.
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
- Later: the same Set up treatment for campaigns (phases/seasons as cards,
  finalise and send).

## Grant's to-dos
- Run migrations/093_players_admin.sql.
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
  stubbing Supabase.
