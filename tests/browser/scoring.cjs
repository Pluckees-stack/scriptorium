// Two-player battle scoring, from one player's side (Alice), with the
// other player (Bob) played by writing to the fake database:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/scoring.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

const general = { command: [{ active: true, name_en: 'General' }] };
const unit = (id, rosterId, name, points, wargear = {}) => ({ id, roster_id: rosterId, name, category: 'core', size: 1, points, experience: 0, status: null, archived_at: null, wargear, current_wounds: null });
function world() {
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }, { id: 'b', display_name: 'Bob' }],
      campaign_members: [
        { user_id: 'a', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true },
        { user_id: 'b', campaign_id: 'c1', role: 'player', faction_id: 'skaven', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }, { id: 'skaven', name: 'Skaven' }],
      rosters: [{ id: 'ra', player_id: 'a', campaign_id: 'c1', faction_id: 'empire-of-man', name: 'Alice list', points_limit: 2000 },
        { id: 'rb', player_id: 'b', campaign_id: 'c1', faction_id: 'skaven', name: 'Bob list', points_limit: 2000 }],
      units: [unit('a1', 'ra', 'Captain', 100, general), unit('a2', 'ra', 'Halberdiers', 200),
        unit('b1', 'rb', 'Warlord', 100, general), unit('b2', 'rb', 'Clanrats', 200), unit('b3', 'rb', 'Slaves', 100), unit('b4', 'rb', 'Rats', 100)],
      missions: [{ id: 'm1', campaign_id: 'c1', name: 'Open field', mode: 'normal', turn_limit: 6, random_length: false,
        common_objectives: ['king-is-dead', 'breaking-the-enemy'], secondary_objectives: [{ key: 'baggage-trains' }, { key: 'strategic-locations', count: 3 }], objective_vp: {}, custom_objective_ids: [], game_sizes: ['2000-2499'] }],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
    // what's logged, kept to check the VP
    rpcSource: `{ log_game_with_xp: (args, db) => { window.__lastLogged = args.p_game; db.games.push({ ...args.p_game, id: 'g1' }); return { data: 'g1', error: null }; } }`,
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };
const db = (page, fn, arg) => page.evaluate(([f, a]) => new Function('db', 'a', `return (${f})(db, a)`)(window.__FAKE_DB, a), [fn.toString(), arg]);

