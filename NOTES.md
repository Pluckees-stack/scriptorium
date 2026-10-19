# Working notes

Read this at the start of each session. Update it before ending one.

## How we work
- Work on a branch, push it and open a PR. Merge only when Grant says "merge".
- Grant runs SQL migrations and seeds himself. Mark each migration "Run" in
  migrations/README.md once he confirms.
- Keep sessions short: one piece of work per session, then update this file.
- Avoid parallel agents and heavy screenshot checks unless asked; they use a
  lot of tokens.

## Open PRs
- None. #99 (scenario builder in the event builder, PR 5) merged. Next: admin console clean-up (plan to be agreed with Grant).
- #98 (rules scenarios drawn exactly, seed re-run) merged.
- Scenario editor Map step (branch claude/kind-goldberg-4g6mzt): a rules
  scenario shows its drawn map once (in the preview on wide screens, in the
  step on phones) instead of blank image tiles.

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
