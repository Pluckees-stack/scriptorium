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
- Accessibility matters: keep ARIA attributes and keyboard
  navigation intact when editing UI.
- Never expose the Supabase service role key; client uses the
  anon key with row level security.

## Testing
- Open index.html in a browser to test (or use a local server).