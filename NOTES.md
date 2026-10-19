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
- #88 Players run tournaments (long campaigns stay with platform admins).
  After merging, Grant runs migrations/089_players_run_tournaments.sql.
- #93 Admin console clean-up: every add/change is a button that opens
  swipeable cards (the `openFlow` component, styled like the scenario builder).

## Grant's to-dos
- Run seeds/rules-scenarios.sql (41 official scenarios) if not done.
- Check Netlify billing/usage; consider turning off deploy previews.

## Decisions waiting on Grant
- Should grudges settle automatically when a battle is confirmed?
- Should award winners be locked once given?

## Backlog
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
