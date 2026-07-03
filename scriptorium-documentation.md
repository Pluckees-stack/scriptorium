# Scriptorium — how it works behind the scenes

This is the reference document for anyone running or maintaining the campaign manager — most likely future you, six weeks into the campaign, trying to remember why something works the way it does.

---

## 1. What this actually is

A single HTML file (`index.html`) that is the entire application: markup, styling, and JavaScript, all in one document. There's no build step, no server code you host yourself, and no separate frontend/backend split. The file talks directly to a [Supabase](https://supabase.com) project over the network — Supabase provides the Postgres database, user authentication, and the API layer, all as a hosted service.

**Why one file.** This was a deliberate choice, not a shortcut. It means the app can be hosted anywhere that serves static files (Netlify Drop, GitHub Pages, or literally just opening the file locally with Supabase keys filled in), with zero deployment pipeline. The trade-off — a large file, harder to navigate than a proper multi-file project — was accepted knowingly, for a campaign tool with one maintainer and a few dozen players. If this ever grows into something bigger (multiple campaigns, a public product), that trade-off should be revisited.

**The two things that make it work:**
- **Supabase project** — your database, your auth, your API keys (the "anon public" key, safe to embed in client code — this is normal for Supabase apps and is what row-level security is for, see §4).
- **Old World Builder's public data** — the app fetches unit rules and spell lists at runtime from the [Old World Builder GitHub repo](https://github.com/nthiebes/old-world-builder), pinned to a specific commit (see §5).

---

## 2. Database schema

### Tables

| Table | Purpose | Owned by |
|---|---|---|
| `factions` | The playable armies (18 seeded, matching Old World Builder) | You (reference data) |
| `alliances` | The teams players fight for on the standings hub | You (reference data) |
| `trait_objectives` | Per-faction campaign objectives | You (reference data) |
| `catalog_units` | Shared unit reference data (scraped statlines, points) | You (reference data) |
| `players` | One row per competitor, linked to their Supabase auth account | Each player, their own row |
| `rosters` | A player's army list, usually one per player, grown over the campaign | Each player, their own rosters |
| `units` | Individual units within a roster — the thing that carries XP, wounds, wargear | Each player, via their rosters |
| `unit_advances` | Dated history of veteran abilities / battle honours a unit has earned | Each player, via their units |
| `games` | One row per logged battle | Each player, their own games |

Campaign totals (glory points, win/loss records) are **never stored** — they're computed live by two database views, `player_standings` and `alliance_standings`, every time the standings screen loads. This means they can never drift out of sync with the underlying game log; there's nothing to accidentally leave stale.

### Migration history

The base schema (all tables above, the two standings views, and the original RLS policies) was created first, in one script. Everything below was added afterwards, in this order, as features were built:

1. `games.opponent_unit_outcomes jsonb` — records which of the opponent's units hit the Battlefield Losses / Death & Dishonour trigger in a given battle, so the defeated player's own app can prompt them to roll.
2. `games.kill_credits jsonb` — records which of your own units get 1 XP for a kill, so a later battle deletion can reverse exactly the right amount.
3. `players.theme text` — the player's chosen colour theme. Originally had a default of `'classic'`; that default was later dropped and existing rows reset to `null`, specifically so the app could tell "never chosen a theme" apart from "deliberately chose the default" and correctly fall back to the player's faction colours.
4. `players.dark_mode boolean default false` — dark mode preference.
5. `players.onboarded boolean default false` — whether the first-time setup wizard has been completed.
6. `players.text_scale text default 'normal'` — accessibility text-size preference.
7. Three functions added for security hardening — not columns, see §4: `increment_unit_xp`, `log_game_with_xp`, `delete_game_with_xp`.

**Don't just trust this list — verify it.** Run this in the SQL editor to see your database's actual current state, which is the real ground truth regardless of what this document says:

```sql
select column_name, data_type, column_default
  from information_schema.columns
 where table_name = 'players'
 order by ordinal_position;
```

---

## 3. Authentication — the username system

Players sign in with a plain username and password. Under the hood, Supabase Auth requires something shaped like an email, so the app silently appends a fake domain — `grant` becomes `grant@seasonofskulls.app`. This email is never sent anywhere and never needs to exist.

