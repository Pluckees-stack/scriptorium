# Working notes

Read this at the start of each session. Update it before ending one.

## How we work
- Work on a branch, push it and open a PR. Merge only when Grant says "merge",
  except: a PR with no migration may be merged by Claude once its tests and
  browser checks pass (Grant, 19 Oct 2026).
- Several sessions run at once: fetch main before each PR, and in this file
  edit only your own lines and sections.
- Grant runs SQL migrations and seeds himself. Mark each migration "Run" in
  migrations/README.md once he confirms.
- Keep sessions short: one piece of work per session, then update this file.
- Avoid parallel agents and heavy screenshot checks unless asked; they use a
  lot of tokens.

## Open PRs
- sim.cjs fails on and off, fixed in the test (30 Oct; no migration, test only), merged as #235. Cause, logged frame by frame: page.click's scroll-into-view centres its target in every scroller, so clicking Next on "Their units" scrolled the card strip (#endCardTrack) down about 400px. It's overflow-y:hidden but as tall inside as its tallest card. "Your units" then started under the masthead, buttons sat under the tab bar, and Playwright's retries slid the strip sideways until it snapped back and "Your units" went inert. Nothing was animating when it went wrong. Not something a player meets: a thumb can't scroll the strip up or down, and keyboard focus only scrolls what's out of sight. sim.cjs now taps everything on the end cards with tap(): it scrolls the window only, waits until the target is still for a frame, with nothing animating on it or its ancestors (the strip's height eases, and the page can follow it part way through) and nothing over its middle, then taps there. It also checks that each status button changed (a unit already on no wounds starts marked Killed, so its Killed unmarks it) and that the strip is never scrolled up or down (put page.click back on Next and that check fails). Other tests that page.click inside a .bf-swipe card can meet the same thing.
- Favour of the Gods not for sale, and spent by its round (Grant, 29 Oct; migration 113, run by Grant 29 Oct), merged as #234: (1) in WarCastle's shop (Get a magic item) the Warriors of Chaos list's Favour of the Gods is greyed out (#wcShopList li.is-disabled) and its Buy disabled: it's earned in battle (112). Only the screen: warcastle_buy_item would still take it. (2) No Used button: when a round ends, every Favour on a unit is spent (used_at) and gone, then the round's new Favours are given (113; items only go on between rounds, so one on a unit was carried through the round). Checks: warcastle.cjs (a Warriors of Chaos player's shop; a Favour on a card, a spent one gone), 113 on a local Postgres.
- Favour of the Gods into magic items (Grant, 29 Oct; migration 112, run by Grant 29 Oct), merged as #232: when a round ends, each Favour in that round's Chaos trackers becomes a free Favour of the Gods (Enchanted Item, 0 points) in the player's magic items, for Warriors of Chaos and Beastmen only (Dark Elves and Daemons can't roll on the Gaze of the Gods, Grant 29 Oct). Single use for the event (Grant: "one and gone"): spent by the round it's carried into (113, which replaced 112's Used button). It's an enchanted item as normal: no Favour on a model with another enchanted item. Items in the list a player brings, single use or not, stay available every battle (Grant 29 Oct, nothing to do). Checks: warcastle.cjs (Favour, Used), SQL checked on a local Postgres. Open: single-use items bought in the shop have no Used button (no single-use data yet).
- Result Supply (Grant, 29 Oct; migration 114, run by Grant 29 Oct), branch claude/nifty-cerf-7cli0e: each WarCastle battle's result gives Supply on top of the objectives held: win 3, draw 2, loss 1 (warcastle_tokens reason 'result'; history reads "Battle result, round N, table T"). The test stub (warcastle-rpc.cjs) only gives it when objectives are reported, not on a bare result change; check in warcastle.cjs ("and the result's Supply").
- Set up › Allegiances (Grant, 29 Oct; no migration), branch claude/peaceful-davinci-xec1t0: WarCastle's Set up has an Allegiances tab (Map, Entrants, Allegiances, Start; #wcSidesAdminTabBtn, #adminWcSidesPanel). Before the start the allegiances fold-out (#tournamentMapSidesWrap) is moved there, open, no summary: allegiances and their trackers before the lock, each army's once locked (entrant rows exist then). Back under the map in Event › Allegiances once it starts. Check: warcastle.cjs (before the event). Parked by Grant: warcastle.cjs "The organiser, moving the armies" failed in 3 of 6 full runs on this branch (the p05 tap into area 12 not registering, then everything after), passed every time alone and 4 of 4 on main; Grant sees nothing wrong moving armies by hand, thinks it's latency. Look at the test's fixed waits if it keeps failing.
- WarCastle Entrants tidy (Grant, 29 Oct; no migration), merged as #230: (1) WarCastle has no check-in in Set up › Entrants (renderAdminCheckIn skips it); check-in is on Set up › Start, which lists everyone before the lock too. The Entrants check-in's own Lock entrants shortcut goes with it there (the picker's Lock entrants stays). Ordinary tournaments keep check-in in Entrants. (2) The quest editor is Briefing and Quest, no Check step; Submit asks "Is X's briefing and quest ready to submit?" (not yet keeps it open). Grant saw the editor box close going back from Check on the live site; not reproduced here (desktop, phone, phone at 10x slower CPU), Check was the only step of a different height. Checks: warcastle.cjs ("no check-in in Entrants", "check-in in Entrants before the lock" for an ordinary tournament, "back to Briefing", "not ready", "Submit asks").
- WarCastle trackers, PR A (Grant, 29 Oct; migration 111, run by Grant 29 Oct), merged as #229: rules from Grant's doc "Warcastle allegiance rules" (claude.ai artifact MbTjLiJYwqVYdyW8PZH7v7). An add-on only: nothing existing changes. Run › Allegiances has Trackers: each allegiance None / Corruption / Waaagh! / Order (settings.warcastle.trackers.kinds), each bar's figures round by round, every submission (Remove). Once a battle has its result, a Chaos or Orc player gets a pop-up on Play (opens by itself once per device; a Corruption / Waaagh! energy button after) for burned, Grim Monuments, big units, characters killed, features on their own table after a win, the ritual (Chaos on table 6); points worked out in SQL. Map tab: two bars over the map, no numbers. Maths in warcastleTrackerState (sizes per round in settings.warcastle.trackers.sizes, kept by the organiser's view; never shrink). Checks: tests/warcastle/run.mjs (Trackers), warcastle.cjs (Trackers), SQL checked on a local Postgres. Not done (later PRs): taint spreading and putrid on the map (B); Shard holder, ritual effects (C); Favour of the Gods into magic items.
- WarCastle quests (Grant, 28 Oct; migration 110, run by Grant 29 Oct), merged as #228: Set up › Entrants has Quests under the entrants (#wcQuestsSection, WarCastle only): everyone signed up (the entrants picker's people), each with Edit, a flow of Briefing, Quest and Check (the two as written, formatted). Each box has the story toolbar (Bold, Italic, Heading, List, Numbered list, Quote; no Photo; Ctrl/⌘+B and I): storyFormat / storyInsert take the box, and numbered lists are opt-in (storyBodyHtml(body, { numbered: true }), storyFormat(kind, ta, true)) so campaign stories are unchanged. Saved to warcastle_quests (upsert on campaign, player). Send to players sets settings.warcastle.quests_sent_at (the same flag Start's Quests sent out switch sets, which stays as it was) and notifies everyone (notify_event_players); then hidden. Players: the holding card's tiles are Your quest (Not sent yet, then Ready, opening #wcQuestOverlay: Briefing, then Quest) and Your magic items; Player briefing and The war so far are gone (Grant). During the event Play's card has Your quest beside Briefing once sent (Briefing still opens the event pack). Secret by migration 110's policies (tried on a local Postgres 16: organiser all, a player none before sending and only their own after, no writes; re-run safe). Checks: warcastle.cjs ("quests in Set up › Entrants", "A player: Your quest").
- Builder keeps its terrain on a setting change (Grant, 28 Oct; no migration), merged as #227: only Shuffle positions, Random terrain (and the terrain tool's Random terrain / Roll all) and Random set-up place everything afresh, plus Mirrored on/off and switching terrain on. keepTerrain(): table or game size scales each piece's place to the new table; deployment map (and its Random) re-places markers and moves only pieces on the new map's markers, labels, own pieces or rivers; count, density and a single feature picked add or take away pieces by name (twin pairs when mirrored), the rest unmoved. Any piece off the table is nudged on; one on another piece is placed again with its twin. Rivers and roads are placed again, turned as they were, on a table or map change, or when the features include a different line. Check: tests/browser/map-keep.cjs.
- Turn a river or road (Grant, 28 Oct; no migration), branch claude/tender-faraday-q2k4hz: a "Turn" button (.mini-btn, data-line-turn) beside an added river's or road's width swaps it between top to bottom and side to side. The way it's turned (mapState.lineAcross, kept with the scenario in BF_KEEP) holds through Shuffle positions, mirrored or not; placeLinear takes it as dirs, falling back to either way if the turned way can't fit. A scenario's own fixed river can't be turned. Width stepper and Turn wrap together (.bf-line-tools). Check: tests/browser/map-lines.cjs.
- WarCastle map pieces show each player's icon (Grant, 27 Oct; no migration), branch claude/elegant-pasteur-iukoy4: the map's pieces (playerIconHtml) are now a person badge (.player-icon.faction-emblem with data-person), so paintPerson gives them the player's photo, else the emblem and colour they picked in Account › Profile, else their army's emblem on its colour; the number or initials only when there's no army. Tokens carry faction. Checks: tests/warcastle/run.mjs (Pieces). warcastle.cjs failed once on the drag checks (the known slow-run problem below), passed on re-runs.
- Every theme as the admin colour (Grant, 27 Oct; no migration), branch claude/beautiful-mccarthy-cvjqu4: Account › Display › Admin colour left out Chaos Black, White Scar and the four flag themes (Rainbow to Amethyst). All of EXTRA_THEMES are offered now, and admin mode takes on the picked theme's page (Chaos Black's dark, White Scar's white) and flag stripes (applyTheme looks up EXTRA_THEMES by adminColourChoice() in admin); a flag's admin tile shows its stripes, as on the theme grid. Check: scoring.cjs (9. Admin colour).
- Round timer: hours and quarter hours (Grant, 27 Oct; no migration), branch claude/nifty-clarke-j2di78: in a tournament campaign (WarCastle) Edit details is hidden, so the timer's (i) is the only place to set the round length, and its + from "No timer" did nothing (0 + 5 is under the 10 minimum). The round length is now two steppers in the (i): hours (± 1 h) and minutes (± 15, a length off the quarter hours steps onto them), up to 10 h; down to 0 is no timer; − / + disabled at the ends. Time left while a round's played stays ± 5 min, with Pause. Nothing in the app clears round_minutes, but seeds/warcastle-test.sql copies it from the real event on every run (each run a reset), so a length set only on the test instance goes. Check: warcastle.cjs ("the round length from the timer's (i)", "a timer from none").
- Channelling for every battle in a tournament (Grant, 26 Oct; uses migration 109, run 27 Oct), branch claude/fervent-mendel-l1i96g-tournaments, after the WarCastle round switch: any tournament but WarCastle has a Channelling switch in Edit details › Points and timer (tournaments.channelling); battles from its pairings use Channelling dice. Not shown in WarCastle, and WarCastle ignores it. Check: warcastle.cjs ("An ordinary tournament: Channelling for every battle").
- warcastle.cjs "The organiser, moving the armies" failed once on a slow run (27 Oct, checking the tournaments Channelling branch; passed on the re-run): the drag's save took over 8s, the until for spots.p05 gave up silently, and "a dragged piece stays where it was dropped", "and where it was dropped after the save" and "a moved army leaves the queue for Moved" checked without waiting. Fix: make those three wait (until) and check the until's result. Not started.
- Channelling for a round (Grant, 26 Oct; migration 109, run by Grant 27 Oct), merged as #221: WarCastle's Event box (#tournamentNext) has a Channelling switch (toggleSwitchHtml, #tRoundChannelling) only while the next round is drawn and not started; it saves tournament_rounds.channelling. A battle from that round's pairing sends battle_setup.magic 'channelling' whatever the table's scenario says (currentBattleSetup over scenarioBattleSetup; pendingRoundChannelling from the Play card). Rounds are read with select('*') so it works before 109 (the switch's save shows the error). Ploys are never used in WarCastle (Grant). 109 also adds tournaments.channelling (the next entry). Checks: warcastle.cjs ("Channelling for the round", "a round with Channelling").
- WarCastle Play centred, no roll-off line (Grant, 26 Oct; no migration), branch claude/awesome-gates-596uoh: the Play block for a WarCastle pairing (.wg-block.wc-play) is centred (deployment and head to head centred, head to head at most 28rem), which mattered on desktop. "Roll off: the winner attacks." is gone from Play and the Map's own-area card (warcastleRoleLine gives no line for a roll-off; the deployment still shows). Checks: warcastle.cjs ("the battle centred", "a roll-off, no line of text").
- WarCastle Play: head to head, not the round's tables (Grant, 26 Oct; no migration), merged as #213: during a round a WarCastle entrant's Play no longer lists every other battle under Play this battle (Map › Battles has them). Above the button: the area's number and the two players' badges head to head (tournamentTablesHtml with bare: true, faction from campaign_members). Ordinary tournaments and the organiser's Play unchanged. Check: warcastle.cjs ("Play: area and head to head"; the board's checks now run as the organiser).
- One logger again (Grant, 26 Oct; no migration), merged as #210: #188 dropped "who's submitting?" and claimed the logger only at the final Log, so both players filled in the result. Now End battle claims game_invites.submitter_id (claimLogging); the other player's turn poll sees it and they wait (showOpponentLoggingHold: "Waiting for X to log the battle…", Log it myself, back to Playing if the logger goes Back, which releases the claim). Rejoin goes back to logging or waiting. doLog's "Log it anyway?" and the conflict handling stay as the fallback. Check: tests/browser/sim-paths.cjs part 4.
- Logger's Play card catches up (Grant, 26 Oct; no migration): in a tournament the one who logged it kept "Waiting for X to confirm the result." after X confirmed (Play was drawn once, never read again). While a block is waiting (t-awaiting: to be confirmed, or disputed), refreshTournamentGameCta runs every 10s on the WarCastle hold timer. Check: tests/browser/warcastle.cjs "sees the confirmation within seconds".
- Settled tournament Play card (Grant, 26 Oct; no migration): once a pairing has its result, Play shows the tournament, round and area, "Waiting for the round to end.", the two players head to head (tournamentTablesHtml readOnly: badges, armies, result and score) and View detail (details.admin-section, scoreColumnsHtml from the battle's breakdowns), nothing to amend. Factions now load for any tournament's head to head. No change to logging or confirming. Check: tests/browser/warcastle.cjs "Play: settled".
- Settled card layout (Grant, 26 Oct): "Round N" centred in the display font, "Waiting for the round to end…" in italics, each side's victory points shown open (no View detail fold-out).
- Play cards uniform (Grant, 26 Oct; no migration): before and after a tournament battle, Play's card heads with "Round N" (display font, centred) and a line in italics under it (Area N / Table N before, "Waiting for the round to end…" after; roundCard in refreshTournamentGameCta). The head to head is stacked (tournamentTablesHtml stacked: no table number, each badge above the name, 2.8rem; .t-match.is-stacked). An ordinary tournament's card now has the head to head too.
- WarCastle Briefing on Play (Grant, 26 Oct; no migration): once the briefing's sent (settings.setup.sent_at), Play's card before and after a battle has a Briefing button (button.act.btn-secondary, data-wc-briefing) opening #wcBriefingOverlay with the event pack (eventPackHtml) and its Download the player pack. Grant: quests will go in the briefing, so no Quest button. Check: tests/browser/warcastle.cjs "Briefing".
- Found, not fixed: warcastle.cjs's Map drag checks ("drag a piece to move it" and the rest) failed once on 26 Oct and passed on the re-run.
- Found, not fixed: tests/browser/sim.cjs 3 58 times out on a click in battle 2 on about 3 runs in 5 (26 Oct). Narrative campaign, not the tournament Play card. Not yet checked on main.
- Found, not fixed: in the Dark Elves theme the leading side's total (.vp-head.is-lead, var(--gold) = #7a5c8a) is barely readable on a faction panel. Affects every two-column score in that theme.
- Players restructure done (P1 #121, P2 charts; chart view: data points at the top, list filters hidden in Chart, Export CSV of the chart beside Pin to Home), branch claude/festive-ride-0y0cvh. Charts also: By Scenario, measures VP scored / conceded / winning margin, As average per battle or biggest in one battle. Also By Unit / Magic item (Lists taking it, Points spent; a unit by Kills or Times wiped out, the latter Path to Glory only); Lore chart dropped (Grant). Chart options fold away (details.admin-section). Buttons now follow CLAUDE.md UI components (steppers, closes, follow, photo toggle, carousel arrows merged; .pm-btn and .x-btn gone); campaign Set up is Event details / Phases (opens on Phases, and on the phase being played); scenario rows reworked. Home: once the setup checklist is finished (or hidden) it stays put; later gaps join "Needs your attention" (was "Waiting on you"). Storytelling for campaigns to discuss with Grant. Merged: A–E2 (#102–#116), C1–C3 (#117–#119), #120.
- #152 (archived units left out of list points totals: phone roster deck, alliance members' lists, tournament entrants) merged.
- #98 (rules scenarios drawn exactly, seed re-run) merged.
- #100 (scenario editor shows a rules scenario's drawn map once) merged.
- #101 (Play shows the set-up table under the scenario picker, "Edit set-up") merged.
- Scored battles use the scenario's table as it comes (Grant, 26 Oct; no migration), branch claude/trusting-mayer-3hydyw, PR #212: in a campaign, tournament or WarCastle battle there's no Build a scenario / Set up / Edit set-up on the scenario step (only free play and no-opponent battles keep it); players choose from the list only ("Choose a scenario."). A tournament or WarCastle pairing's scenario (the round's or the table's) is locked: picker disabled, no Random (lockGameMission). builtScenarioMission is gone; the accepter still reads battle_setup.mission for requests sent before. Checks: scoring.cjs (1, 4), warcastle.cjs ("Play the pairing").

- Account and import (Grant, 21 Oct; no migration) merged (#157): Import is its own panel within Lists: a small Import option to the left of Yours on the Lists switch (Import · Yours · Other players); Lists still opens on Yours, a finished replace import goes back to Yours, onboarding opens Import (an overlay at first, made a normal tab at Grant's ask, 21 Oct). The Account tab is the settings page itself (no Account settings overlay): swipeable cards (drawSwipeCards, with its own .scope-switch.admin-subnav tabs via data-own-tabs) for Profile (name and club, one Save), Campaigns (list, current campaign, join with a code, Run a tournament), Display (theme, dark mode, text size, fun extras), Security (password, two-factor, Sign out). On wider screens the Lists switch's slide is a short nudge and fade (#160). Display also has Font (Classic / Clear = Atkinson Hyperlegible / OpenDyslexic, via data-font on :root swapping the font variables; web font loaded only once picked) and, for organisers and site admins, Admin colour (fold-out: Opposite of my theme, the default, five admin-only colours, or any faction's); both kept on the device only (localStorage scriptorium.font / scriptorium.adminColour), by Grant's choice, 21 Oct. Could move to players columns later. The logo (h1, The Scriptorium) keeps Old London whatever the font (#163). Accessibility (Grant, 21 Oct): every theme is kept readable by readableAccent (pale text on the main colour and dark-or-pale text on gold, both 4.5:1; colours nudged only as far as needed; --on-gold replaces fixed #171a1c on gold); Display has High contrast and Reduce motion switches (data-contrast / data-motion on :root, set in <head> from the device, else the phone's own settings; reduceMotion() replaces the matchMedia checks); Skip to content link. Faction themes have their own names on Account › Display (FACTION_ACCENTS[].theme, a place and its colour: Athel Loren emerald, Warpstone green, Hashut rust, Naggaroth violet, …; the gods likewise, Khorne red …; .label stays the faction name everywhere else); the four Chaos gods are themes too (EXTRA_THEMES god-khorne/-nurgle/-tzeentch/-slaanesh, also offered as admin colours). Chaos Black (white on black, the black page) and White Scar (black on white, the white page; swapped at Grant's ask) are EXTRA_THEMES with page:'light'/'dark' (they ignore dark mode), onOxblood and panelInput; --brand is the theme colour as text on the page (logo, eyebrows, links), set to the ink for these two (Chaos Black and White Scar). Every theme swatch is a gradient of its palette (main colour to gold). Pluckee yellow (Grant's YouTube channel colour: warm bright yellow #f5c400 with pure black text, ink #000; Grant happy with it, 22 Oct); its own touches in CSS via :root[data-theme-key] (set by applyTheme, the admin colour's key in admin): thick white outline on the logo and headings (text-shadow rings), bar in the full yellow, icons and labels outlined in white (drop-shadow on .tab-btn) is a light-panel theme (onOxblood dark) and an admin colour. Light panels are now general: a dark onOxblood gives white panel inputs, and --brand falls back to the ink whenever the theme colour is under 3:1 on the page. Flag themes, named subtly for their colours (EXTRA_THEMES: Rainbow, Sky and rose = trans, Dusk = bi, Amethyst = non-binary; keys flag-pride/-trans/-bi/-nonbinary) sit after the factions; swatch and active tab bar show a soft left-to-right gradient, not the full flag (Grant, 21 Oct). Next from the accessibility list, not started: colour-only signals (charts, map), larger tap targets, a screen-reader pass of battle flows. Explainer lines and hint placeholders there removed; saves confirm with a toast. Open play's separate join box merged into Campaigns. The Old World Builder export steps in the import overlay stay as written (Grant wrote them for there).

- Profile photos (Grant, 22 Oct), branch claude/awesome-ptolemy-f60zd9, merged as #180 with migration 102 (players.avatar_path, public avatars bucket; run by Grant 22 Oct): Account › Profile has your photo (Add / Change / Remove; cropped to a 320px square). Story's switcher is Profile · Campaign · All (centred, no heading): Profile is a player's photos from their posts as a three-across grid (renderStoryProfile; your own by default, anyone's by tapping their name or photo on a post; each opens full size, yours with Remove photo). Double-tap a post's photo to like it (a thumb rises; never unlikes; single tap opens it after 280ms). The word "chronicle" is gone from the interface (Post to Story, Posted · See it in Story); "Best chronicler" (an award) kept. Every person is the one badge, .faction-emblem via personBadgeHtml()/setPersonBadge(); anything with data-person gets that player's photo painted in (paintPerson, a MutationObserver, batched lookups), WarCastle's .player-icon included. Works before 102 (no photos, picker hidden). Not yet: photos in standings / players lists (they use .alliance-dot, not a badge).

- Profile icon and crop (Grant, 22 Oct), branch claude/awesome-ptolemy-f60zd9, merged as #185 with migration 103 (players.avatar_emblem, avatar_colour; run by Grant 22 Oct): with no photo, Account › Profile offers Emblem (any faction, or your army's) and Colour (a colour picker, or the emblem's own); shown for you everywhere via data-person (paintEmblem swaps the badge's emblem and colour, and puts it back). Picking a photo now opens a crop step (square frame, circle kept; drag, slider, pinch, wheel or keys to place and zoom; Cancel saves nothing). Order: photo, then picked emblem, then army's emblem, then initial.
- Front page (Grant, 22 and 26 Oct; no migration), merged as #187: the slow splash is gone. Signed out, #login is the front page: "Warhammer: The Old World", the title and "Every deed is weighed. Every death is recorded." on the left (above on phones), fading in one by one from the top; the sign-in card on the right, there from the start (Sign in · Create account switch, Continue with Google, then the fields; 'signup' is the same screen, setAuthMode). No emblems or feature text (Grant cut them). Hint placeholders on sign-up removed. Link preview image is the white logo on oxblood only (assets/og-image.png?v=2). Google: with GOOGLE_CLIENT_ID set (config block), Google's own button signs in by pop-up (signInWithIdToken), so the chooser names thescriptorium.co, not syocqufswktsbuqcnurp.supabase.co; empty, the old redirect stays. Browser checks: tests/browser/front.cjs.

- Scoring check (Grant, 22 Oct; a friend's battle gained 500 VP from nowhere; no migration), merged as #188 (migration 105 run by Grant, 23 Oct): a scored battle needs a scenario, picked or built on the scenario step (a built one scores by its own objectives and VP and goes with the request as battle_setup.mission); with no scenario only units score (it used to switch every objective on, Breaking the Enemy 500 included). King is Dead counts a General fled or fleeing. End of battle is one stage of swipe cards (bf-tabs/bf-swipe, drawSwipeCards): Their units, Your units, Victory points, Finalise. Scoring follows the Matched Play Guide (tow.whfb.app, checked 23 Oct): a unit fleeing or at 25% of its starting strength or less is half its points (was a quarter); King is Dead 100 for the General slain, fled or fleeing; Trophies of War 50 a standard plus 50 for the Battle Standard Bearer slain, fled or fleeing; Breaking the Enemy 500; Special Feature 200; Baggage Trains 100 for each train held (your own or the enemy's: a counter, two trains at most between the sides, less any destroyed) and 250 for destroying the enemy's; Domination 100 a quarter, +50 double strength, +100 uncontested; Strategic Locations 30 a marker at the end of every player's turn (on the card a count, Number held, all turns added up, starting from what was banked; markers × 12 between the two sides, strategicHeld). Victory points (renderVpTable) enters each objective the way it scores (Grant: "a check box situation"): switches for the conditions, counts for standards and quarters, VP for units, what's scored turn by turn and Other (VP_ENTRIES); This scenario open, Other points folded (each fold-out stays as left). Worked-out entries (units, King is Dead, the Battle Standard Bearer, Breaking the Enemy, Strategic Locations) follow the units until set by hand, and again once set back. Every score display is two columns, a side each, the player who took the first turn on the left (sidesInTurnOrder; Grant asked for attacker left, defender right, and there's no attacker outside narrative scenarios and WarCastle), a faint line between them, each thing scored named across both columns with the two sides' figures below, centred (scoreColumnsHtml, .vp-cols, .vp-row-head); Domination reads Quarters held, then Of which your units had double strength / were uncontested, the terms double strength and uncontested in bold; King is Dead and the Battle Standard Bearer read slain, fled or fleeing; Special Feature has "Controlled at the end of the battle" across both columns and just a switch each (VP_ROW_NOTES); in a column a switch's label sits under it; Units destroyed is just each side's total with Show units, a pop-up of the units that scored (status and VP; #vpUnitsOverlay, an EXTRA_SHEETS sheet) whose Edit goes back to that side's unit card; figure boxes (Other, Battle March's) are the standard field, narrowed to fit; the rest supporting text at the same size as every other entry label, row headings larger; a quarter is double strength or uncontested, never both (the two together at most the quarters held), and four quarters between the two sides (countMax, fitDomination): the Victory points card, Finalise, the running total, the battle log's Scoring and a tournament round's results. The organiser's amend score table is the same Victory points card (renderVpTable on a board: VP_BOARD for the end of a battle, amendBoard for the table, units as a figure there as there are no unit cards), opened as it was entered: the organiser's own entries (vp_detail.entries), else the battle's (each breakdown line carries its entries), else worked back from each element's VP (stateFromScore; whatever doesn't fit in Other, so the total holds). Saving keeps each element's VP (vp_detail.a / .b, SCORE_PARTS from VP_ELEMENTS plus Custom objectives) and the entries. The organiser's other two forms are the same card too (Grant, 23 Oct: every result form the same; an organiser just puts a result right): Edit a battle (Run's battle list) has a Score step (gameEditBoard, saved straight to games: player_vp / opponent_vp and the breakdowns) with Work out result & points from VP; Add a battle puts a head-to-head's score on the card under the two players (manualGameBoard), each player's VP from it, and sends each player's breakdown, kept by migration 105 (105_manual_game_breakdowns.sql, run by Grant 23 Oct). A 1-player or 3+ player battle added by hand has just each player's VP (the card is two-sided); manualObjectiveScore and its old objective blocks are gone. organiserBoard() makes a card for any battle an organiser enters. Finalise's headline is the result in words ("Minor Victory for Alice", resultHeadlineHtml) with a line of the battle's story under it (picked once per battle), then the scores, then the campaign points. The running total leads with who's ahead in the same voice (runningLeadLine). No more waiting for both players to agree: either player logs the battle (claims game_invites.submitter_id; the other is asked "Log it anyway?") and the other confirms or disputes it from their battle log, which shows each side's VP and a Scoring fold-out; a player still in the battle is told when the other has logged it. In play: a running total (Victory points so far, with Scoring so far folded: units at no wounds on either tracker, the opponent's read from their units every poll, King is Dead, Breaking the Enemy, Strategic Locations banked) and Strategic Locations every turn (Grant: both players score their markers at the end of every player's turn; whoever's turn it is records both, − / + within the scenario's count, kept turn to turn; unsynced battles alternate first and second player's turns too). Also: End my turn checks the save; banked Strategic Locations reloaded on rejoin; own units wiped on your tracker start as dead; going back from the end screens keeps the marks and figures. Checks: tests/vp/run.mjs, tests/browser/scoring.cjs.

- WarCastle-only panels (Grant, 23 Oct; Supply and Warpstone showed in a new ordinary tournament; no migration), branch claude/sharp-bardeen-2bt0wn: Lists' Supply and Warpstone row (#wcItemsRow) was only re-rendered while in WarCastle, so after visiting WarCastle it stayed showing in any other campaign. renderRosters now always runs renderWarcastleItems (it hides itself outside WarCastle), and it and renderMyBattalions drop their result if the campaign changed while they loaded. Check in tests/browser/warcastle.cjs ("From WarCastle to another tournament").
- Scenario pickers grouped by book again (Grant, 23 Oct; no migration), branch claude/inspiring-cannon-1h8xsv, PR open for Grant: every scenario dropdown uses missionOptionsHtml (this campaign's first, then Rulebook, Matched Play Guide, Arcane Journals, Battle March; the book read from the description's prefix, rulesSourceOf); the Scenarios library heads the rules' tiles the same way. Check: tests/browser/scenario-groups.cjs. Also in #189 (Grant, 23 Oct): the old scenario form and the bulk CSV import of scenarios removed (the builder replaces both; tests/csv gone); custom objectives, whose only form was inside the old one, have their own fold-out on the Scenarios tab (Custom objectives: list, Delete, Add a custom objective), which the builder's Custom objectives step points to. Check: tests/browser/scenarios-admin.cjs. Not done: the four copies of "copy a rules scenario into this campaign before changing it" (Scenarios tab, Phases, Set up rounds, WarCastle tables) still differ in wording.

- Play empty for the organiser (Grant, 23 Oct; WarCastle and WarCastle (test); no migration), merged as #192: during a round, someone not entered in the event (the organiser) got a blank Play (a tournament hides Play battle, Free play and game nights, and only an entrant's pairing was drawn). Now they see every table in the round, as between rounds, and an organiser not entered has a Go to Event button at the top of Play at any stage (switches to admin and opens the Event tab; Grant: "just a button"). Check in tests/browser/warcastle.cjs ("The organiser, Run as one page").
- Players' WarCastle map as the organiser's (Grant, 23 Oct; no migration), merged as #195: the Map tab (renderWarcastlePlayerMap) now draws what Event › Map does, with nothing to move: every army's piece (all fixed; a tap on one picks its area), sword and shield, crowded areas red, while moving the green and red rings for whose turn it is, and the round in Old London over the corner (warcastleMapCaption). No tray, queue, Stays/Move, Undo or Make pairings. A Map · Battles switch (#wcMapTabs, data-own-tabs, swipe cards #wcMapTrack) gives Battles: that round's tables (while moving, the round just played) as Event › Battles draws them (tournamentTablesHtml with readOnly: rows aren't buttons, nothing opens); the last round's other results wait for the reveal. Checks in tests/browser/warcastle.cjs ("A player, round 1 in play", "while the armies move").

- Kill credits only with Path to Glory (Grant, 23 Oct), merged as #194 (migration 106 run by Grant 26 Oct): with Path to Glory off a killed unit's button on the end-of-battle cards reads "Killed", with no picker, and its flavour line names no killer (STATUS_LINES_DEAD_*_NO_KILLER); doLog sends no kill_credits. 106 makes apply_game_kill_credits give nothing when the campaign has Path to Glory off and clear that battle's credits (so reverse_game_kill_credits stays exact). How units ended and the scoring unchanged. Checks in tests/browser/scoring.cjs (2 off, 2b on). Later, separate: organisers re-marking units after a battle is submitted (saving each army's full unit list with the battle). Players chart Kills (Grant: "just the number of kills"): with Path to Glory off it's each player's enemy units destroyed, counted from their breakdown's units line ("…, destroyed: N"; units set by hand keep no list, so count none), and Kills by unit isn't offered; with it on, kill credits as before. Check in scoring.cjs (8). The organisers' re-marking work (next) will save full unit lists, which Kills could then count from instead.
- Organisers re-mark units after a battle (Grant, 23 Oct; no migration), branch claude/jolly-ptolemy-hze8ox, merged as #197: every logged battle keeps each army's full unit list in its breakdown's units line (entries.units: id, name, size, points as then, general, bsb, status; null alive), the line kept even at 0 VP (scoreColumnsHtml hides 0-VP units rows). computeVpTally scores from S.units when a state carries one (else the armies as marked) and returns unitList. Units destroyed is the total and Show units on every card; the organiser forms' figure (units: 'figure') is gone. On an organiser's card (Edit a battle, Add a battle, the amend table) Show units lists every unit with the unit cards' status buttons (unitMarkHtml, shared with renderUnitTracker; "Killed", no killer: score only, Grant), read only while the card's locked; a re-mark redraws the card. stateFromScore restores the list, and the units' VP, King is Dead, Battle Standard Bearer and Breaking the Enemy follow it again unless set otherwise (withUnitsFollowing); a worked-out element with no line restores as not met. An older battle (no list) keeps its units' VP and lists its units as written (S.unitsLegacy), read only; corrections in Other. Edit a battle's result and campaign points, and the amend table's result (tournamentPointsFor, as the standings take it), follow the score while they're what the score gave. Add a battle offers each player's current army (copied into the battle on save). Grant decided: score only, never kill credits, experience or loss rolls. Kills chart counts entries.units when there. Checks: tests/vp/fuzz.mjs (reopens with every unit's status; a re-mark saves and reopens), scoring.cjs (2, 6, 6b, 7), warcastle.cjs ("re-marks a unit on the amend table").
- Free play with no opponent, tracked to the end (Grant, 24-25 Oct; migration 107, run by Grant 26 Oct), merged as #198, then corrected (Grant, 25 Oct: #198 brought back the Units destroyed counter he'd had removed, and dropped Your units so he couldn't mark which of his units died), merged as #199: with "No opponent available" (isSoloFreePlay) End battle goes to Your units (mark your own units as in any battle), Victory points and Finalise; Their units moved aside (#endCardsAside; data-end-go numbers resolve by card, endCardAt). No units figure anywhere: your Units destroyed is greyed out (no enemy army), the opponent's comes from your units with Show units, and the rest of their side is greyed out (VP_BOARD.greyed(side, key); their worked-out objectives off), so their total is just what your units gave. You enter your own objectives. Finalise shows both scores, no result. Saved to free_play_log (107, changed before it was run: player_vp, player_breakdown, opponent_vp, opponent_breakdown with your army as it ended, scenario, notes; before 107 just the marker). Battle log: "0–200 VP · Not counted toward the campaign" and Scoring. Never scored. Check: scoring.cjs (2c). Lesson: Grant's "Units destroyed" counter is gone for good; never bring a typed units figure back.
- King is Dead's switch reads "The enemy general is slain, fled or fleeing" (Grant, 26 Oct). Same PR: the swipe card strips (drawSwipeCards) could mark a card part-way through a Next/Back slide as current when the slide paused, leaving the card it was going to inert (Finalise's Confirm & log battle untappable; scoring.cjs failed about 1 run in 8). showSwipeCard now keeps track._goingTo until the slide arrives (or 1s, then settleSwipeCard marks what's in view).
- Moving the armies: who can fight where (Grant, 23 Oct; no migration), merged as #196: an area holds two armies to fight. Those who've had their turn (moved in or stayed, in turn order) hold it (warcastleManoeuvre: held, mustLeave). A third taking its turn there is flagged ("can't fight in area N: A and B already hold it") and asked "Move there anyway?" / "Stay anyway?" (never blocked: Grant wanted no hard wiring). Once two hold an area, anyone still to move from it is told to leave on their turn: a toast at that move, a flag, and "has to leave" in their row. Placing in round 1 too. An area with armies still to move is free to move into (Grant), so "Area N has 3 armies" and the red only come once none in it is still to move (man.crowded). The caption over the map's corner says who's moving now (Winners · Elves; everyone has moved), and the list and the army being moved show each one's faction (and result, when picked). Checks: tests/warcastle/run.mjs, tests/browser/warcastle.cjs (app.cjs keeps page.dialogs).
- Strategic Locations in play (Grant, 26 Oct; no migration), branch claude/zealous-davinci-t1jhbo, PR open: the in-play − / + counts were kept turn to turn, so a count left alone was banked again at every End turn (one marker held once read 10 on the score card), and they carried into the next battle. Now both counts go back to 0 at the start of every player's turn and of every battle (clearStrategicHeld); each turn's markers are added to each side's total as before, and the score card's Number held (still − / +) shows that total. Under each side's count in play: Total N · VP (every turn banked so far; the other player's turns too, read every poll). Checks: scoring.cjs, sim-paths.cjs. Waited on #205 (warcastle.cjs made steady) and #207 (a check for the swipe cards), both merged.

- Who goes first, in every battle (Grant, 26 Oct; no migration), merged as #204: "Who goes first?" was only ever asked in a linked scored battle (request accepted, scenario picked); free play, No opponent available and Start without waiting went straight to Playing with "First player's turn". Nothing had removed it. Now enterPlayingStage asks whenever it isn't settled yet (syncedFirstPlayerId, now the first player in any battle), on that device alone; the turn line reads "Your turn." / "Bob's turn." and the score columns follow it. Skip to result still skips it (no play). The question has no line under it (Grant, 26 Oct: "Decide at the table…" removed). Checks: sim-paths.cjs (Start without waiting), scoring.cjs (2c).
- No double-tap zoom on phones (Grant, 25 Oct; tapping a counter fast twice zoomed the page; no migration), merged as #200: buttons, links, fields, labels and summaries take touch-action: manipulation (one CSS rule by `* { box-sizing }`). Pinch zoom kept on purpose (accessibility). Left off role="button" rows so the Muster List's double-tap rename still works. Check: tests/browser/tap-zoom.cjs.

- Crossed battle requests (Grant, 26 Oct; two players on WarCastle (test) both tapped Play this battle, each sent the other a request, one was declined and nobody knew whose battle counted; no migration), merged as #202: the earlier request is the battle. Sending checks for a request already waiting from that opponent and joins it instead (crossedInviteFrom, joinCrossedInvite; a toast says so); while waiting, each poll checks again, and if theirs was sent first (inviteIsEarlier: created_at, then id) yours is withdrawn and you join theirs as the one who accepted. Both sides apply the same rule, so exactly one battle is left and no one has to decline. The waiting screen also now notices a withdrawn or expired request ("The request was withdrawn."; it used to wait for ever). Checks: tests/browser/sim-paths.cjs (3a-3c).
- One open battle per pair in the database (Grant, 26 Oct: "close any avenues for error"; migration 108, run by Grant 26 Oct), merged as #203: a unique index on the pair over pending and accepted requests refuses a crossed request even in the same instant (23505); sendGameInvite then joins the one already there. 108 also withdraws any extra open battles a pair already has (keeps the one under way, else the earliest). #202's client-side sorting kept as a fallback. Checks: sim-paths.cjs (3a'; fake-supabase's window.__FAKE_REFUSE stands in for a constraint); 108 tried on a local Postgres 16 (tidy, refuse, re-run). (A one-off warcastle.cjs drag failure seen while checking this was the slow-run problem #205 fixed.)
- warcastle.cjs made steady (26 Oct; tests only), branch claude/zealous-davinci-t1jhbo-warcastle-waits: "The organiser, moving the armies" failed on slow runs. Picking an army scrolls the map smoothly on a phone, and the tap was measured mid-scroll, so it missed; the two Undos then took back the wrong moves and every drag after failed. It now waits for the map to stop moving before a tap or drag (mapSettled) and for each move or undo to show (until) instead of fixed pauses. Passed 6 runs of 6, three at a time.
- Check for the swipe cards' Next (26 Oct; tests only), branch claude/zealous-davinci-t1jhbo-swipe-cards: the fix for the cards going back mid-slide landed in #206 (line above) with no check; scoring.cjs now has one ("Next on a slow phone": the slide starts late and a scroll is read before it moves; failed on main before #206, cards went 2,1,2). Not checked: the battlefield steps (showBattlefieldStep) and the flow pop-up (showFlowStep) have their own swipe code and may have the same race.
- Standings fixes (Grant, 26 Oct, from WarCastle reviews; no migration), branch claude/laughing-faraday-6bd06d, PR #209 open: (1) a battle the other player logged is confirmed on Play: the tournament pairing's block shows what they logged, Confirm this result (button.act) and Something's not right (pendingConfirmHtml, shared with the battle log; onPendingConfirmClick on both). Play used to tell both players "Waiting for X to confirm". In a tournament, Needs your attention's Check the result stays on Play (goToBattleCard; it used to open the Map / Standings tab), and the "has logged this battle" toast says on Play. (2) WarCastle: players don't see the standings until the organiser reveals the final results (final_results_revealed_at, the existing Reveal final results; Grant: off till the final round). (3) Every tournament: players' standings are #, Player, W–D–L, Adj. (if any) and Score, ranked by score (tournamentPlayerStandingsTableHtml); no Overall, VP ±, SoS, soft scores, Best Overall or tiebreak lines. The organiser's table, print and CSV unchanged. (4) Every tournament: campaign points count as off (campaignPointsOn), so no CP in the battle log, records or confirm notes; the organiser's Edit a battle and Add a battle hide their CP fields, the pending list and its messages drop CP. Checks in warcastle.cjs ("their opponent logged the battle", "the standings").

## WarCastle (Grant, 20 Oct 2026)
- Brief, plan and settled questions in warcastle-brief.md. Steps 1 to 6
  merged (#150 map; #151 moves, seeds, manoeuvre with draggable pieces,
  tables and deployment, allegiances; migration 100 and both seeds run).
  WarCastle (test) has 26 dummies (wc-test-NN@example.com; password from
  Grant); re-run seeds/warcastle-test.sql to reset it.
- A tournament event's entrants are in Set up › Entrants (check-in, lock,
  Start event); Run has no Entrants step. WarCastle can start once all 13
  tables have a scenario (its rounds have no plan of their own).
