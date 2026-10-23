# Scriptorium

A single-file HTML web app for a 40+ player, three-month
Warhammer: The Old World narrative campaign.

## Architecture
- Everything lives in index.html: HTML, CSS, and JS in one file.
  Keep it that way — do not split into modules.
- Backend is Supabase (auth, database, realtime).
- Six factions, each with its own colour theming.

## Conventions
- British English throughout, sentence case for UI text.
- Use the agreed terms in glossary.md (battle not game, phase not round,
  roster not warband) for any new interface text.
- Accessibility matters: keep ARIA attributes and keyboard
  navigation intact when editing UI.
- No explainer text unless Grant asks for it (Grant, 20 Oct 2026). A
  control's label is enough: no help lines under fields or switches, no
  "this lets you…" notes, no hint-style placeholders, no new (i) info
  buttons. Error messages and the "Are you sure?" on destructive actions
  are still fine. If something seems to need explaining, ask in the PR
  instead of adding text.
- Never expose the Supabase service role key; client uses the
  anon key with row level security.

## UI components (agreed with Grant, 20 Oct 2026)
Reuse these. Do not add a new class for a button, switch, chip, tab, menu
or stepper. If none fits, add a modifier to the nearest one and say why in
the PR. Buttons are filled ovals with a shadow, never just an outline.

Buttons
- Main: `button.act`. Gold in the faction panels, oxblood outside them.
- Secondary: `button.act.btn-secondary` (softer fill).
- Settings row: `button.act.set-act` (a main button placed in a Set up row).
- Small: `.mini-btn`. Danger: `.mini-btn.adm-danger`.
  Round add (+): `.mini-btn.chip-add`.
- Inline in text: `button.link` (e.g. "Forgot password?").
- Help: `.info-btn` (the "i" beside a heading or field).
- Icon only: `.chron-icon-btn` (like, share).
- Plus / minus: `.wound-btn`. The only stepper.
- Previous / next: `.deck-nav`. The only arrows.
- Close (×): `.rules-dialog__close`. The only close button.

Choosers
- Pick one of a few: `.scope-switch` with `role="radio"` buttons (also
  used as section tabs: `.scope-switch.admin-subnav`).
- On/off: `.toggle-switch`, built with `toggleSwitchHtml()`; in a Set up
  row, inside `.set-switch`.
- Pick several: a plain checkbox, or `.scn-chip` pills.
- Removable chips: `.chip` in a `.chip-list`.
- Also kept, one job each: `.theme-swatch`, `.scn-map` (map tiles),
  `.dash-kpi.dash-tile` (stat tiles), `.me-btn`.
- A person (header button, chronicle, list headers): `.faction-emblem`,
  built with `personBadgeHtml()` or `setPersonBadge()`. Give anything that
  shows a person `data-person="{player id}"` and their profile photo fills
  in by itself (WarCastle's `.player-icon` does this too).

Tabs, steps, menus and fields
- Main navigation: the icon tab bar (`.tab-btn` in `#playerTabBar` and
  `#adminNav`), at the bottom on phones and the top on wider screens. The
  old folder-tab look in the base `.tab-btn` rules is retired.
- Steps: `.bf-tabs` step pills. The only step strip.
- "···" menu: `details.battle-menu` with `.battle-menu-item`s.
- Fold-out: `details.admin-section`.
- Search and pick: `.lookup` (combobox and list).
- Fields: the global `input`, `select` and `textarea` styles.

Modifiers: `.wound-btn.is-plus` / `.is-minus` (the + and − drawn),
`.rules-dialog__close.is-back` (a back arrow), and `.on-photo` (dark glass
over a photo, on `.mini-btn`, `.rules-dialog__close` or `.deck-nav`).

Still to merge into the above (then delete the old classes):
`.seg-btn` into `.scope-switch`;
`.t-step` and `.cb-step` into `.bf-tabs`; `details.chron-menu` and
`details.unit-photo-menu` into `.battle-menu`; `details.cat-details` into
`details.admin-section`, which takes the category fold-out's spacing
between arrow and text; the three photo thumbnails (`.media-thumb`,
`.chron-photo-thumb`, `.bc-photo`) into one; `select.status-select` and
`select.lore-select` into `select` with one small size.

## Testing
- Open index.html in a browser to test (or use a local server).

## Before merging (Grant, 23 Oct 2026)
Fixing one thing has broken another more than once. Before any PR is merged,
run all of these and say in the PR that they passed. A failure is fixed, never
skipped or loosened to pass.
- Unit tests: `for f in tests/*/run.mjs; do node "$f"; done`
- Scoring fuzz: `node tests/vp/fuzz.mjs 5000 <any seed>`
- Browser checks (serve the repo root first: `python3 -m http.server 8765`),
  each with `NODE_PATH=$(npm root -g) node <file>`:
  `tests/browser/scoring.cjs`, `tests/browser/sim.cjs 3 <any seed>`,
  `tests/browser/sim-paths.cjs`, `tests/browser/warcastle.cjs`
- Something broke that no check caught? Add a check for it in the same PR.
- One piece of work per PR; anything else found goes in NOTES.md, not the PR.
## Session notes
- Read NOTES.md first: open PRs, pending decisions, backlog and how we work.
  Keep it up to date before ending a session.
