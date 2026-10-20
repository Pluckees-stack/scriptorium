# WarCastle — working brief

A two-day narrative event for 26 players, run inside Scriptorium. This file
is the running brief: what's decided, the build plan, and what's still open.
Nothing here is built on `main` yet. The October build on branch
`warcastle-map-movement` used an older map and pre-dates the tournament
rebuild (#102 onwards), so it is a source of code to port, not to merge.

## How the event runs (Grant, 20 Oct 2026)

A contested province of Ostermark near Fortenhaf and the Kislev border. At
its heart, in Moller's Field, sits a giant shard of Morrslieb.

**A physical map on a table.** Players move their own pieces on it. The
organiser mirrors each move live on the map in the admin console. Players
see the map on their phones but can't move anything there.

**Six rounds.** The organiser places everyone for round 1, which goes
straight to battle. Then five full turns, each:

1. **Town crier.** News: changes in the balance of power, new alliances,
   spectacular battles, the Winds of Magic.
2. **Diplomacy.** 15 minutes to negotiate. Players tell the organiser if
   they form, change or break an allegiance, or turn neutral. Fighting an
   ally breaks the allegiance automatically.
3. **Manoeuvre.** Each army moves to an adjacent area, or stays:
   - winners may stay or move;
   - draws must move;
   - losers must move, unless their last opponent left the area.

   Order: all winners, then all draws, then all losers; within each, by
   faction group, each group at once:
   1. Elves (High, Wood, Dark)
   2. Skaven
   3. Chaos: Warriors, Daemons, Beastmen (not Chaos Dwarfs)
   4. Humans: Empire, Bretonnia, Cathay, Kislev
   5. Orcs, Lizardmen and Ogres
   6. Undead: Tomb Kings, Vampire Counts
   7. Dwarfs, with Chaos Dwarfs

   The organiser settles anything left over (armies with no opponent,
   ties): "good" factions usually win ties, or roll for it.
4. **Battle.** The armies in each area play on its table.
5. **Resolve.** Results are logged in Scriptorium as usual. Losers must
   leave the area; winners may stay or move.

**Deployment** (player pack, `Player_Pack.pdf`):
- The **attacker** is always the army that moved into the area last; the
  **defender** is the one already there. In round 1 (everyone placed by
  the organiser) the two players roll off.
- The attacker's zone is set by the **direction they came from**: North,
  South, East, West (long or short edge strips, 24" deep on the short
  edges), or North-East, North-West, South-East, South-West (diagonal
  wedges).
- **Ambush:** a winner who stayed in their area may declare an ambush on
  the army moving in. The defender deploys on both long edges; the
  attacker in a central strip running in from the short edge on the side
  it arrived from, with its baggage train (BT) at that edge.
- **The deployments are the existing ones, turned to fit** (Grant): the
  same zones, with the angle and sides switched to match the direction of
  attack.
- **13 physical tables, one per area**, each built in the scenario builder
  (terrain and table objectives). Its deployment is not fixed: it changes
  with each battle's movement, and updates on the fly if the organiser
  changes a move.

**Two kinds of objective** (still being finalised):
- **Quests**, one set per player, unique and secret. A player may have
  more than one, and the organiser can change them mid-event. They score
  points, and may be an end-of-event state rather than done in one battle.
- **Table objectives**, on the tabletop: strategic objectives, special
  features, domination and so on. They differ from table to table and are
  built into each table's scenario.

**Trackers.** Chaos corruption and Waaagh! energy stay in, still being
finalised. Opposing alliances can push them down as well as up.

## The map

`assets/warcastle/fortenhaf-map.webp` (2000×1333). 13 areas in five regions,
told apart by the colour of their borders (colour has no other effect):

| Region | Areas |
|---|---|
| River | 1, 2 |
| Woodlands | 3, 4 |
| Town (Fortenhaf) | 7, 8 |
| Mountains | 5, 6 |
| Plains (Moller's Field and the shard: 13) | 9, 10, 11, 12, 13 |

(Grant confirmed the directions below, 20 Oct; the tables have their north
edges marked.)

An army can only cross a border at a dotted crossing. There are 25 (Grant
confirmed, 20 Oct), and never more than one between two areas, so a move is
fully described by where it starts and ends. **Attacker came from** is the
direction of travel, so it picks the deployment; worked out from the map by
Claude, confirmed by Grant:

| | Move | Attacker came from | Move | Attacker came from |
|---|---|---|---|---|
| A | 1 → 3 | North-East | 3 → 1 | South-West |
| B | 1 → 2 | West | 2 → 1 | East |
| C | 1 → 9 | North-West | 9 → 1 | South-East |
| D | 2 → 7 | North-East | 7 → 2 | South-West |
| E | 2 → 8 | North | 8 → 2 | South |
| F | 7 → 8 | West | 8 → 7 | East |
| G | 7 → 9 | North | 9 → 7 | South |
| H | 8 → 9 | North-East | 9 → 8 | South-West |
| I | 3 → 9 | West | 9 → 3 | East |
| J | 3 → 4 | North | 4 → 3 | South |
| K | 9 → 10 | North | 10 → 9 | South |
| L | 9 → 11 | North-West | 11 → 9 | South-East |
| M | 9 → 13 | West | 13 → 9 | East |
| N | 4 → 10 | West | 10 → 4 | East |
| O | 10 → 11 | South-West | 11 → 10 | North-East |
| P | 11 → 13 | South-West | 13 → 11 | North-East |
| Q | 10 → 5 | West | 5 → 10 | East |
| R | 11 → 5 | North-West | 5 → 11 | South-East |
| S | 2 → 12 | West | 12 → 2 | East |
| T | 2 → 13 | North-West | 13 → 2 | South-East |
| U | 12 → 13 | North-East | 13 → 12 | South-West |
| V | 12 → 11 | North-East | 11 → 12 | South-West |
| W | 12 → 6 | North | 6 → 12 | South |
| X | 11 → 6 | West | 6 → 11 | East |
| Y | 5 → 6 | South-West | 6 → 5 | North-East |

Area 9 wraps round the west of 7 and 8 up to the river. Area 11 includes the
wooded strip between 13 and the mountains, up to 12.

## Two instances

Both are ordinary campaigns (tournament format, tournament format
`warcastle`), so each is sealed off from Season of Skulls and from each
other by the existing row level security.

1. **WarCastle**, the real one. Real players join with the join link.
2. **WarCastle (test)**, the same set-up with 26 dummy players, for
   rehearsing the day and trying every PR before the real one.

How the test one works:
- **Dummy players are real, synthetic logins** (players rows must belong to
  a Supabase account). A seed, `seeds/warcastle-test.sql`, run by Grant in
  the SQL editor, creates them (`wc-test-01` … `wc-test-26`, one known
  password), with factions spread across every movement group, a roster
  each, and enters them.
- **Grant can sign in as any dummy** on a second phone to see the player
  side, and run the event as organiser on the first.
- **The seed copies the real event's set-up** (the 13 tables, quests),
  so it is built once, in the real event, hidden from players until "Send
  to players".
- **Re-running the seed resets the test event** to before round 1.
- Dummy accounts and the test campaign are left out of anything
  platform-wide (finding players, records, leaderboards).

## Build plan

One PR each where possible. Steps 1 to 6 are built; 7 and 8 wait for the
quests and trackers to be finalised.

1. **The map** (built, merged in #150). Areas, regions, crossings and
   directions in `index.html`; zoomable on phones; tap an area for who's
   there, its table and its crossings. Players see it on the Standings tab
   (labelled Map), the organiser as a Map step in Run. Shown for an event
   whose `campaigns.settings.template` is `'warcastle'`.
2. **Positions and moves** (built, migration `100_warcastle.sql`):
   `warcastle_moves`, `tournament_pairings.warcastle`, allegiances.
3. **The two instances** (built): `seeds/warcastle.sql` marks the real
   event (made in the event builder, Tournament type, named WarCastle);
   `seeds/warcastle-test.sql` makes "WarCastle (test)" with 26 dummy logins
   (`wc-test-01@example.com` …, one password set in the script), the real
   event's organisers and scenarios, and resets it on every run.
4. **Moving the armies** (built). Run opens on Map. After a round ends
   (or before round 1), tap an army in the checklist (winners, draws,
   losers, each by faction group), then the area it moved to, or Stays.
   Flags, never blocks: no crossing, a draw or loser staying put, three in
   an area, an army alone, allies together. Undo for slips. Players' maps
   follow the moves (refreshed every 20 seconds).
5. **Tables and deployment** (built). Run › Map › Tables: each area's
   scenario from the library. Make the pairings: each area's armies on its
   table, the last in attacks from the way it came, round 1 a roll-off
   (Swap after it). Ambush is offered to a winner who stayed. Players see
   their part and the deployment drawn in Play and on the Map tab.
   The deployments are the existing ones turned: Open Battle (north,
   south), Mountain Pass (east, west), Drawn Battlelines (diagonals,
   mirrored for north-west and south-east).
   *Still to do:* Play's own drawn table still shows the scenario's
   deployment, not the turned one.
6. **Allegiances** (built). Run › Map › Allegiances: add, remove, and set
   each army's. Shown by each army's name on the map.
7. **Quests** (migration). Several per player, secret, changeable at any
   time by the organiser, worth points, met in a battle or at the end of
   the event.
8. **Corruption and Waaagh!** (migration, may share 7's). Ported from the
   old branch, with opposing alliances able to push them down.

No overall winner: it's a big roleplay, not a tournament. Best general,
sportsmanship, painting and the like use the existing awards and soft
scores.

To try it: run `migrations/100_warcastle.sql`, create the WarCastle event,
run `seeds/warcastle.sql`, set the password in `seeds/warcastle-test.sql`
and run it, then open WarCastle (test).

## Open questions

1. **The pack's diagonal pictures** don't match their names: North-East
   shows the attacker in the top-left, and North-West and South-East look
   the same. The app follows the compass (the attacker deploys in the
   corner it came from). Which is right?
2. **Fighting an ally breaks the allegiance**: who leaves it, the
   attacker, or both? For now it's flagged and the organiser changes it.
3. **Renegade Crowns** isn't in the movement order: it's with Humans.
4. **Ambush after arriving from the north or south**: the attacker's strip
   comes in from the west edge. Right?