**What this buys you:** no real personal data collected, no email verification friction for a friendly campaign, dead simple signup.

**What it costs you:** there is no automated "forgot password" flow, because there's no real inbox behind the address. **You are the password reset mechanism.** If a player forgets their password:

1. Go to your Supabase project → Authentication → Users.
2. Find their account (by the fake email, i.e. their username).
3. Use the "Reset password" option there to set a new one, and pass it to them directly.

**Closing signups once the campaign is full:** Authentication → Providers → Email has a toggle to disable new signups. Flip it once everyone's enrolled, to stop the signup form from accepting new accounts (this doesn't affect existing players signing in).

---

## 4. Security model — what actually protects the data

The app's JavaScript runs entirely in each player's browser. Nothing about the client code itself is "secure" in a meaningful sense — anyone reasonably technical can open their browser's developer console and issue Supabase queries directly, bypassing the UI entirely.

**What actually stops a player from editing someone else's data is Postgres Row Level Security (RLS)**, configured on the database side, not the app side. Every player-owned table has:
- A **read** policy: anyone signed in can see everyone's data (needed for the standings hub and opponent lists).
- An **owner-only write** policy: a player can only insert, update, or delete rows that belong to them, checked via `auth.uid()` matching the row's owner, all the way down through the relationship (a unit's owner is checked via its roster's owner, for instance).

Reference tables (`factions`, `alliances`, `trait_objectives`, `catalog_units`) have read policies only — no write policy at all means nobody except you, via the Supabase dashboard, can change them.

**To verify this is actually switched on**, not just present in a script somewhere:

```sql
-- every row should show true
select relname, relrowsecurity from pg_class
 where relname in ('players','rosters','units','unit_advances','games',
                    'factions','alliances','trait_objectives','catalog_units')
   and relkind = 'r';

-- check the shape of the policies themselves
select tablename, policyname, cmd from pg_policies
 where schemaname = 'public' order by tablename;
```

**What RLS does *not* stop:** a player editing their *own* units — inflating their own XP via the console, for instance. Full protection against that would mean moving game logic into the database entirely and never trusting client-submitted values, which is a much bigger undertaking than suits a friendly campaign tracker. The realistic threat this defends against — one player vandalising another's roster or the standings — is fully covered.

### The three hardening functions

Three database functions exist specifically to close race conditions the original design had. The original pattern for changing a unit's XP was: read the current value in JavaScript, add to it, write it back. If two updates happened close together (a double-click, or two things updating at once), the second write could read stale data and silently overwrite the first.

- **`increment_unit_xp(unit_id, amount)`** — changes XP atomically at the database level (`experience = experience + amount`), so there's no read-then-write gap for a race to happen in. Used for manual XP entry and veteran-roll XP gains.
- **`log_game_with_xp(game)`** — logging a battle and awarding the resulting kill XP happens as a single database transaction. Previously this was insert-the-game, then loop through kill credits awarding XP one network round-trip at a time — if the connection dropped mid-loop, you'd end up with a logged game and half-applied XP.
- **`delete_game_with_xp(game_id)`** — the reverse: deleting a battle and reversing its XP happens together, atomically.

All three run with the same permissions as the calling player (`security invoker`), meaning your existing RLS policies still apply inside them — a player still can't touch anyone else's units through these functions, they just can no longer race against themselves.

---

## 5. The Old World Builder dependency

Two files are fetched at runtime from the Old World Builder GitHub repository: the unit rules index (used for "Full rules" links and statlines) and the spell lists (used for lore selection). Both URLs are **pinned to a specific commit**, not the live `main` branch — this means the app's behaviour can never change underneath you just because that project pushed an update. If either file fails to load (network issue, or the pinned commit somehow becomes unavailable), the app degrades gracefully: rosters, XP, and battle logging all keep working exactly as normal, only the rules-lookup and spell-list features become temporarily unavailable.

**If you ever need to update the pinned version** (say, Old World Builder adds a faction or fixes an error you want reflected here): find the commit you want on GitHub, copy its full 40-character SHA, and replace the SHA in both `RULES_INDEX_URL` and `LORES_WITH_SPELLS_URL` near the top of the script. Test that both URLs actually return data before relying on it — a broken pin fails the same way a network outage does (gracefully), but it's still worth checking deliberately rather than by accident.

