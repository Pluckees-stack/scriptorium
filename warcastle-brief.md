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
   ally breaks the allegiance automatically. A player's IP goes with them
   to their new allegiance, but stays in the region it was scored in.
   (Tom has 5 IP in the Mountains and leaves the Jade Alliance, which had
   20 there: the Jade Alliance drops to 15.)
3. **Manoeuvre.** Each army moves to an adjacent area, or stays:
   - winners may stay or move;
   - draws must move;
   - losers must move, unless their last opponent left the area.

   Movement goes by faction, each group at once: Elves; Skaven; Chaos (not
   Chaos Dwarfs); Humans; Orcs, Lizardmen and Ogres; Undead; Dwarfs.
   The organiser settles anything left over (armies with no opponent,
   ties): "good" factions usually win ties, or roll for it.
4. **Battle.** The armies in each area play on its table.
5. **Resolve.** Results are logged in Scriptorium as usual. Losers must
   leave the area; winners may stay or move.

**Deployment** (player pack, `Player_Pack.pdf`):
- The **attacker** is always the army that moved into the area last; the
  **defender** is the one already there.
- The attacker's zone is set by the **direction they came from**: North,
  South, East, West (long or short edge strips, 24" deep on the short
  edges), or North-East, North-West, South-East, South-West (diagonal
  wedges). There is also a special **Ambush** deployment (defender on both
  long edges, attacker in a central strip from one short edge, with "BT").
- Each table has its own pre-made set-up (terrain).

**Personal objectives.** Each player has their own, secret. A player may
have more than one, and the organiser can change them mid-event. They
score points. Some are an end-of-event state (a quest) rather than
something done in one battle. Still being finalised.

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

An army can only cross a border at a dotted crossing. There are 25 (Grant
confirmed, 20 Oct), and never more than one between two areas, so a move is
fully described by where it starts and ends. **Attacker came from** is the
direction of travel, so it picks the deployment; worked out from the map by
Claude, for Grant to check:

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
- **The seed copies the real event's set-up** (table set-ups, objectives),
  so it is built once, in the real event, hidden from players until "Send
  to players".
- **Re-running the seed resets the test event** to before round 1.
- Dummy accounts and the test campaign are left out of anything
  platform-wide (finding players, records, leaderboards).

## Build plan

One PR each. Migrations are marked; the rest is front end.

1. **The map.** Areas, regions, crossings and directions in `index.html`.
   Zoomable on phones; tap an area for who's there and its table. Players
   see it read-only, kept live by realtime as the organiser moves pieces.
2. **Positions and moves** (migration, replacing the unrun `069`). Where
   each army stands; each turn's moves, in the order entered.
3. **The two instances** (seeds). `seeds/warcastle.sql` creates the real
   event with Grant as organiser; `seeds/warcastle-test.sql` the test one.
   From here every PR is tried in the test event first.
4. **Manoeuvre in the console.** Run, for WarCastle, follows the turn:
   Town crier, Diplomacy (with the round clock set to 15 minutes),
   Manoeuvre, Battle, Resolve. In Manoeuvre the organiser taps a piece, then
   the area it moved to, as it happens on the table. A checklist shows the
   movement groups in order and who still has to move. The app flags, but
   never blocks: no crossing; a draw or loser staying put; three armies in
   one area; an army left alone. Undo for slips.
5. **Pairings and deployment.** Locking Manoeuvre makes the round's
   pairings from the map: the armies in each area play on its table; the
   last to arrive attacks, and their direction gives the deployment. The
   organiser can swap attacker and defender, choose Ambush, or pair
   leftovers by hand. Starting the round sends each player their table,
   opponent, role and deployment (drawn as in the pack) with the table's
   set-up, straight into Play.
6. **Allegiances and IP.** The organiser records allegiances as they
   change; fighting an ally breaks it automatically. IP per player per
   region, alliance totals per region, moved correctly when a player
   changes side. Town crier uses the existing announcements.
7. **Personal objectives** (migration). Several per player, secret,
   changeable at any time by the organiser, worth points, ticked off in a
   battle or at the end of the event.
8. **Corruption and Waaagh!** (migration, may share 7's). Ported from the
   old branch, with opposing alliances able to push them down.

7 and 8 wait until the objectives and trackers are finalised.

## Open questions

1. **Are the "attacker came from" directions right?** Each physical table
   will need its north edge marked to match.
2. **Order of moves:** are winners, draws and losers each taken in faction
   order (all winners by faction, then all draws by faction…), or faction
   order first?
3. **Round 1:** with everyone placed by the organiser, who attacks? Roll
   off, or set by the organiser?
4. **Ambush:** when is it used, and what is "BT"?
5. **Factions in each movement group:** where do the rest go? A proposal
   for Grant to correct: Bretonnia, Empire, Cathay, Kislev → Humans; Chaos
   Dwarfs → Dwarfs; Daemons of Chaos, Beastmen → Chaos; Tomb Kings,
   Vampire Counts → Undead; Wood Elves, High Elves, Dark Elves → Elves.
6. **IP (influence):** how is it scored, and how is the overall winner
   decided (alliance with the most regions held, most IP, objectives)?
7. **Tables:** 13 physical tables, one per area, each with its own fixed
   terrain?
