# Roadmap — working brief

Grant's change list, with each item read against what the code already does.
For each item: what it probably means, what already exists, and what needs
answering before it can be built. Answer questions in any order — rough notes
are fine. Size is a rough guide: **S** an evening, **M** a few sessions,
**L** a project in its own right.

## Shared building blocks

Several items share a common piece. Build that piece once and the items
built on it each get smaller.

| Building block | Items it unlocks |
|---|---|
| **Mobile-first layout pass** | Mobile first, tabs, dropdowns, checkboxes, switches, smoothness, swipeable sheets |
| **Image upload pipeline** (storage bucket, access rules, shrinking images on the phone before upload) | Art upload, photo sharing, unit art, lore images, alliance emblems |
| **Roll tables** (organiser-defined d6/2d6 tables, rolled with an animation) | Dice rolling, random encounters, weather, winds of magic |
| **Campaign map** (already built for WarCastle on branch `warcastle-map-movement`) | Map interface, map pushes scenarios |
| **Player preferences** (per-account settings) | Effects on/off, intro overlay "don't show again", 2FA status |

---

## UI changes

**1. Smoother UI across the board — M**
Most screens are rebuilt from scratch each time something changes, which
causes flicker, lost scroll position and "Reading…" flashes. Fixes: update
only the parts that change, add short transitions, and show placeholder
outlines instead of loading text.
- *Question:* which screens feel worst? A top three would give us a starting point.

**2. Slimmer dropdowns — S**
Reduce the padding and height on dropdowns everywhere. A pure CSS change.

**3. Bigger checkboxes — S**
Checkboxes are currently browser-default size (e.g. the spell picker). Size
them up to about 22px with faction-coloured ticks, and make the whole row
tappable.

**4. Remove skull switches — S**
The `.skull-switch` (a toggle whose thumb is a skull) is used for the campaign
settings toggles.
- *Question:* replace them with a plain on/off switch, or ordinary checkboxes?

**5. Full-screen effects when a game begins, with an on/off switch — M**
A game-start overlay already exists (`gameEntryOverlay`, the battle-narration
text). This would make it a proper full-screen moment, such as an ink wash,
the faction banner or the opponent's name. Switching effects off is already
automatic for anyone whose phone is set to reduce motion. The new switch
would sit in Account settings.
- *Question:* should the switch be per device, or follow your account across devices?
- *Question:* just the game start, or other moments too (unit destroyed,
  victory, round going live)?

**6. Move the tabs inline with the Scriptorium title — M**
At the moment the title sits in the header, with the tab bar on its own row
underneath. On desktop the tabs would move into the header row. On a phone
there isn't room, which is where mobile first comes in (see 8).
- *Question:* is this mainly a desktop request? On phones the natural
  equivalent is a bottom tab bar.

**7. Full-screen animated dice rolling — M**
- *Question:* is this a dice roller players use at the table (roll 10 dice,
  see the results big), an animation for rolls the app makes itself
  (encounters, weather, winds), or both? Building the animation once covers both.

**8. Mobile first — L, and it should come first**
The CSS is written for desktop and squeezed down for phones (overrides at
640px). Going mobile first means designing for phones first:
- a bottom tab bar
- tap targets at least 44px
- the Game view usable one-handed
- desktop as the enhancement

This underpins 1, 2, 3, 6 and 9, so it's the natural first big project.

**9. Swipeable unit sheets, with art — M (L with art)**
In Game view, swipe left and right between unit cards. This is doable with
plain CSS and no library.
- *Question:* where does the art come from? Games Workshop's art can't be
  reused, so the realistic options are photos of players' own models (needs
  the upload pipeline) or a small set of generic artwork per unit type
  chosen by the organiser.

**10. Social feature: upload photos and share to Instagram — M**
Websites can't post to Instagram directly. On phones the share button can
hand an image to Instagram through the phone's share menu, which works well.
- *Question:* is this a campaign photo gallery players can browse, a
  generated "battle report" card (both armies, result, a photo) to share,
  or both?

**11. Improve security — M**
Already reviewed; four issues, two of them serious:
- players can edit their own games after logging them
- anyone can look up players' real email addresses
- helper functions are probably callable directly
- `set-my-email` doesn't confirm the address

The fixes are written up in the earlier review.
- *Note:* the WarCastle branch already uses migration number **069**, so the
  security migration should be **070**.

**12. Two-factor authentication — M**
Supabase supports authenticator-app codes for free. This needs a sign-up
screen with a QR code, a code prompt at login, and a recovery path.
- *Question:* optional for everyone, required for organisers and admins, or
  both? Making it required for admins would also protect the admin-only
  functions.

**13. "Learn to play" overlay — M to L, mostly writing the content**
- *Question:* teaching the Old World rules (a large content job; the app
  already links to the online rules at tow.whfb.app), or a guided first
  game that walks through one battle in Game view? Who writes the content?

**14. "How to use Scriptorium" intro overlay — M**
A first-visit tour that steps through each tab with a highlight and a line
of text, with "skip" and "don't show again".
- *Question:* separate tours for players and organisers? The admin side
  needs one more.