---

## 6. How the game logic works

A few systems that aren't obvious just from reading the UI:

**Theming.** Every player can pick a colour theme from the Account panel — either a faction's own colours or a small set of named palettes — plus an independent dark mode toggle and text-size setting. Colours are implemented as CSS custom properties that get rewritten at runtime; dark mode computes a darkened variant of whichever accent is active rather than using one fixed dark palette, so each choice keeps some of its own character even in the dark. If a player has never touched their theme setting, it defaults to their faction's own colours automatically.

**The onboarding wizard.** Triggers for any player whose `onboarded` flag is false — this covers both brand new signups and any existing player who hasn't been through it yet. It collects a display name and faction, offers a live colour preview, and ends by handing off to the normal Import List tab. It's skippable at every step (a "Skip setup" link) specifically so nobody can get stuck on a screen with no way out.

**Path to Glory.** After a battle, units that were reduced below 25% strength, fled, or were destroyed — and that actually have a veteran ability to lose — get flagged with `opponent_unit_outcomes` on the game row. The next time the *defeated* player opens their own app, it reads back the last 20 games where they were the opponent, and prompts them to make their Battlefield Losses or Death & Dishonour roll. Resolution is tracked per-unit so the same prompt doesn't reappear once handled.

**Wizard-only lore.** A unit only shows spell/lore options if it's actually a spellcaster — checked via whether Old World Builder recorded any lore options for that specific unit at import time, not just whether its faction has an exclusive lore available. (This was a real bug earlier in development — a faction having a lore doesn't mean every character in it can cast.)

**VP scoring.** Computed from the opponent's unit outcomes: destroyed counts full value, fled counts half, reduced-below-25% counts a quarter, with bonuses for killing the enemy general or capturing standards. This lives entirely in the client and isn't currently something a scenario or Trait Objective can override — worth knowing before designing custom scenarios that need different scoring.

---

## 7. Known limitations — deliberate, not accidental

Worth understanding these rather than being surprised by them later:

- **Double-logged battles.** If both players in a game log it independently, it counts twice in the standings. Nothing currently prevents this — it was left as an open design decision. Options if it becomes a real problem: trust players to only log once each (simplest), add a uniqueness constraint on the combination of both players and date, or add an opponent-confirmation step so only one row per battle is ever counted.
- **JSON storage for battle-specific data.** `opponent_unit_outcomes` and `kill_credits` are stored as JSON blobs rather than proper relational rows. This means you can't easily run a query like "who's killed the most units across the whole campaign" — that data is trapped inside individual game records. Fine at this scale; would need restructuring if the campaign tracker ever needed cross-campaign statistics.
- **Verbose error messages.** Error messages shown to players include the raw database error text, not a sanitised generic message. This was a deliberate choice for a small trusted campaign — those exact error messages have already caught several real bugs during development that a generic "something went wrong" would have hidden. Worth revisiting if this were ever opened to the public.
- **Single HTML file.** Covered in §1 — accepted trade-off for this project's size, not built to scale indefinitely.

---

## 8. Quick TO reference

| I need to... | Do this |
|---|---|
| Reset someone's password | Supabase → Authentication → Users → find them → Reset password |
| Stop new signups | Supabase → Authentication → Providers → Email → disable signups |
| Add or edit an alliance | Insert/update a row in the `alliances` table directly (no admin screen exists yet) |
| Add or edit a Trait Objective | Insert/update a row in `trait_objectives`, linked to a `faction_id` |
| Check RLS is actually on | Run the query in §4 |
| See a player's actual current theme/settings | `select * from players where display_name = '...'` |
| Update the Old World Builder data pin | See §5 |
| Something's broken and a player sent a screenshot with an error message | The error text itself usually names the problem directly (a missing column, a permissions error) — it's shown deliberately, see §7 |

---

## 9. Design system

Not obvious from reading the CSS cold, so worth stating the intent directly.

