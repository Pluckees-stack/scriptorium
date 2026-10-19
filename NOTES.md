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
- claude/festive-ride-0y0cvh: event builder, round two. Nothing saves until
  Create event on the review step (kept on the device till then); Basics is
  name, dates, then type; tournaments get Rounds (pairings, number of rounds)
  and a scenario per round; Invite and open comes after creating. Needs
  migration 091.

## Grant's to-dos
- Run migrations/091_draft_round_scenarios.sql.
- Run seeds/rules-scenarios.sql (41 official scenarios) if not done.
- Check Netlify billing/usage; consider turning off deploy previews.

## Decisions waiting on Grant
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