- WarCastle's starting places are in Set up › Map (Grant, 21 Oct): placed
  any time before the start, even before the lock (the night before).
  Start event needs every army placed, makes round 1's pairings from the
  map, and round 1 is then fixed; moves are in Run from round 2. A table
  with no attack to follow (round 1, or both stayed) is a roll-off: the
  players decide who attacks (deploys first), not the app.
- The organiser's map (Grant, 21 Oct): pieces are dragged smoothly (the
  piece lifts, lands where it's let go, shows at once and saves behind),
  each with its player's name under it; the page widens while the map
  shows (900px and up). Browser checks: openApp takes viewport and touch.
- Play before a tournament event starts: a holding card (not started yet,
  the name, the player's faction emblem and a live countdown to the start
  day and time in UK time (ukTime), "In 3 days, 4 hours, 12 mins, 9 secs", tiles for army, list and venue, the event
  details folded away). WarCastle's tiles are Your quest and Your magic
  items (Grant, 28 Oct; Player briefing and The war so far dropped).
  To build: a briefing doc per player, quests per player (secret), magic
  items, and fun narrative stats (alliance on the up, biggest slaughter,
  not called standings). The pack card steps aside until
  the start; WarCastle's pack has no pairings system, scoring or ties.
- WarCastle battalions (the Narrative Gazette, pp 19-23; Grant, 22 Oct):
  players tag units [Recruit] / [Veteran] (also [Warlord], [Lord Commander])
  in OWB's unit name, which OWB keeps as unit.name (name_en is the type).
  Import reads the tag into wargear.battalion (an untagged general is the
  Warlord) and the rest of the name into the nickname; a picker per unit and
  a whole-file switch put it right; the unit editor changes it later.
  A file of only some battalions (every unit placed) adds to the list:
  "Add to existing roster" only treats units of those battalions as
  dropped, merges the OWB file unit by unit, and keeps the list's name and
  points (warcastleImportScope, warcastleMergeOwbRaw; Grant, 22 Oct).
  Two files copied from one OWB list share unit ids: a unit whose id is
  already on a unit in another battalion becomes "<OWB id>~<battalion>" in
  the units and the stored OWB file, so both are kept (Grant's two Grand
  Cathay files, both with the Grand Cannon; fixtures warcastle-cathay-*).
  The import preview keeps its one line; no note about battalions (Grant).
  warcastleBattalionChecks flags (never blocks) points, slots, the Warlord
  types (WARCASTLE_WARLORDS, OWB names), magic items and the army's 2,500
  and half-its-models rules; shown on import and in Lists.
  Lists shows each battalion's points by slot (warcastleCategoryPoints, %
  of the limit for Recruit/Veteran) and a View battalion button; your own
  list below is hidden in WarCastle and opens a battalion at a time in
  #wcBattalionOverlay, which #rostersMuster moves into (so every card
  handler still works), always as cards. "Not in a battalion" and
  "Archived" rows appear when there are any (Grant, 22 Oct).