**Typography**, three fonts, each with a specific role:
- **Old London** (display headings, e.g. "Scriptorium" itself) — a genuine freeware blackletter font, not a Google Font, so it's embedded directly in the HTML as base64. If it's ever missing after an edit, check the `@font-face` block near the top of the `<style>` section.
- **EB Garamond** (small-caps labels, tab names, the "Vol 1: The Season of Skulls" wordmark, category headers) — Google Font.
- **Newsreader** (all body text) — Google Font.

**Palette**: deliberately cool-toned, not warm parchment — ink, ground, parchment, and parchment-edge are all desaturated greys rather than browns. Every faction gets its own accent pair (an oxblood-equivalent and a gold-equivalent), layered on top of that neutral base. The six old "named palettes" (Classic, Ember & Ash, etc.) were removed on request — factions are now the only selectable accent source, with one internal-only fallback (`DEFAULT_BASE` in the script) for anyone without a faction set yet.

**Background**: ink blots, not the watercolor wash from earlier in development — hard-edged pooled blots plus scattered spatter dots along the bottom of the page, built from layered CSS gradients mixed with the active theme colour via `color-mix()`, so they're already theme-reactive. The user is planning to hand-paint real blot shapes to replace these — needed format: solid single colour (any colour, it'll be used as a mask) on a transparent background, SVG preferred, either one bottom strip or several separate blots for more placement flexibility.

**The "boxes = interactive" pattern**: branding and non-interactive text (the masthead, headings) sit directly on the page background, fully transparent, no box. Anything genuinely interactive — the login form, every tab's content — sits in a bold, roughly 90%-opaque solid-colour box in the active accent colour, with off-white text, a backdrop blur so the page texture still shows faintly through, and a drop shadow. This is a deliberate signal: if it's boxed, you can interact with it; if it's not, it's just information.

**Accordions**: Muster List and Game View categories (Characters, Core, etc.) are collapsible, closed by default, state persists across re-renders. Opening one triggers a staggered cascade of its unit rows — this is re-triggered on every open, not just the first, and is scoped to that specific accordion so ticking XP elsewhere never replays it.

**Motion**: entrances generally run 0.3–0.7s; closes are deliberately faster than opens for the same element, to feel like a consistent physical motion rather than a mirrored one. Tab switches stagger their top-level sections in one after another rather than revealing everything at once.

**Accessibility**: text contrast has been actively measured (not eyeballed) across all themes and factions using proper WCAG maths, including correctly compositing semi-transparent colours rather than treating them in isolation — worth being careful about if extending the palette further, since that's an easy mistake to make. Text size is user-configurable from the Account panel. Touch targets follow the 44px minimum guideline.

---

## 10. Current status and open backlog

**Done and verified as of this document:**
- Full visual identity — theming, typography, the bold-box interaction pattern, ink-blot backgrounds, animations.
- First-time onboarding wizard.
- Security hardening — RLS confirmed live and correctly shaped on every table; atomic XP functions written and wired into all four call sites; Old World Builder URLs pinned to a fixed commit.

**Still open:**
- **Mission/scenario content** — the Game View "Mission" stage is an empty placeholder waiting on your actual scenario designs. Scenario-specific VP scoring hangs off this too; currently VP is generic (destroyed/fled/below-25%, general/standard bonuses) with no way for a scenario to override it.
- **Faction-exclusive lore map** — only 4 of the 18 factions are confirmed against real book data (from Old World Builder's own per-unit data); the rest are name-matched guesses and should be checked against the actual army books.
- **Faction accent colours** — all 18 are Claude's judgement calls, not sourced from anything official. Worth a skim; Lizardmen was already corrected once for being too close to Wood Elves.
- **Alliances and Trait Objectives** — need confirming as actually seeded in the database. Both are admin-write-only reference tables (see §4), so nothing appears in the standings or the trait dropdown until rows exist.
- **No admin/TO screen** — managing alliances, trait objectives, and players currently means writing SQL directly. Flagged as a wanted feature, not yet built.
- **Double-logged battles** — still an open design decision, not a bug (see §7).
- **Influence Points / phase-based standings** — mentioned in early campaign design discussions but not implemented in the app. Needs a decision: intentionally out of scope for this tool, or a real gap to plan for.

