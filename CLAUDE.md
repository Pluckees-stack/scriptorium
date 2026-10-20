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

Tabs, steps, menus and fields
- Main navigation: the tab bar (`.tab-btn`), drawn as the icon bar. The old
  folder-tab look is retired; don't build on it.
- Steps: `.bf-tabs` step pills. The only step strip.
- "···" menu: `details.battle-menu` with `.battle-menu-item`s.
- Fold-out: `details.admin-section`.
- Search and pick: `.lookup` (combobox and list).
- Fields: the global `input`, `select` and `textarea` styles.

Still to merge into the above (one PR, then delete the old classes):
`.chron-follow` and `.photo-toggle` into `.mini-btn`; `.stepper-btn`
(dropped) and `.ue-step` into `.wound-btn`; `.chron-nav` into
`.deck-nav`; `.chron-bar-btn`, `.setup-round-x`, `.chron-prompt-x`,
`.media-viewer-close` and `.chron-preview-remove` into the close button
(a modifier for over a photo); `.seg-btn` into `.scope-switch`;
`.t-step` and `.cb-step` into `.bf-tabs`; `details.chron-menu` and
`details.unit-photo-menu` into `.battle-menu`; `details.cat-details` into
`details.admin-section`, which takes the category fold-out's spacing
between arrow and text; the three photo thumbnails (`.media-thumb`,
`.chron-photo-thumb`, `.bc-photo`) into one; `select.status-select` and
`select.lore-select` into `select` with one small size.

## Testing
- Open index.html in a browser to test (or use a local server).
## Session notes
- Read NOTES.md first: open PRs, pending decisions, backlog and how we work.
  Keep it up to date before ending a session.