async function toMission(page) {
  await page.click('.tab-btn[data-tab="game"]');
  await page.click('#startGameBtn');
  await page.waitForSelector('#gameStageOpponent:not(.hide)');
  await page.waitForFunction(() => document.querySelectorAll('#gameOpponentSelect option').length > 1);
  await page.selectOption('#gameOpponentSelect', 'b');
  await page.click('#opponentContinueBtn');
  await page.waitForSelector('#gameStageMission:not(.hide)');
  await page.waitForFunction(() => document.querySelector('#gameMissionSelect option[value="m1"]'));
}
async function intoBattle(page) {
  await toMission(page);
  await page.selectOption('#gameMissionSelect', 'm1');
  await page.click('#missionContinueBtn');
  await page.waitForSelector('#gameStageWaiting:not(.hide)');
  // accepted, with the columns' own defaults (the fake has none)
  await db(page, (d) => Object.assign(d.game_invites[0], { status: 'accepted', active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0 }));
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  await page.click('#spellsContinueBtn');
  await db(page, (d) => { d.game_invites[0].to_ready_at = new Date().toISOString(); });
  await page.waitForSelector('#gameStagePick:not(.hide)', { timeout: 15000 });
  await page.click('#pickSelfBtn');
  await page.waitForSelector('#gameStagePlaying:not(.hide)');
  await page.waitForTimeout(800);
}

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

  // 1. a scored battle needs a scenario
  let page = await openApp(browser, world());
  await toMission(page);
  await page.click('#missionContinueBtn');
  check(await page.isVisible('#gameMissionErr') && /Choose a scenario or build one/.test(await page.textContent('#gameMissionErr')), 'no scenario: asked to choose or build one');
  check(!(await db(page, (d) => d.game_invites.length)), 'no scenario: no request sent');
  await page.close();

  // 2. a full battle: turns, the running total, the end-of-battle cards, logged by one player
  page = await openApp(browser, world());
  await intoBattle(page);
  check(await page.getAttribute('#gameStrategicLocationsInput', 'max') === '3' && await page.getAttribute('#gameStrategicLocationsOppInput', 'max') === '3', 'markers: both sides, capped at the scenario’s 3');
  check(await page.isVisible('#gameRunningTotal'), 'running total shown in play');
  // end of Alice's turn: she holds 2, Bob 1, and both score
  await page.click('[data-strat-for="gameStrategicLocationsInput"][data-strat-by="1"]');
  await page.click('[data-strat-for="gameStrategicLocationsInput"][data-strat-by="1"]');
  await page.click('[data-strat-for="gameStrategicLocationsOppInput"][data-strat-by="1"]');
  await page.click('#gameNextTurnBtn');
  await page.waitForTimeout(600);
  const inv1 = await db(page, (d) => d.game_invites[0]);
  check(inv1.strategic_vp_from_user === 60 && inv1.strategic_vp_to_user === 30, `end of Alice's turn banks both sides (${inv1.strategic_vp_from_user} / ${inv1.strategic_vp_to_user}, want 60 / 30)`);
  check(await page.isDisabled('#gameStrategicLocationsInput'), 'markers locked on Bob’s turn');
  // Bob ends his turn: Alice still holds 2, he holds 1
  await db(page, (d) => Object.assign(d.game_invites[0], { strategic_vp_from_user: 120, strategic_vp_to_user: 60, active_slot: 'first', current_round: 2 }));
  // Alice's Captain wiped on her tracker; Bob's Warlord on his
  await page.evaluate(() => { const b = [...document.querySelectorAll('#rostersGame .wound-btn[data-action="dec"]')].find(x => x.dataset.unitId === 'a1'); for (let i = 0; i < 10 && b; i++) b.click(); });
  await db(page, (d) => { d.units.find(u => u.id === 'b1').current_wounds = 0; });
  await page.waitForTimeout(3800);
  const running = (await page.textContent('#gameRunningTotals')).replace(/\s+/g, ' ');
  // Alice: Warlord 100 + King 100 + 120; Bob: Captain 100 + King 100 + 60
  check(/Alice\s*320\s*VP\s*Bob\s*260\s*VP/.test(running) && /Alice has the upper hand|favours Alice|Alice is pulling ahead|Alice holds the advantage/.test(running), `running total: Alice leads 320–260 (${running.trim()})`);
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEnd:not(.hide)');
  await page.waitForSelector('#vp-player-units-n');
  check(await page.$$eval('#endCardTabs [data-swipe]', xs => xs.length) === 4, 'end of battle: four cards');
  check(await page.$eval('#opponentUnitsList .seg-btn[data-unit-id="b1"][data-v="dead"]', b => b.classList.contains('on')), 'Bob’s Warlord starts as dead');
  // Path to Glory off: no kill credits, so no killer to pick
  const deadBtn = await page.textContent('#opponentUnitsList .seg-btn[data-unit-id="b1"][data-v="dead"]');
  const deadLine = await page.textContent('#opponentUnitsList .status-line').catch(() => '');
  check(deadBtn === 'Killed' && !(await page.$('.killed-by-select')) && /^Warlord\b/.test(deadLine) && !/ by /.test(deadLine), `Path to Glory off: "Killed", no picker, a line naming no killer (${deadBtn}; ${deadLine})`);
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="fled"]');
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b3"][data-v="fled"]');
  await page.click('#endCardTheirs [data-end-go="1"]');
  await page.waitForTimeout(700);
  check(await page.$eval('#ownUnitsList .seg-btn[data-unit-id="a1"][data-v="dead"]', b => b.classList.contains('on')), 'your Captain, wiped on your tracker, starts as dead');
  await page.click('#endCardOwn [data-end-go="2"]');
  await page.waitForTimeout(700);
  const sections = await page.$$eval('#vpTable details', ds => ds.map(d => ({ open: d.open, keys: [...new Set([...d.querySelectorAll('.vp-cell[data-vp-key]')].map(c => c.dataset.vpKey))] })));
  check(sections[0].open && ['units', 'king-is-dead', 'breaking-the-enemy', 'baggage-trains', 'strategic-locations'].every(k => sections[0].keys.includes(k)), 'This scenario: open, with its five elements (' + sections[0].keys.join(', ') + ')');
  check(!sections[1].open && ['trophies-of-war', 'special-feature', 'domination', 'other'].every(k => sections[1].keys.includes(k)) && !sections[1].keys.includes('baggage-trains'), 'Other points: closed, with the rest (' + sections[1].keys.join(', ') + ')');
  check(await page.isChecked('#vp-player-breaking') && await page.isChecked('#vp-player-kingIsDead') && await page.textContent('#vp-player-strategicHeld') === '4' && await page.textContent('#vp-opponent-strategicHeld') === '2' && /120 VP/.test(await page.textContent('#vp-player-strategic-locations-n')), 'worked out: Breaking the Enemy and King is Dead ticked, Strategic Locations held 4 (120 VP) and 2');
  // 3 markers × 12 turns between the two: Bob's 2 leave Alice 34
  for (let i = 0; i < 30; i++) await page.click('#vp-player-strategicHeld-up');
  check(await page.textContent('#vp-player-strategicHeld') === '34' && await page.isDisabled('#vp-player-strategicHeld-up') && await page.isDisabled('#vp-opponent-strategicHeld-up'), 'Strategic Locations: 36 between the two (3 markers × 12 turns)');
  for (let i = 0; i < 30; i++) await page.click('#vp-player-strategicHeld-dn');
  // units: a total, the units in a pop-up, Edit back to their card
  check(/^400 VP$/.test(await page.textContent('#vp-player-units-n')) && !(await page.$('#vp-player-unitsVp')), 'units: just the total (400 VP), no box');
  await page.click('[data-vp-units="player"]');
  const unitsPop = await page.textContent('#vpUnitsOverlay');
  check(await page.isVisible('#vpUnitsOverlay') && /Alice: units destroyed/.test(unitsPop) && /Warlord, destroyed\s*100 VP/.test(unitsPop) && /Clanrats, fled\s*200 VP/.test(unitsPop), 'Show units: each unit that scored, its status and VP');
  await page.click('#vpUnitsEditBtn'); await page.waitForTimeout(700);
  check(await page.isHidden('#vpUnitsOverlay') && await page.getAttribute('#endCardTheirsTab', 'aria-selected') === 'true', 'Edit: back to Their units');
  await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(500);
  await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(700);
  check(await page.textContent('#vp-player-baggageHeld') === '0' && !(await page.isChecked('#vp-player-baggageDestroyed')), 'baggage: none held, the enemy’s not destroyed');
  await page.click('label:has(#vp-player-breaking)');
  check(!(await page.isChecked('#vp-player-breaking')) && /^0 VP$/.test(await page.textContent('#vp-player-breaking-the-enemy-n')), 'Breaking the Enemy switched off: 0 VP');
  await page.click('#vp-player-baggageHeld-up'); await page.click('#vp-player-baggageHeld-up');
  check(/200 VP/.test(await page.textContent('#vp-player-baggage-trains-n')) && await page.isDisabled('#vp-player-baggageHeld-up') && await page.isDisabled('#vp-opponent-baggageHeld-up'), 'both baggage trains held: 200 VP, and none left for Bob');
  await page.click('label:has(#vp-player-baggageDestroyed)');
  check(await page.textContent('#vp-player-baggageHeld') === '1' && /350 VP/.test(await page.textContent('#vp-player-baggage-trains-n')), 'the enemy’s train destroyed: one left to hold, 100 + 250 = 350 VP');
  await page.click('label:has(#vp-player-baggageDestroyed)'); await page.click('#vp-player-baggageHeld-dn');
  await page.click('#vpTable details:nth-of-type(2) summary');
  await page.waitForTimeout(400); // the card grows to fit what's opened
  await page.click('#vp-player-standards-up'); await page.click('#vp-player-standards-up');
  check(/100 VP/.test(await page.textContent('#vp-player-trophies-of-war-n')), 'two standards counted: 100 VP');
  await page.click('#vp-player-standards-dn'); await page.click('#vp-player-standards-dn');
  // Domination: double strength or uncontested, never both; four quarters between the two
  await page.click('#vp-player-domQuarters-up'); await page.click('#vp-player-domQuarters-up');
  await page.click('#vp-player-domDouble-up'); await page.click('#vp-player-domUncontested-up');
  check(await page.isDisabled('#vp-player-domDouble-up') && await page.isDisabled('#vp-player-domUncontested-up'), 'Domination: 2 quarters, 1 double strength and 1 uncontested, no more of either');
  await page.click('#vp-opponent-domQuarters-up'); await page.click('#vp-opponent-domQuarters-up');
  check(await page.isDisabled('#vp-opponent-domQuarters-up') && await page.isDisabled('#vp-player-domQuarters-up'), 'Domination: four quarters between the two sides');
  await page.click('#vp-player-domQuarters-dn');
  check(await page.textContent('#vp-player-domUncontested') === '1' && await page.textContent('#vp-player-domDouble') === '0' && /200 VP/.test(await page.textContent('#vp-player-domination-n')), 'one quarter fewer: the bonuses come down with it (1 quarter, uncontested: 200 VP)');
  for (const id of ['vp-player-domQuarters-dn', 'vp-opponent-domQuarters-dn', 'vp-opponent-domQuarters-dn']) await page.click('#' + id);
  await page.fill('#vp-player-otherVp', '25'); await page.press('#vp-player-otherVp', 'Tab');
  check(/645/.test(await page.textContent('#vpTotal-player')), 'your total follows what’s entered (645)');
  // back to the battle and End battle again: marks and figures kept
  await page.click('#endBackBtn');
  await page.waitForSelector('#gameStagePlaying:not(.hide)');
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEnd:not(.hide)');
  await page.waitForSelector('#vp-player-units-n');
  check(await page.$eval('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="fled"]', b => b.classList.contains('on')) && !(await page.isChecked('#vp-player-breaking')), 'going back keeps the marks and entries');
  await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(500);
  await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(500);
  await page.click('#endCardVp [data-end-go="3"]'); await page.waitForTimeout(700);
  const final = await page.textContent('#vpTally');
  check(/Victory for Alice/.test(final) && /Alice\s*645\s*VP\s*Bob\s*260\s*VP/.test(final), 'Finalise: the winner as the headline, then the scores in columns (' + final.slice(0, 60).replace(/\s+/g, ' ') + '…)');
  await page.click('#lgBtn');
  await page.waitForTimeout(5500);
  const game = await db(page, (d) => ({ games: d.games.length, inv: d.game_invites[0] }));
  const rpcs = await page.evaluate(() => window.__FAKE_LOG.filter(x => x[0] === 'rpc').map(x => x[1]));
  check(rpcs.includes('log_game_with_xp'), 'logged straight away with log_game_with_xp (no waiting for the opponent)');
  check(game.inv.submitter_id === 'a' && game.inv.status === 'completed', 'request claimed by Alice and closed');
  // Alice: Warlord 100 + Clanrats 200 + Slaves 100 + King 100 + Strategic 120 + Other 25 = 645
  // Bob: Captain 100 + King 100 (Alice's General) + Strategic 60 = 260
  const logged = await page.evaluate(() => window.__lastLogged);
  check(!!logged, 'a battle was logged');
  if (logged) check(logged.player_vp === 645 && logged.opponent_vp === 260, `VP logged ${logged.player_vp}–${logged.opponent_vp} (want 645–260)`);
  if (logged) check(logged.kill_credits == null && logged.opponent_kill_credits == null, 'Path to Glory off: no kill credits sent');
  // each side's units line keeps the whole army it scored against, as it ended
  const armyOf = (bd) => (bd || []).find(x => x.key === 'units')?.entries?.units?.map(u => `${u.id}:${u.status}:${u.points}${u.general ? ':g' : ''}`).join(' ');
  if (logged) check(armyOf(logged.player_breakdown) === 'b1:dead:100:g b2:fled:200 b3:fled:100 b4:null:100' && armyOf(logged.opponent_breakdown) === 'a1:dead:100:g a2:null:200',
    `both armies saved with every unit's status (${armyOf(logged.player_breakdown)} / ${armyOf(logged.opponent_breakdown)})`);
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 2b. Path to Glory on: "Killed by…", the picker and kill credits
  const wp = world();
  wp.db.campaigns[0].path_to_glory_enabled = true;
  page = await openApp(browser, wp);
  await intoBattle(page);
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEnd:not(.hide)');
  await page.waitForSelector('#opponentUnitsList .seg-btn[data-unit-id="b2"]');
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="dead"]');
  check(await page.textContent('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="dead"]') === 'Killed by\u2026' && !!(await page.$('.killed-by-select[data-unit-id="b2"]')) && !(await page.$('#opponentUnitsList .status-line')),
    'Path to Glory on: "Killed by…" opens the picker, the line waits for the killer');
  await page.selectOption('.killed-by-select[data-unit-id="b2"]', 'a2');
  const ptgLine = await page.textContent('#opponentUnitsList .status-line').catch(() => '');
  check(/Clanrats.*Halberdiers/.test(ptgLine), `the line names the killer (${ptgLine})`);
  await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(500);
  await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(500);
  await page.click('#endCardVp [data-end-go="3"]'); await page.waitForTimeout(700);
  await page.click('#lgBtn');
  await page.waitForTimeout(5500);
  const loggedPtg = await page.evaluate(() => window.__lastLogged);
  check(!!loggedPtg && JSON.stringify(loggedPtg.kill_credits) === JSON.stringify([{ unitId: 'a2', amount: 1 }]) && loggedPtg.opponent_kill_credits == null && loggedPtg.player_vp === 200,
    'Path to Glory on: kill credits sent (' + (loggedPtg ? JSON.stringify(loggedPtg.kill_credits) + ', ' + loggedPtg.player_vp + ' VP' : 'nothing logged') + ')');
  check(!page.errors.length, 'no page errors (Path to Glory on)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 2c. free play with no opponent here, tracked to the end: your own score
  // (your units destroyed as a figure), the opponent's side greyed out
  page = await openApp(browser, world());
  await page.click('.tab-btn[data-tab="game"]');
  await page.click('#freePlayBtn');
  await page.waitForSelector('#gameStageOpponent:not(.hide)');
  await page.click('#noOpponentBtn');
  await page.waitForSelector('#gameStageMission:not(.hide)');
  await page.click('#missionContinueBtn');
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  await page.click('#spellsContinueBtn');
  await page.waitForSelector('#gameStagePick:not(.hide), #gameStagePlaying:not(.hide)', { timeout: 15000 });
  if (await page.isVisible('#gameStagePick')) await page.click('#pickSelfBtn');
  await page.waitForSelector('#gameStagePlaying:not(.hide)');
  await page.evaluate(() => { window.confirm = (m) => /end the game/.test(m); });
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEnd:not(.hide)');
  await page.waitForTimeout(700);
  const soloTabs = await page.$$eval('#endCardTabs [data-swipe]', xs => xs.map(x => x.textContent.replace(/^\d+/, '')));
  check(soloTabs.join(',') === 'Victory points,Finalise', 'no opponent: no armies to mark, just Victory points and Finalise (' + soloTabs.join(', ') + ')');
  check(await page.isVisible('#vp-player-unitsVp') && !(await page.$('[data-vp-units]')) && !(await page.$('#vpTotal-opponent')) &&
    await page.$$eval('#vpTable .vp-cell.is-right', cs => cs.length > 0 && cs.every(c => c.classList.contains('is-nil') && !c.querySelector('input, button'))),
    'Victory points: your units destroyed a figure; the opponent\'s side greyed out, nothing to enter');
  // the strip settled on the card (cards out of view are inert)
  await page.waitForFunction(() => !document.getElementById('endCardVp').inert && Math.abs(document.getElementById('endCardTrack').scrollLeft - document.getElementById('endCardVp').offsetLeft) < 3);
  await page.fill('#vp-player-unitsVp', '600'); await page.press('#vp-player-unitsVp', 'Tab'); await page.waitForTimeout(300);
  check(/600/.test(await page.textContent('#vpTotal-player')), 'the figure counts (600)');
  await page.click('#endCardVp [data-end-go="3"]'); await page.waitForTimeout(700);
  const soloFinal = (await page.innerText('#vpTally')).replace(/\s+/g, ' ');
  check(/Alice 600 VP Opponent –/.test(soloFinal) && !/Victory|Honours/.test(soloFinal) && !(await page.textContent('#lgDerivedResult')), 'Finalise: your VP, no result (' + soloFinal + ')');
  await page.fill('#lgNotes', 'Solo practice');
  await page.click('#lgBtn'); await page.waitForTimeout(1500);
  const fp = await db(page, (d) => d.free_play_log[0]);
  check(!!fp && fp.user_id === 'a' && fp.player_vp === 600 && fp.notes === 'Solo practice' && fp.player_breakdown?.[0]?.key === 'units' && fp.result === undefined && fp.opponent_vp === undefined,
    'kept with the free play battle: your VP and its breakdown (' + JSON.stringify(fp && { a: fp.player_vp, n: fp.notes }) + ')');
  const rpcsSolo = await page.evaluate(() => window.__FAKE_LOG.filter(x => x[0] === 'rpc').map(x => x[1]));
  check(!rpcsSolo.includes('log_game_with_xp') && await page.isVisible('#gameStageStart'), 'never scored: no campaign battle logged, back to the start');
  await page.waitForTimeout(800);
  const fpCard = (await page.innerText('#battleLog')).replace(/\s+/g, ' ');
  check(/You played a free play battle/.test(fpCard) && /600 VP · Not counted toward the campaign/i.test(fpCard), 'battle log: the free play battle with your VP (' + fpCard.slice(0, 160) + ')');
  check(!page.errors.length, 'no page errors (free play, no opponent)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 3. Bob logs first while Alice is still playing
  page = await openApp(browser, world());
  await intoBattle(page);
  await db(page, (d) => { d.game_invites[0].staged_game_id = 'g9'; d.game_invites[0].submitter_id = 'b'; });
  await page.waitForSelector('#gameStageStart:not(.hide)', { timeout: 8000 }).catch(() => {});
  check(await page.isVisible('#gameStageStart'), 'opponent logged: back to the start');
  check(/Bob has logged this battle/.test(await page.textContent('body')), 'opponent logged: told so');
  await page.close();

  // 4. a scenario built on the scenario step scores by its own objectives
  page = await openApp(browser, world());
  await toMission(page);
  await page.click('#buildScenarioBtn');
  await page.waitForSelector('#battlefieldOverlayDone', { state: 'visible' });
  await page.click('#battlefieldOverlayDone');
  await page.waitForTimeout(500);
  await page.click('#missionContinueBtn');
  await page.waitForTimeout(800);
  const built = await db(page, (d) => d.game_invites[0]?.battle_setup?.mission || null);
  check(!!built && built.name === 'Own scenario' && Array.isArray(built.common_objectives), 'built scenario goes with the request' + (built ? ` (${built.common_objectives.join(', ')})` : ''));
  await page.close();

  // 5. Bob, later: the battle Alice logged, with its scoring, to confirm or dispute
  const wb = world();
  wb.session.user = { id: 'b', email: 'b@example.com', user_metadata: {} };
  wb.db.games.push({ id: 'g1', campaign_id: 'c1', player_id: 'a', opponent_id: 'b', result: 'win', campaign_points: 3, opponent_campaign_points: 1,
    player_vp: 635, opponent_vp: 230, confirmation_status: 'pending', played_on: '2026-10-22',
    player_breakdown: [{ key: 'breaking-the-enemy', label: 'Breaking the Enemy', vp: 500 }], opponent_breakdown: [{ key: 'units', label: 'Captain — destroyed', vp: 100 }] });
  page = await openApp(browser, wb);
  await page.waitForSelector('#battleLog [data-action="confirm-game"]', { state: 'attached', timeout: 10000 }).catch(() => {});
  const logText = await page.textContent('#battleLog');
  check(/you 230 VP, them 635 VP/.test(logText) && /Breaking the Enemy\s*500 VP/.test(logText), 'battle log: VP and scoring shown to confirm or dispute');
  check(!page.errors.length, 'no page errors (battle log)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 6. the organiser puts a logged battle right, on the same card
  const wo = world();
  wo.db.campaign_members[0].role = 'organiser';
  wo.db.games.push({ id: 7, campaign_id: 'c1', player_id: 'a', opponent_id: 'b', result: 'win', campaign_points: 3, opponent_campaign_points: 1,
    player_vp: 500, opponent_vp: 100, confirmation_status: 'confirmed', played_on: '2026-10-22', mission_id: 'm1', scenario: 'Open field',
    player_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 300, detail: ['Warlord, destroyed: 100', 'Clanrats, fled: 200'], entries: { unitsVp: 300 } }, { key: 'king-is-dead', label: 'King is Dead', vp: 100, entries: { kingIsDead: true } },
      { key: 'baggage-trains', label: 'Baggage Trains', vp: 100, entries: { baggageHeld: 1, baggageDestroyed: false } }],
    opponent_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 100, entries: { unitsVp: 100 } }] });
  wo.rpcSource = `{ admin_log_manual_game: (args) => { window.__manualGame = args.p_game; return { data: 1, error: null }; } }`;
  page = await openApp(browser, wo);
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  await page.evaluate(() => document.querySelector('#adminGameLog [data-action="game-edit"][data-id="7"]').click()); await page.waitForTimeout(600);
  await page.click('#flowTab1'); await page.waitForTimeout(500);
  check(await page.isChecked('#gedit-player-kingIsDead') && await page.textContent('#gedit-player-baggageHeld') === '1' && /500/.test(await page.textContent('#geditTotal-player')) && /100/.test(await page.textContent('#geditTotal-opponent')),
    'Edit a battle: its score on the players\' card, as it was entered');
  // from before armies were kept: its units as written, nothing to re-mark, its old total
  check(!(await page.$('#gedit-player-unitsVp')) && /300 VP/.test(await page.textContent('#gedit-player-units-n')), 'units: the total and Show units, no figure to type');
  await page.click('#gameEditScores [data-vp-units="player"]'); await page.waitForTimeout(400);
  const oldPop = (await page.innerText('#vpUnitsBody')).replace(/\s+/g, ' ');
  check(await page.isVisible('#vpUnitsOverlay') && /Warlord, destroyed 100 VP/.test(oldPop) && /Clanrats, fled 200 VP/.test(oldPop) && !(await page.$('#vpUnitsBody .seg-btn')) && await page.isHidden('#vpUnitsEditBtn'),
    'an older battle: its units listed as written, read only (' + oldPop.trim() + ')');
  await page.click('#vpUnitsOverlay [data-close-sheet]'); await page.waitForTimeout(300);
  await page.click('#gedit-player-baggageHeld-up');
  await page.click('#gameEditDeriveBtn');
  check(/600/.test(await page.textContent('#geditTotal-player')) && await page.inputValue('#gameEditResult') === 'win', 'put right: the total follows, and the result can be worked out from it');
  await page.click('#flowTab2'); await page.waitForTimeout(400);
  await page.click('#flowFinishBtn'); await page.waitForTimeout(800);
  const g7 = await db(page, (d) => d.games.find(g => g.id === 7));
  check(g7.player_vp === 600 && g7.player_breakdown.find(x => x.key === 'baggage-trains')?.entries?.baggageHeld === 2, 'saved: the new total and its breakdown');
  // 7. the organiser adds a battle: the same card for two players
  await page.evaluate(() => document.getElementById('manualGameOpenBtn').click()); await page.waitForTimeout(500);
  await page.selectOption('#manualGameMission', 'm1');
  await page.click('#flowTab1'); await page.waitForTimeout(400);
  const rows = await page.$$('.manual-game-row .manual-game-player');
  await rows[0].selectOption('a'); await page.waitForTimeout(200);
  await (await page.$$('.manual-game-row .manual-game-player'))[1].selectOption('b'); await page.waitForTimeout(300);
  check(!!(await page.$('#manualGameScores .vp-cols')) && /Alice/.test(await page.textContent('#manualGameScores')) && await page.$eval('.manual-game-vp', e => e.readOnly), 'Add a battle: two players, the players\' card, VP from it');
  await page.click('label:has(#mgame-player-kingIsDead)');
  check(await page.$eval('.manual-game-vp', e => e.value) === '100', 'a switch on the card gives the player their VP');
  // each player's army as it is now, to mark
  await page.click('#manualGameScores [data-vp-units="player"]'); await page.waitForTimeout(400);
  check(await page.$$eval('#vpUnitsBody .seg-btn[data-v="dead"]', bs => bs.map(b => b.dataset.unitId).join(' ')) === 'b1 b2 b3 b4', 'Add a battle: Bob\'s army as it is now, to mark');
  await page.click('#vpUnitsBody .seg-btn[data-unit-id="b2"][data-v="fleeing"]'); await page.waitForTimeout(200);
  check(/100 VP/.test(await page.textContent('#vpUnitsTotal')) && await page.$eval('.manual-game-vp', e => e.value) === '200', 'Clanrats fleeing: half its 200 points, and Alice\'s VP follows (200)');
  await page.click('#vpUnitsBody .seg-btn[data-unit-id="b2"][data-v="fleeing"]'); await page.waitForTimeout(200);
  await page.click('#vpUnitsOverlay [data-close-sheet]'); await page.waitForTimeout(300);
  await page.click('#manualGameDeriveBtn');
  await page.click('#flowTab2'); await page.waitForTimeout(400);
  await page.click('#flowFinishBtn'); await page.waitForTimeout(800);
  const mg = await page.evaluate(() => window.__manualGame);
  check(mg && mg.participants[0].vp === 100 && mg.participants[0].breakdown?.find(x => x.vp)?.key === 'king-is-dead' && mg.participants[0].breakdown?.find(x => x.key === 'units')?.entries?.units?.length === 4 && mg.participants[0].result === 'draw' && mg.participants[1].result === 'draw', 'added with each player\'s breakdown, the result worked out (100 VP apart: a draw)' + (mg ? ': ' + JSON.stringify(mg.participants).slice(0, 300) : ': nothing sent'));
  check(!page.errors.length, 'no page errors (organiser)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 6b. the organiser re-marks a unit on a logged battle: units' VP, total and result follow
  const wr = world();
  wr.db.campaign_members[0].role = 'organiser';
  const army = (list) => list.map(([id, name, points, status, general]) => ({ id, name, size: 1, points, status, ...(general ? { general: true } : {}) }));
  wr.db.games.push({ id: 9, campaign_id: 'c1', player_id: 'a', opponent_id: 'b', result: 'draw', campaign_points: 1, opponent_campaign_points: 1,
    player_vp: 100, opponent_vp: 100, confirmation_status: 'confirmed', played_on: '2026-10-22', mission_id: null, scenario: null,
    player_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 100, detail: ['Warlord, destroyed: 100'],
      entries: { unitsVp: 100, units: army([['b1', 'Warlord', 100, 'dead', true], ['b2', 'Clanrats', 200, null], ['b3', 'Slaves', 100, null], ['b4', 'Rats', 100, null]]) } }],
    opponent_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 100, detail: ['Captain, destroyed: 100'],
      entries: { unitsVp: 100, units: army([['a1', 'Captain', 100, 'dead', true], ['a2', 'Halberdiers', 200, null]]) } }] });
  // the lists have changed since: the battle keeps its own copy
  wr.db.units.find(u => u.id === 'b2').points = 999;
  page = await openApp(browser, wr);
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  const openEdit9 = async () => { await page.evaluate(() => document.querySelector('#adminGameLog [data-action="game-edit"][data-id="9"]').click()); await page.waitForTimeout(600); await page.click('#flowTab1'); await page.waitForTimeout(500); };
  await openEdit9();
  await page.click('#gameEditScores [data-vp-units="player"]'); await page.waitForTimeout(400);
  check(await page.isVisible('#vpUnitsOverlay') && /Alice: units destroyed/.test(await page.textContent('#vpUnitsTitle')) && await page.$$eval('#vpUnitsBody .wg-block', xs => xs.length) === 4 &&
    await page.getAttribute('#vpUnitsBody .seg-btn[data-unit-id="b1"][data-v="dead"]', 'aria-pressed') === 'true' && /Clanrats ×1 · 200 pts/.test(await page.textContent('#vpUnitsBody')),
    'Edit a battle: Show units lists every unit of Bob\'s army as it ended, at its points then');
  await page.click('#vpUnitsBody .seg-btn[data-unit-id="b2"][data-v="fled"]'); await page.waitForTimeout(300);
  check(/300 VP/.test(await page.textContent('#vpUnitsTotal')) && /300 VP/.test(await page.textContent('#gedit-player-units-n')) && /300/.test(await page.textContent('#geditTotal-player')),
    're-marked Clanrats fled: units 300 VP, the total follows');
  await page.click('#vpUnitsOverlay [data-close-sheet]'); await page.waitForTimeout(300);
  check(await page.inputValue('#gameEditResult') === 'win', 'the result follows the score (draw to win): ' + await page.inputValue('#gameEditResult'));
  await page.click('#flowTab2'); await page.waitForTimeout(400);
  await page.click('#flowFinishBtn'); await page.waitForTimeout(800);
  const g9 = await db(page, (d) => d.games.find(g => g.id === 9));
  const g9units = g9.player_breakdown.find(x => x.key === 'units');
  check(g9.player_vp === 300 && g9.result === 'win' && g9units.vp === 300 && g9units.entries.units.find(u => u.id === 'b2').status === 'fled' && g9units.entries.units.find(u => u.id === 'b2').points === 200,
    'saved: 300 VP, a win, Clanrats fled (still 200 points)');
  await openEdit9();
  await page.click('#gameEditScores [data-vp-units="player"]'); await page.waitForTimeout(400);
  check(await page.getAttribute('#vpUnitsBody .seg-btn[data-unit-id="b2"][data-v="fled"]', 'aria-pressed') === 'true' && /300 VP/.test(await page.textContent('#vpUnitsTotal')), 'opened again: as it was saved');
  await page.click('#vpUnitsOverlay [data-close-sheet]'); await page.waitForTimeout(300);
  check(!page.errors.length, 'no page errors (re-marking)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 8. the Players chart's Kills: the units a player destroyed with Path to
  // Glory off, their units' kill credits with it on
  for (const ptg of [false, true]) {
    const wk = world();
    wk.db.campaign_members[0].role = 'organiser';
    wk.db.campaigns[0].path_to_glory_enabled = ptg;
    wk.db.games.push({ id: 8, campaign_id: 'c1', player_id: 'a', opponent_id: 'b', result: 'win', campaign_points: 3, opponent_campaign_points: 1,
      player_vp: 400, opponent_vp: 100, confirmation_status: 'confirmed', played_on: '2026-10-22', scenario: 'Open field',
      kill_credits: [{ unitId: 'a2', amount: 3 }], opponent_kill_credits: null,
      player_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 400, detail: ['Warlord, destroyed: 100', 'Clanrats, fled: 200', 'Slaves, destroyed: 100'] }],
      opponent_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 100, detail: ['Captain, destroyed: 100'] }] });
    page = await openApp(browser, wk);
    await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
    await page.evaluate(() => document.getElementById('playersOpenBtn').click()); await page.waitForTimeout(600);
    await page.click('#playersView [data-view="chart"]'); await page.waitForTimeout(600);
    await page.selectOption('#chartMeasure', 'kills');
    await page.selectOption('#chartGroup', 'player'); await page.waitForTimeout(1200);
    const exp = await page.evaluate(() => new Promise((res) => {
      const orig = URL.createObjectURL; URL.createObjectURL = (b) => { b.text().then(res); URL.createObjectURL = orig; return orig.call(URL, new Blob([''])); };
      document.getElementById('chartExportBtn').click();
    }));
    const row = (name) => (exp.split('\n').find(l => l.includes(name)) || '').replace(/"/g, '');
    const want = ptg ? ['Alice,3', 'Bob,0'] : ['Alice,2', 'Bob,1'];
    check(row('Alice').startsWith(want[0]) && row('Bob').startsWith(want[1]),
      `Kills chart, Path to Glory ${ptg ? 'on: kill credits' : 'off: units destroyed'} (${row('Alice')} / ${row('Bob') || 'no Bob row'})`);
    await page.selectOption('#chartGroup', 'unit').catch(() => {}); await page.waitForTimeout(400);
    const unitKillsOk = await page.$eval('#chartMeasure option[value="kills"]', o => !o.disabled);
    check(unitKillsOk === ptg, `Kills by unit ${ptg ? 'offered' : 'not offered'} with Path to Glory ${ptg ? 'on' : 'off'}`);
    check(!page.errors.length, 'no page errors (Kills chart)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
    await page.close();
  }

  await browser.close();
  console.log(fails.length ? `\n${fails.length} failed` : '\nAll passed');
  process.exit(fails.length ? 1 : 0);
})();
