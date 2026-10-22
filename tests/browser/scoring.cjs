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

  // 2. a full battle: turns, every objective at the end, logged by one player
  page = await openApp(browser, world());
  await intoBattle(page);
  check(await page.getAttribute('#gameStrategicLocationsInput', 'max') === '3', 'synced: markers capped at the scenario’s 3 per turn');
  await page.fill('#gameStrategicLocationsInput', '2');
  await page.click('#gameNextTurnBtn');
  await page.waitForTimeout(500);
  check(await db(page, (d) => d.game_invites[0].strategic_vp_from_user) === 60, 'end my turn banks 2 markers (60 VP)');
  // Bob's turn: he holds one marker
  await db(page, (d) => { const i = d.game_invites[0]; i.strategic_vp_to_user = 30; i.active_slot = 'first'; i.current_round = 2; });
  await page.waitForTimeout(3500);
  // Bob killed Alice's Captain on his tracker? No: Alice's own Captain wiped on her tracker
  await page.evaluate(() => { const b = [...document.querySelectorAll('#rostersGame .wound-btn[data-action="dec"]')].find(x => x.dataset.unitId === 'a1'); for (let i = 0; i < 10 && b; i++) b.click(); });
  // Bob's tracker: his Warlord dead
  await db(page, (d) => { d.units.find(u => u.id === 'b1').current_wounds = 0; });
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEndMine:not(.hide)');
  await page.waitForSelector('#obj-player-kingIsDead');
  const ids = await page.$$eval('#myObjectivesBlock [id^="obj-player-"]', xs => xs.map(x => x.id));
  check(['kingIsDead', 'breakingTheEnemy', 'baggageDestroyed', 'baggageSurvived', 'strategicVp', 'otherVp'].every(f => ids.includes('obj-player-' + f)), 'What you scored: every objective editable (' + ids.join(', ') + ')');
  check(await page.isChecked('#obj-player-kingIsDead'), 'King is Dead ticked from Bob’s dead Warlord');
  check(await page.inputValue('#obj-player-strategicVp') === '60', 'Strategic Locations starts at the 60 banked');
  // mark two more of Bob's units fled: 3 of 4 gone -> Breaking ticks itself
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="fled"]');
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b3"][data-v="fled"]');
  check(await page.isChecked('#obj-player-breakingTheEnemy'), 'Breaking the Enemy follows the units');
  await page.click('label:has(#obj-player-breakingTheEnemy)');
  await page.click('#opponentUnitsList .seg-btn[data-unit-id="b4"][data-v="fleeing"]');
  check(!(await page.isChecked('#obj-player-breakingTheEnemy')), 'Breaking the Enemy stays off once set by hand');
  await page.fill('#obj-player-otherVp', '25'); await page.press('#obj-player-otherVp', 'Tab');
  // back to the battle and End battle again: marks kept
  await page.click('#endMineBackBtn');
  await page.waitForSelector('#gameStagePlaying:not(.hide)');
  await page.click('#endGameBtn');
  await page.waitForSelector('#gameStageEndMine:not(.hide)');
  await page.waitForSelector('#obj-player-kingIsDead');
  check(await page.$eval('#opponentUnitsList .seg-btn[data-unit-id="b2"][data-v="fled"]', b => b.classList.contains('on')), 'going back keeps the units marked');
  await page.click('#endMineContinueBtn');
  await page.waitForSelector('#gameStageEndOpponent:not(.hide)');
  check(await page.$eval('#ownUnitsList .seg-btn[data-unit-id="a1"][data-v="dead"]', b => b.classList.contains('on')), 'your own unit wiped on your tracker starts as dead');
  check(await page.inputValue('#obj-opponent-strategicVp') === '30', 'their Strategic Locations starts at the 30 they banked');
  await page.click('#endOpponentContinueBtn');
  await page.waitForSelector('#gameStageEndConfirm:not(.hide)');
  const tally = await page.textContent('#vpTally');
  check(!/Baggage/.test(tally), 'no baggage VP for either side with nothing ticked');
  await page.click('#lgBtn');
  await page.waitForTimeout(5500);
  const game = await db(page, (d) => ({ games: d.games.length, inv: d.game_invites[0] }));
  const rpcs = await page.evaluate(() => window.__FAKE_LOG.filter(x => x[0] === 'rpc').map(x => x[1]));
  check(rpcs.includes('log_game_with_xp'), 'logged straight away with log_game_with_xp (no waiting for the opponent)');
  check(game.inv.submitter_id === 'a' && game.inv.status === 'completed', 'request claimed by Alice and closed');
  // Alice: Warlord 100 + Clanrats 200 + Slaves 100 + Rats 50 (fleeing) + King 100 + Strategic 60 + Other 25 = 635
  // Bob: Captain 100 + King 100 (Alice's General) + Strategic 30 = 230
  const logged = await page.evaluate(() => window.__lastLogged);
  check(!!logged, 'a battle was logged');
  if (logged) check(logged.player_vp === 635 && logged.opponent_vp === 230, `VP logged ${logged.player_vp}–${logged.opponent_vp} (want 635–230)`);
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
  check(/you 230 VP, them 635 VP/.test(logText) && /Breaking the Enemy: 500 VP/.test(logText), 'battle log: VP and scoring shown to confirm or dispute');
  check(!page.errors.length, 'no page errors (battle log)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  await browser.close();
  console.log(fails.length ? `\n${fails.length} failed` : '\nAll passed');
  process.exit(fails.length ? 1 : 0);
})();
