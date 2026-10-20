# WarCastle — working brief

A one-off event, run inside Scriptorium. This file is the running brief:
what's decided, the build plan, and what's still open. Nothing here is built
on `main` yet. The October build on branch `warcastle-map-movement` used an
older map and pre-dates the tournament rebuild (#102 onwards), so it is a
source of ideas and code to port, not something to merge.

## What WarCastle is (Grant, 20 Oct 2026)

- **A map game.** Players move pieces on the Fortenhaf map each round.
  The area they move into is the table they play on.
- **The direction they arrive from matters.** Which crossing an army came
  through sets where it deploys on that table.
- **Each table has its own pre-made set-up.**
- **Each player has their own set of objectives** and tracks them.
- So each round: move the pieces, push each player their scenario and
  deployment, and let them track their personal objectives.

## The map

`assets/warcastle/fortenhaf-map.webp` (2000×1333). 13 numbered areas.
An army can only cross a border at a dotted crossing; there are 25:

| | Between | | Between | | Between |
|---|---|---|---|---|---|
| A | 1 – 3 | J | 3 – 4 | S | 2 – 12 |
| B | 1 – 2 | K | 9 – 10 | T | 2 – 13 |
| C | 1 – 9 | L | 9 – 11 | U | 12 – 13 |
| D | 2 – 7 | M | 9 – 13 | V | 12 – 11 |
| E | 2 – 8 | N | 4 – 10 | W | 12 – 6 |
| F | 7 – 8 | O | 10 – 11 | X | 11 – 6 |
| G | 7 – 9 | P | 11 – 13 | Y | 5 – 6 |
| H | 8 – 9 | Q | 10 – 5 | | |
| I | 3 – 9 | R | 11 – 5 | | |

Read from the map by Claude; Grant to confirm. Area 9 wraps round the west
of 7 and 8 up to the river, and area 11 includes the wooded strip between
13 and the mountains up to 12.

## Two instances

Both are ordinary campaigns (tournament format, tournament format
`warcastle`), so each is sealed off from Season of Skulls and from each other
by the existing row level security.

1. **WarCastle**, the real one. Real players join with the join link as usual.
2. **WarCastle (test)**, the same set-up with dummy players, for rehearsing
   the day and testing every PR before it touches the real one.

How the test one works:
- **Dummy players are real, synthetic logins** (players rows must belong to
  a Supabase account). A seed, `seeds/warcastle-test.sql`, run by Grant in
  the SQL editor, creates them (e.g. `wc-test-01` … `wc-test-26`, one known
  password), gives each a faction and a roster, and enters them.
- **Grant can sign in as any dummy** on a second phone to see the player
  side, and use Run as the organiser on the first.
- **The seed copies the real event's set-up** (table set-ups and personal
  objectives) into the test campaign, so it is built once, in the real event,
  hidden from players until "Send to players".
- **Re-running the seed resets the test event** to round 1, empty.
- Dummy accounts and the test campaign are left out of anything
  platform-wide (finding players, records, leaderboards).

## Build plan

Each step is one PR. Steps 2 and 3 need migrations; the rest are front end.

1. **The map** (no migration). The new map in `index.html`: areas,
   crossings, pinch-zoom on phones, tap an area for who's there and its
   set-up. Read-only, showing where armies are.
2. **Positions and moves** (migration, replacing the unrun `069`). Where
   each army stands, and each round's moves, with the crossing used. The
   round's pairings come from the positions: the armies in an area play on
   its table. The app flags illegal moves (no crossing, too far, area full).
3. **The test instance** (seed). `seeds/warcastle.sql` creates the real
   event with Grant as organiser; `seeds/warcastle-test.sql` creates the
   test one with dummies. From here on every PR is tried in the test event.
4. **Table set-ups by crossing.** Each area gets its pre-made set-up from
   the scenario builder, with a deployment for each crossing into it. When a
   round goes live, each player is sent their table, opponent, scenario and
   deployment, straight into Play.
5. **Personal objectives.** Each player's own objectives, visible only to
   them (and the organiser), ticked off during or after the battle, and
   counted in standings if they score.
6. **Organiser console for the day.** Run, reshaped round the map: enter or
   approve moves, see who's still to move, start the round, chase results.
7. **Optional, from the old branch:** the corruption and Waaagh! trackers,
   special features scoring on even rounds, round briefings.

## Open questions

1. **Are the 25 crossings above right?** (Picture sent in the session.)
2. **Who moves the pieces?** Players send their move from their phone and
   the organiser locks the round, or the organiser enters every move?
   If players: do they move one at a time, in result order (winners first,
   as on the old branch), or all at once with clashes resolved after?
3. **How many armies, and how many per area?** The old plan was 26 armies,
   two per area, about 6 rounds. What happens if three end up in one area,
   or one is left alone?
4. **How far can an army move?** One crossing per round? Can it stay put?
5. **Deployment by crossing:** if both armies came in through the same
   crossing, or one stayed put, where does each deploy?
6. **Do crossings differ?** The borders are coloured (river, forest,
   manor walls, mountains, open ground). Does that change anything?
7. **Personal objectives:** written by you per player, or drawn from a
   pool? Secret from opponents? Do they score points, and how is the
   overall winner decided?
8. **Are the corruption and Waaagh! trackers still part of it?**