- WarCastle tokens and items (migration 101, run 22 Oct): Lists ›
  Magic items (Supply, Warpstone, Get a magic item from WARCASTLE_ITEMS, a
  compact copy of OWB's magic-items.json, Send tokens, history); Run's
  Supply and Warpstone fold-out (+3 Supply, swap 3 for a Warpstone, undo);
  Play's Your magic items tile. Prices are set in SQL (warcastle_item_price),
  mirrored by warcastleItemPrice. Browser checks: tests/browser/warcastle-rpc.cjs
  stands in for the functions (a world's rpcSource). The shop has no Battle
  March items (OWB compositionRule battle-march), groups by type in the
  rulebook's order, dearest first, and each name opens its rules (a world's
  rulesIndex stubs the index in tests). Each unit card has Your magic
  items: Equip magic item and Remove, only between rounds (the tournament
  active, no round active; client-side only, the database doesn't check),
  within each allowance (warcastleItemFit: the character's Magic Items
  points, a champion's, a standard bearer's banner, a BSB's without limit;
  one of each kind). Next: which battalions play by round/scenario.
- The organiser's map (Grant, 22 Oct): an area with more than two armies
  is red. From round 2, the armies whose turn it is (the first group in the
  order with anyone still to move) are bigger with a green ring and are the
  only ones that drag on the map, along with any already moved; the rest
  still to move have a red ring. Where two meet, a sword marks the attacker
  and a shield the defender (as the pairings have it once made). The list
  beside the map still moves anyone.
- A tournament event's Event details has one When and where row (day,
  times, venue; one sheet, one Save; Grant, 22 Oct); a campaign keeps its
  Dates row. Times are dropdowns in 5-minute steps (fillTimeSelect).
- Finalised set-up locks Set up's Edits: they now look switched off, and
  Event details has a "Finalised" note with its own Unlock (Grant couldn't
  find why Edit did nothing, 22 Oct).
- Tables have no deployment (the attack sets it): Set up › Tables opens the
  builder with no Deployment step (shape 'none', saved deployment null).
- seeds/warcastle-tables.sql: 13 dummy table set-ups ("Dummy N: …") made
  that way: terrain, strategic locations on all, a special feature on 4, 6,
  7 and 13. Run it, then re-run warcastle-test.sql to copy them across.
- Event tab (Grant, 23 Oct; plan of four PRs agreed): for tournament
  campaigns the organiser's "Run" is "Event", left of Set up (moved in the
  DOM). PR 1: once WarCastle is running its Event page is tabs
  (#wcRunTabs, .scope-switch.admin-subnav.wc-run-tabs: Battles, Map,
  Standings, Allegiances, Supply & Warpstone, Soft scores if any are on),
  one at a time (data-pane on #tournamentMapSection and
  #tournamentStandingsSection picks the part; the steps strip hides); it
  opens on Battles during a round, else Map. The round arrows (#tRoundTabs)
  sit in the box at the top; no title or "Swiss · points" line. The map
  shows every army's piece while a round is played or fixed (was counts),
  and the round in Old London over its corner (warcastleMapCaption). The
  "Amend scores" list is gone for every tournament (a battle's row in
  Battles opens it); Bonuses and penalties is a fold-out in Standings.
  PR 2: a battle's row (tournamentTablesHtml, every tournament) is each
  player's badge, name and army either side, the winner's side green, the
  loser's red, a draw's yellow, deeper for a bigger win
  (tournamentResultStrength: on WarCastle the matched play names, Marginal
  .35, Resounding .65, Crushing 1, by OFFICIAL_TP_BANDS at the points
  limit or 2,000; elsewhere the 20-0 scale, a point per 250 VP). A battle
  with a result (or a player's logged battle) opens read-only with Edit,
  which unlocks it and becomes Save. PR 3: Set up › Start
  (admin-wcstart, WarCastle before it starts): Ready to start
  (warcastleReadyItems: entrants locked, map set up, scenarios done, each
  with a button there; briefings sent = settings.setup.sent_at, Send goes
  to Tables' Finalise and send; quests sent = a switch, kept as
  settings.warcastle.quests_sent_at until quests are in the app; everyone
  checked in), the big Start (button.act.is-big, gold with .is-ready when
  all six are done; needs the first three, asks about the rest), then
  check-in for the entrants after the lock (campaign_member_admin
  checked_in_at, as Entrants' check-in before the lock). Entrants keeps
  Lock and Unlock; its Start button is hidden on WarCastle. Starting shows
  #wcBeginOverlay (the map drifting in the dark, embers, your badge, the
  event's name in gold, "Round 1 begins", To battle; reduced motion: still)
  and notifies players; other devices show it once (localStorage
  scriptorium.wcBegun.<campaign>) when Play next loads, or within 20
  seconds while the holding card is up (no realtime in the app). Tests
  mark it seen unless a world sets showBegin. The timer's (i) always has
  Round length (data-t-length, sets tournaments.round_minutes, for the
  round being played too), and during a round Time left and Pause; the
  box stays on WarCastle's tabs. PR 4 (migration 104, run by Grant 23 Oct):
  the end of a battle's Confirm & submit has Strategic objectives held at
  the end (a −/+ for you and your opponent) and Warpstone objective (You,
  them, No one); sent with warcastle_report_objectives once the battle is
  linked to its pairing (reportWarcastleObjectives). The battle result
  sheet (organiser) has the same, locked till Edit. The tokens (reason
  'battle', pairing_id) are given by the database once the pairing has a
  result and put right whenever either changes. Supply & Warpstone: a −
  and + for each player's Supply and Warpstone (corrections; +3 and the
  swap are gone), and Warpstone objectives: Draw for round N picks one of
  each table's objectives at random (its position from the table's
  builder layout markers), kept in settings.warcastle.warpstone_draw, to
  draw again with a confirm. Not browser-tested: the player's report (the
  fake database can't find the pairing a bypassed battle links to); the
  step itself was checked by hand. Waiting-room bypass now ignores a second
  tap (it started free play).
- Next: Play's drawn table to use the turned deployment; account photos for
  .player-icon; then the trackers once Grant has finalised them. Quests:
  claude/warcastle-quests (Open PRs); scoring them in the app is later.
  The war so far (fun narrative stats) is in the Backlog.

## Event builder plan (agreed with Grant, 19 Oct 2026)
- PR 1 (done, #96), builder shape: "Great for…" as a bullet on each type box; drop the
  saved-on-device, "choose the type…" and max-players notes; no type ticked
  at the start, numbered steps appear once one is picked; Blank removed, so
  the type sets the format and Format and rules has no format boxes;
  "Story pages"; Story sharing always on (no switch); Alliances step renamed,
  with an on/off switch on Format and rules (step only shows when on);
  Seasons instead of Phases for a League; scenarios as a short list per
  phase with "Add a scenario" instead of the long tick list; tournament
  pairings and points limit on Format and rules, number of rounds on Rounds;
  Invite and open unnumbered, after Create event.
- PR 2, differential scoring for tournaments (Grant to send references).
- PR 3, Square Based Comp with kill point modifiers (Grant to send links).
  The scenario builder already has a Square Based Comp composition option.
- PR 4 (done, #97), campaign points: on/off switch (off ranks by wins, draws, fewest
  losses and hides CP across the app), and custom result types including
  negative points for heavy defeats.
- PR 5 (done, #99), the scenario builder inside the event builder (new scenarios held
  until Create event, saved with the event; needs a migration).

## Admin console plan (tournament organiser; agreed with Grant, 19 Oct 2026)
Tournament tab bar becomes Home · Players · Set up · Run (Campaign tab
dropped for tournaments). PRs, in order where it matters (C before D, F
and E's soft-score entry):
- A, Home (done, #102): setup checklist alone until done or hidden; then a
  tournament card (top 3, current round, battles in progress, round timer;
  tap a tile for its detail); fun stats (models slain, biggest wins,
  baggage, cowards, factions); "Waiting on you" (was "Needs you"), hidden
  when empty. No migration.
- B, Players (done, #103; club field, under-18 flag and SBC tier picker moved to C/F,
  where they're used): invite (join code, link, QR, add a player); players list;
  lists review with per-player status and Checked, 500+ point unit flag;
  players set their Square Based Comp tier on Lists, organiser can correct
  it; lists lock and reveal; check-in on the day with "drop no-shows", then
  Lock entrants; drop out before lock (frees the slot) and withdraw after;
  waiting list (first in line gets a freed slot, notified); player notes;
  club field; under-18 flag. Migration.
- C, Set up, split in two. C1 (done, #104): tab, event details, round cards, battle type.
  C2 (done, #105): scoring, byes, tiebreaks, soft scores, Square Based Comp, club field.
  Not recorded per battle yet, so not offered as tiebreaks: secondary-objective
  VP and Generals slain. Soft score entry and Best Overall standings come in E.
  (was Scenarios): event details (date, start/finish and
  registration times, venue, address, Google Maps link, notes, max players,
  end/delete); normal battles or Battle March chosen in the event builder,
  filtering scenarios and the scenario builder; tournament summary;
  round cards (map, scenario, objectives; select existing or create/edit in
  the scenario builder overlay, editing a library scenario saves a copy;
  x to remove with "Are you sure? This will delete the round."; Add round);
  library link below. Scoring presets: official matched play (6-0, bands by
  points size, from tow.whfb.app), 20-0 (10-10, one step per 250 VP, 20-0 at
  2,500+), win/draw/loss with draw margin, custom. Byes (points; count as
  win, draw or neither). Tiebreaks (default official: total VP, secondary
  VP, Generals slain; also SoS, VP difference, head-to-head; reorderable).
  Final ranking Best General or Best Overall. Round 1 random or seeded;
  random or ranked tables; same-club and same-faction avoidance. Soft
  scores (painting, sportsmanship, favourite army) with weighting into
  Overall. Square Based Comp: editable tier table (extra points, kill point
  modifier: opponent's kill points x modifier), 500-point single unit or
  character limit (not the Arachnarok). Migration.
- D, Finalise and send (done, #106): Finalise is a soft lock (Unlock) and makes a
  player pack .docx; Send to players publishes to Play and notifies; never
  a hard lock, later changes notify players with what changed. Lists can be
  revealed only once lists are locked and set-up is sent. Migration.
  Also: the scenario editor, opened for an event, no longer asks type of
  battle, battle size or comp; they come from the event.
- D2, One scenario maker (done, no migration): Set up › Rounds (Create and
  Edit), the tournament scenario library and the event builder's "Build a new
  scenario" all open Play's scenario builder (openScenarioMaker), with the
  event's type of battle, points and comp fixed. Saved as an ordinary
  missions row, with the builder's own state in missions.terrain.builder, so
  it reopens as drawn and Play sets up the same table. The old form remains
  only for campaign libraries and platform admins' official scenarios.
- D3 (Grant: "any scenario building thing anywhere on Scriptorium should now
  use the scenario builder"): campaign libraries and official scenarios
  (platform admins, Official switch) moved over too, so the old scenario form
  is unreachable; its code (#missionWizard and helpers) deleted 23 Oct (#189).
  Event details: rows grouped (The event / Scoring and ranking / Pairings
  and extras), one-line values, an (i) on every row.
  Grant: type of battle, army size and comp are event-wide, never per round.
- E1 (Run, part one; migration 097): tournaments' Events tab is Run, with no
  game nights; Run opens on the tournament (no Scenarios step: that's Set up ›
  Rounds); rounds as swipeable cards with tabs (the round in play holds its
  controls; done rounds show results); a clock with Pause/Resume, +5 and +15
  min, everywhere the timer shows; Results › Score changes (audit trail).
  E2 (done, no migration): Best Overall standings (withBestOverall: each part
  as a share of the best in the field, weighted; soft scores entered by the
  organiser in Run › Results, kept in campaigns.settings.soft_results);
  printing (pairings, table sheets, standings) from a hidden frame; "Remind
  players" on the round in play (notify_event_players, 096, to everyone,
  naming the tables still to report); results picked in Run while offline
  wait in localStorage and send when back online; the battle log is a Run
  step for tournaments (moved from Players).
  To do (Grant, 20 Oct): the awards (best sportsman, best painted, best
  chronicler: campaign_awards and award_votes already exist) should be
  switched on ("checked on") by default rather than added by hand. Not
  doing: per-player reminders ("Remind players" to everyone is enough).
  Not doing: an automatic results deadline (Grant, 20 Oct).
  Phone check of Run done (20 Oct): numbers not ticks on the steps, the
  "what's next" box hidden where it repeats the round card, entrants'
  Withdraw in the ··· menu (asked first), battle log lines without empty
  parts and VP for tournaments, Delete in danger red, Needs your attention
  links to the battle log in Run.
  Rounds reworked (Grant, 20 Oct): the clock sits in the bar at the top
  while a round's played (the round named there only on other steps);
  the round strip is ‹ Round 2 of 3 › arrows (.deck-nav); the tables are
  the card (alternate rows shaded, result under the names), and tapping one
  opens the amend overlay (result-only changes still wait offline); a round
  not started is just its match-ups (two dropdowns and a × each), its
  scenario left to Set up; Print and the rarely used fold away. No Edit
  details in a tournament event's Run (it's in Set up); the status chip
  hides while a round's played. Then (Grant): the timer's − / + 5 min (.wound-btn) and Pause / Resume (before a round, the same − / + sets round_minutes)
  live in the (i) pop-out at the bar's top right; the round switcher sits
  under the card and its ends go on to the steps either side (‹ Entrants,
  Results ›), replacing the step's Back / Next on Rounds. Then (Grant):
  each table opens its score overlay (scores filled in, its battle's
  status and dispute reason shown, a › on the row), so a tournament has
  no Battle log step; disputed / quiet battles in Needs your attention go
  to Rounds. Possible follow-up: saving a disputed table could also settle
  its battle (admin_resolve_game) so it leaves Needs your attention.
  Then (Grant): the score overlay shows each side's VP element by element
  (Units destroyed, plus each objective on for the table's scenario, and
  Other for anything unaccounted), editable, totals live. Needs 099 (PR
  waiting on Grant): stores each battle's breakdown and the organiser's
  corrections (vp_detail). Before 099 / for older battles the whole total
  sits in Other. 099 run (Grant). Then: with Square Based Comp on, each side
  has a Tier picker (set_sbc_tier on save: the army's tier, every battle)
  and "After X's tier (× k)" with the modified total; the modifier stays on
  the whole VP, as the standings apply it (Grant). SBC tiers are A to D (Grant):
  choosing Square Based Comp starts with A, B, C, D (extra 0, × 1, for the
  organiser to fill in), fixed: no adding, removing or renaming. Tiers only show
  anywhere when the comp is Square Based Comp. Saving a disputed table also
  settles its battle (admin_resolve_game: confirmed, result from its
  logger's side), so it leaves Needs your attention; the knockout "result
  is decided" line is gone (Grant).
- Storytelling (Grant, 20 Oct): happy with it as is; two additions, done:
  a formatting toolbar (Bold, Italic, Heading, List, Quote, Photo; Ctrl/⌘+B
  and I) with Write / Preview, and photos: a cover photo picker (was an
  image URL) and photos in the story (uploaded to the organiser's own
  chronicle-photos folder, written as ![photo](story:{uid}/story-{n}.webp)).
  storyBodyHtml renders headings, lists, quotes and photos (own storage only).
- E, Run (was Events): swipeable round cards (start round, timer with
  pause/add time, pairings and swaps, results, amend score, penalties, end
  round); battle log; score audit trail; printables (pairings, table
  sheets, scoresheets, standings); offline results queue; results deadline
  nudges; soft score entry. Game nights screen goes for tournaments (date
  and venue live in Set up). Migration.
- F, Public pages: shareable event page (details, map link, format, points,
  comp, spaces left, scenarios once sent, notes, Join button with code and
  QR); opt-in names on it; opt-in public player profiles (factions, avatar,
  unit photos, awards, events); under-18 never public; per-photo hiding.
  Off until the organiser switches it on. Migration.
- G, Data and export: Delete my account (name becomes "Former player" in
  results); results export for Old World Rankings. Migration.
- Not doing for now: Old World Rankings' Battle March scoring template.
- Campaign/league parity (Grant, 19 Oct: "duplicate what we have here" for
  league and campaign; a round/phase can be a one-day tournament that opens
  the tournament editor inside the campaign, rather than shoe-horning it in;
  storytelling improvements to discuss on 20 Oct):
  - C1 (no migration): nav for campaigns is Home · Players · Set up (Event
    details | Phases | Scenarios) · Run (Phases | Game nights | Tournaments)
    · Story. Phases (a league's seasons) are swipeable cards in Set up (their
    scenarios with drawn maps; add existing, Create scenario in Play's
    builder, Edit, take out; Edit phase, move, delete) and in Run (how it's
    going; Start, Finish with rank perks). Awards moved to Run › Phases.
    Shared helper drawSwipeCards for card strips.
  - C2 (done, no migration): Finalise and send for campaigns: the section sits
    under Set up › Phases; the pack and Play card list phases (seasons) with
    their scenarios and maps, campaign points and Path to Glory; finalising
    locks the phase cards too.
  - C3 (migration 098): a phase can be a tournament day: "Make it a tournament
    day" on its Set up card gives it a tournament of its own
    (tournaments.phase_id); its cards in Set up and Run say so and open the
    tournament editor (Run › Tournaments); a campaign holding any
    tournament shows the Scoring and Pairings cards in Event details.

## Players tab (agreed with Grant, 20 Oct 2026)
- P1 (no migration): the tab is Invite · Players · Alliances (Alliances in
  its own section, not for tournaments). Players is a summary and a button
  (or a search) opening the players overlay: everyone, with filters
  (set up, played this phase, alliance, faction, list status), sort, the
  row menu (View as player lives only there), each player's list (status,
  500+ flags, tier, List checked) and View list (the read-only unit card
  viewer), ticking several, and CSV export of what's shown. Lock and Reveal
  lists moved to Set up (above Finalise and send). Battles in progress and
  the battle log moved to Run (a campaign's Run › Battles; a tournament's
  Battle log step). A tournament's check-in moved to Run › Entrants;
  campaigns and leagues have none.
- P2 (done, no migration): Chart view in the overlay: a measure (battles,
  wins, campaign points, list points, players) across, by faction, alliance
  or player down, as a total or average, of whoever the filters leave;
  hover/focus tooltips; Pin to Home (up to six, everyone counted), with
  Unpin, kept in campaigns.settings.dashboard_charts.
- P3 (no migration): Find a player is a lookup (names drop down as you
  type; the one chosen shows as a card under it, with the same actions);
  "Detail view" opens the overlay. Filters: Faction, then Army type (from
  the list file: Grand Army, or the Army of Infamy / Renegade / Legacy
  composition). Charts: Bars, Columns or Donut (totals only), coloured by
  faction (or alliance) or one colour. Buttons app-wide are ovals, filled,
  with a shadow (secondary a softer fill; never just an outline).
- P4 (no migration): charts over time (By: Week): battles, wins or campaign
  points each week or as a running total, one line or a line per faction or
  alliance (confirmed battles, both sides, from games.played_on; last 26
  weeks; crosshair tooltip). Faction bars of totals are split into their
  army types (Grand Army in the faction's colour, each other in a lighter
  shade, no list palest), unless the army type is filtered to one.
- P5 (no migration): chart data points (chips with × and a + to add:
  Everyone, a player, a faction, an army type in its faction, an alliance;
  each a bar, or a line over time; none = everyone by "By") and a From/To
  date range (battle measures counted from confirmed battles in range).
  Pins keep both.
- Later: game night check-in (ticks for bookings on the night, paid flag;
  needs a column on bookings).

## Conventions (Grant)
- Maps: only ever show the scenario builder's drawn maps (ownDeploymentMap
  with deploymentThumbSvg). Uploaded map images are old, kept for reference
  only, and never shown as a scenario's map.

## Grant's to-dos
- Google sign-in: paste the Google OAuth client ID into GOOGLE_CLIENT_ID,
  and add https://thescriptorium.co to its Authorised JavaScript origins in
  Google Cloud (Credentials). Optional: app name and logo in Google's
  Branding page.
- Check Netlify billing/usage; consider turning off deploy previews.

- Room around "Leave this battle" (Grant, 26 Oct; no migration), merged as #211: on Play's waiting screens the button rows had only a word space between them. They now lay out with a 1rem gap; on "Waiting for your opponent", Leave sits on its own line under "start anyway" (as on the who-goes-first and hold screens), and all three Leave buttons are the danger button (.mini-btn.adm-danger). Checks: tests/browser/sim-paths.cjs. The danger red is only a little darker than the panel on the red themes (Empire, Khorne, Vampire Counts); Grant is fine with that for now (26 Oct).

## Decisions waiting on Grant
- Hallowed Ground, Looting & Pillaging and War in the Shadowlands are
  44" x 30" in their own rules, so they're drawn and set up on that table
  (like Battle March), not 72" x 48". Change if you'd rather full size.
- Clash at Sturdham's map labels the hamlet 20" x 18", which can't fit
  between zones 15" apart; it's drawn 20" x 12" as the picture shows.
- Should grudges settle automatically when a battle is confirmed?
- Should award winners be locked once given?

## Backlog
- Keyboard focus may sit under the fixed bars on a phone (noticed 30 Oct, fixing sim.cjs; not tried by hand): nothing sets scroll-padding, so a control tabbed to near the bottom or top could be scrolled into view under the tab bar (#playerTabBar) or the masthead. A fix would be scroll-padding on html for the bars' heights. Not started.
- Merge the duplicate controls listed under "Still to merge" in CLAUDE.md
  (UI components), then delete the old classes. No migration. Also delete
  the unused folder-tab look in the base .tab-btn rules (Grant, 20 Oct: the
  icon bar everywhere, which both phone and wide screens already show).
- Move hosting from Netlify to GitHub Pages (CNAME is already in the repo).
- Team tournaments.
- Player home screen.
- Public events list.
- "See it as a player" preview for organisers.
- Clear stale drafts.
- "Learn to use" overlay.
- Contact Old World Rankings.
- Game night admin booking rows are still busy; tidy them.
- WarCastle's war so far: fun narrative stats (alliance on the up, biggest
  slaughter; not called standings). Its holding-card tile was dropped
  (Grant, 28 Oct); somewhere else for it if it's wanted.

## Testing tips
- Scoring simulations (Grant, 23 Oct, after #188): `node tests/vp/fuzz.mjs [runs] [seed]`
  runs random scenarios, armies, marks and entries through the real
  scoring (totals add up, the rules' limits hold, a battle reopens at its
  score; a deliberately broken rule fails it at once).
  `tests/browser/sim.cjs [battles] [seed]` plays random battles through the
  page and checks the card, Finalise, the logged battle and the organiser's
  Edit agree; `tests/browser/sim-paths.cjs` covers the accepting player and
  "start anyway". 25,000 fuzz runs and 15 random battles clean, 23 Oct; the
  one problem found (the organiser's battle list not refreshed on entering
  admin) fixed.
- Unit tests: `for f in tests/*/run.mjs; do node "$f"; done`
- Browser checks: Playwright with Chromium at /opt/pw-browsers/chromium,
  stubbing Supabase. tests/browser/ has a fake Supabase (fake-supabase.mjs,
  an in-memory database) and app.cjs to open the real index.html with a
  world of rows; serve the repo root on 8765, then
  `NODE_PATH=$(npm root -g) node tests/browser/warcastle.cjs` (also
  scoring.cjs: a two-player battle from one side, the other played by
  writing to the fake database).