**15. Standardise language across the app — S to M**
The house style is British English and sentence case, but the tab labels
mix styles ("Player Rosters", "Tournament Admin" and "Scenario Admin"
alongside "Muster list"). The code also says "mission" where the interface
says "scenario", and older docs still say "glory" where the app now says
"campaign points". The first step is a glossary of agreed terms, then one
pass through the app.
- *Question:* any terms you want to change (e.g. "Muster list", "Game view")?

**16. Lore drafting — size depends on the answer**
Narrative pages already exist (Narrative admin, with bold and italic).
- *Question:* which of these?
  - a better editor (headings, images, drafts, scheduled publishing)
  - players writing lore for their own army
  - AI help with drafting

**17. Art upload — M (it's the upload pipeline)**
- *Question:* art for what? Unit sheets, player or army banners, narrative
  pages, alliance emblems (currently entered as a web address)? Probably
  all of them, which is why it's worth building once.

**18. WarCastle one-off — on a branch, not live yet**
`warcastle-brief.md` holds the brief. The branch `warcastle-map-movement`
already has:
- the overworld map and movement rules
- the corruption and Waaagh! trackers
- round briefings pushed to players

It needs migration 069 run, a test, and answers to the brief's remaining
open questions.

**19. Tidy the Old World Builder update branches — S**
The nightly update check has created a new `owb-update-2026MMDD` branch
every day (about 20 so far). Change it to reuse one branch, and delete the
old ones.

---

## Campaign features

**20. Scenario builder — size depends on the answer**
Scenario admin already exists, with objectives, VP values, custom
objectives, special rules and deployment maps.
- *Question:* what's missing? A visual builder for drawing deployment zones
  and terrain on a map, letting players build scenarios, or something else?

**21. Map interface — M to L (reuses the WarCastle map)**
The WarCastle branch has a map with areas, neighbours, movement and
tap-for-detail.
- *Question:* what do players *do* on the campaign map? Claim territory,
  move armies, choose who to attack? Does the map decide pairings, or just
  show the state of the campaign?

**22. Map pushes scenarios to players — S to M once 21 exists**
The WarCastle branch already pops up a round's scenario briefing when the
round goes live. For the campaign version, each area would carry a
scenario, so attacking an area puts that scenario in front of both players.

**23. Battalion manager — unclear**
- *Question:* what's a battalion here? Possibilities include:
  - a group of units within a roster
  - several separate armies per player (e.g. for moving around the map)
  - a team of players fighting together

**24. Build lists inside Scriptorium — L**
Today lists are built in Old World Builder and imported. The app already
loads Old World Builder's unit data and has the points pricing, so an
in-app builder is possible, but it's large: every option, magic item and
rule has to be right.
- *Question:* is the pain building lists, or keeping them up to date during
  the campaign (adding units between games)? If it's the second, a "grow
  your roster" editor is much smaller than a full builder.

**25. Manage character, core, special, etc. — tied to 24**
Units already carry their category.
- *Question:* is this about list-building limits (e.g. maximum percentage of
  points on characters), or about organising and managing a growing roster
  by category?

**26. Random encounters — M (uses roll tables)**
- *Question:* when do they happen? Before a game, when moving on the map,
  between rounds? Do they change the game (a rule for the battle) or just
  the story?

**27. Weather effects — S once roll tables exist**
Rolled per game or per round on an organiser's table, with the result shown
in Game view alongside the scenario.
- *Question:* per game, or one weather for the whole round?

**28. Winds of magic and their impact, with channelling — S to M**
- *Question:* is this a house rule, e.g. a "winds" strength rolled each
  round that adjusts casting, with channelling switched on or off? Spell
  out the rule and the app can roll it, show it in Game view and the spell
  list, and keep a history.

**29. Messages for allies and neutral players — M to L**
Alliances are currently just teams. They have no "ally / neutral / enemy"
relationship.
- *Question:* who counts as neutral? Does this need relationships between
  alliances (set by the organiser, perhaps changeable as diplomacy)?
- *Question:* a direct message, a message board per alliance, or both?
  Should enemies ever see intercepted messages? That could be fun.
- *Note:* the app has no live updates today (it checks for changes every
  so often), so chat would either use Supabase's live updates or feel a
  bit laggy.

---

## Suggested order

1. **Groundwork** (low risk, mostly quick): security fixes (070), language
   pass (15), Old World Builder branch tidy (19), 2FA (12).
2. **Mobile-first pass**: 8, with 1 to 4 and 6 folded in.
3. **Feel**: game-start effects and switch (5), dice (7), intro tour (14).
4. **Pictures**: upload pipeline, then art (17), swipeable sheets (9),
   photos and sharing (10).
5. **Campaign systems**: roll tables, then weather (27), encounters (26) and
   winds (28). Merge the map (18), then the campaign map and scenario push
   (21, 22). Messaging (29).
6. **Big bets, needing answers first**: list builder and roster categories
   (24, 25), battalions (23), learn to play (13), scenario builder (20),
   lore (16).
