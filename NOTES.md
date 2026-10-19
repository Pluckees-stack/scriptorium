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
- Rules scenarios drawn exactly (branch claude/kind-goldberg-4g6mzt): the
  29 scenarios that used an approximate map and the rules' image now have
  their own builder maps (zones, featured terrain, markers, carts), the
  images and "approximation" text are gone, descriptions are just the
  source ("Book - Scenario # - Name"), and a scenario with nothing placed
  on its map starts with random terrain ("Terrain placement randomised").
  Needs seeds/rules-scenarios.sql re-run.

## Grant's to-dos
- Re-run seeds/rules-scenarios.sql (41 official scenarios): updates the
  descriptions and maps, and deletes the rules' map images it added before.
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
- Differential scoring for tournaments (20-0, 19-1, 18-2... a round).
- Team tournaments.
- Build a new scenario from inside the event builder (for now: Scenarios tab
  once the event exists).
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
