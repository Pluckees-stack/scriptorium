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
  await page.waitForSelector('#vp-player-unitsVp');
  check(await page.$$eval('#endCardTabs [data-swipe]', xs => xs.length) === 4, 'end of battle: four cards');
  check(await page.$eval('#opponentUnitsList .seg-btn[data-unit-id="b1"][data-v="dead"]', b => b.classList.contains('on')), 'Bob’s Warlord starts as dead');
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
  await page.waitForSelector('#vp-player-unitsVp');
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
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
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

  await browser.close();
  console.log(fails.length ? `\n${fails.length} failed` : '\nAll passed');
  process.exit(fails.length ? 1 : 0);
})();
