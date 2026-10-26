// The other ways through a battle the random battles (sim.cjs) don't
// take: the player who accepted the request (their markers in their own
// column), "start anyway" (unsynced: both sides' markers kept on the
// page), and both players asking each other at once (one battle, the
// earlier request's), and one player logging the result. Uses scoring.cjs's world.
//   NODE_PATH=$(npm root -g) node tests/browser/sim-paths.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');
const src = require('fs').readFileSync(__dirname + '/scoring.cjs', 'utf8');
const world = new Function('require', src.slice(src.indexOf('const general'), src.indexOf('const fails')) + '; return world;')(require);
const db = (page, fn) => page.evaluate((f) => new Function('db', `return (${f})(db)`)(window.__FAKE_DB), fn.toString());
const fails = [];
// two buttons at least 12px apart, side by side or one above the other
const apart = (page, a, b) => page.evaluate(([a, b]) => {
  const r = document.querySelector(a).getBoundingClientRect(), q = document.querySelector(b).getBoundingClientRect();
  return Math.max(q.left - r.right, r.left - q.right, q.top - r.bottom, r.top - q.bottom) >= 12;
}, [a, b]);
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

  // 1. Bob accepts Alice's request; Alice goes first
  const w = world();
  w.session.user = { id: 'b', email: 'b@example.com', user_metadata: {} };
  w.db.game_invites.push({ id: 'inv1', campaign_id: 'c1', from_user_id: 'a', to_user_id: 'b', status: 'pending', mission_id: 'm1', scenario: 'Open field',
    active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0, created_at: new Date().toISOString() });
  let page = await openApp(browser, w);
  await page.waitForSelector('#incomingInviteOverlay:not(.hide)', { timeout: 20000 });
  await page.click('#incomingInviteAcceptBtn');
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  await page.click('#spellsContinueBtn');
  await db(page, (d) => Object.assign(d.game_invites[0], { from_ready_at: 'now', first_player_id: 'a' }));
  await page.waitForSelector('#gameStagePlaying:not(.hide)', { timeout: 20000 }); await page.waitForTimeout(3500);
  check(await page.isDisabled('#gameNextTurnBtn') && /Alice's turn/.test(await page.textContent('#gameWhoseTurnLine')), 'Bob: Alice goes first, so it\'s her turn');
  // Alice's turn ends (she held 1, Bob 2): 30 to her, 60 to Bob
  await db(page, (d) => Object.assign(d.game_invites[0], { active_slot: 'second', strategic_vp_from_user: 30, strategic_vp_to_user: 60 }));
  await page.waitForTimeout(3500);
  check(await page.isEnabled('#gameNextTurnBtn'), 'Bob: then his turn');
  await page.click('[data-strat-for="gameStrategicLocationsInput"][data-strat-by="1"]');
  await page.click('[data-strat-for="gameStrategicLocationsInput"][data-strat-by="1"]');
  await page.click('[data-strat-for="gameStrategicLocationsInput"][data-strat-by="1"]');
  await page.click('#gameNextTurnBtn'); await page.waitForTimeout(600);
  const inv = await db(page, (d) => d.game_invites[0]);
  check(inv.strategic_vp_to_user === 150 && inv.strategic_vp_from_user === 30 && inv.current_round === 2, `Bob holds 3: his own column (to_user ${inv.strategic_vp_to_user}, want 150; from_user ${inv.strategic_vp_from_user}, want 30)`);
  const running = (await page.textContent('#gameRunningTotals')).replace(/\s+/g, ' ');
  check(/Alice\s*30\s*VP\s*Bob\s*150\s*VP/.test(running), `running total: Alice (first turn) left on 30, Bob 150 (${running.trim()})`);
  await page.click('#endGameBtn'); await page.waitForSelector('#vp-player-units-n'); await page.waitForTimeout(400);
  await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(400);
  await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(600);
  check(await page.textContent('#vp-player-strategicHeld') === '5' && await page.textContent('#vp-opponent-strategicHeld') === '1', 'Bob\'s card: he held 5 (150), Alice 1 (30)');
  const heads = await page.$$eval('#vpTable .vp-head-name', es => es.map(e => e.textContent));
  check(heads[0] === 'Alice' && heads[1] === 'Bob', `Alice, who went first, on the left (${heads})`);
  check(!page.errors.length, 'no script errors (Bob)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 2. Alice starts without waiting: the battle runs on her page alone
  const w2 = world();
  page = await openApp(browser, w2);
  await page.click('.tab-btn[data-tab="game"]'); await page.click('#startGameBtn');
  await page.waitForFunction(() => document.querySelectorAll('#gameOpponentSelect option').length > 1);
  await page.selectOption('#gameOpponentSelect', 'b'); await page.click('#opponentContinueBtn');
  await page.waitForFunction(() => document.querySelector('#gameMissionSelect option[value="m1"]'));
  await page.selectOption('#gameMissionSelect', 'm1'); await page.click('#missionContinueBtn');
  await page.waitForSelector('#gameStageWaiting:not(.hide)');
  check(await apart(page, '#waitingCancelBtn', '#waitingBypassBtn'), 'waiting: "Cancel request" and "start anyway" have room between them');
  await db(page, (d) => Object.assign(d.game_invites[0], { status: 'accepted', active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0 }));
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 }); await page.click('#spellsContinueBtn');
  await page.waitForSelector('#gameStageSync:not(.hide)');
  check(await apart(page, '#syncBypassBtn', '#gameStageSync [data-leave-battle]'), 'sync: "start anyway" and "Leave this battle" have room between them');
  check(await page.$$eval('[data-leave-battle].mini-btn', es => es.length === 3 && es.every(e => e.classList.contains('adm-danger'))), 'every "Leave this battle" is the danger button');
  await page.click('#syncBypassBtn');
  // still asked who goes first, on her page alone
  await page.waitForSelector('#gameStagePick:not(.hide)');
  check(/Bob goes first/.test(await page.textContent('#pickOpponentBtn')), 'unsynced: asked who goes first');
  await page.click('#pickSelfBtn');
  await page.waitForSelector('#gameStagePlaying:not(.hide)'); await page.waitForTimeout(500);
  check(/Your turn/.test(await page.textContent('#gameWhoseTurnLine')) && await page.isEnabled('#gameNextTurnBtn'), 'unsynced: Alice went first, so her turn, and it can be ended');
  // two turns: first player's (Alice 2, Bob 1), then second's (Alice 1, Bob 2)
  const hold = async (mine, theirs) => {
    for (const [id, n] of [['gameStrategicLocationsInput', mine], ['gameStrategicLocationsOppInput', theirs]]) {
      await page.fill('#' + id, String(n)); await page.dispatchEvent('#' + id, 'change');
    }
    await page.click('#gameNextTurnBtn'); await page.waitForTimeout(300);
  };
  await hold(2, 1);
  check(/Bob's turn/.test(await page.textContent('#gameWhoseTurnLine')) && (await page.textContent('#gameTurnNumber')) === '1', 'unsynced: then Bob\'s, still round 1');
  await hold(1, 2);
  check((await page.textContent('#gameTurnNumber')) === '2', 'unsynced: round 2 after both turns');
  // a turn ended untouched scores nothing: the counts start each turn at none
  check(await page.inputValue('#gameStrategicLocationsInput') === '0' && await page.inputValue('#gameStrategicLocationsOppInput') === '0', 'unsynced: markers back to none each turn');
  await page.click('#gameNextTurnBtn'); await page.waitForTimeout(300);
  await page.click('#endGameBtn'); await page.waitForSelector('#vp-player-units-n'); await page.waitForTimeout(300);
  await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(400);
  await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(600);
  check(await page.textContent('#vp-player-strategicHeld') === '3' && await page.textContent('#vp-opponent-strategicHeld') === '3', 'unsynced: both sides banked on the page (3 each)');
  await page.click('#endCardVp [data-end-go="3"]'); await page.waitForTimeout(500);
  await page.click('#lgBtn'); await page.waitForTimeout(5500);
  const logged = await page.evaluate(() => window.__lastLogged);
  check(logged && logged.player_vp === 90 && logged.opponent_vp === 90, `unsynced: logged 90–90 (${logged && logged.player_vp}–${logged && logged.opponent_vp})`);
  check(!page.errors.length, 'no script errors (start anyway)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  // 3. Both ask each other at once: the earlier request is the battle
  const askBob = async (page) => {
    await page.click('.tab-btn[data-tab="game"]'); await page.click('#startGameBtn');
    await page.waitForFunction(() => document.querySelectorAll('#gameOpponentSelect option').length > 1);
    await page.selectOption('#gameOpponentSelect', 'b'); await page.click('#opponentContinueBtn');
    await page.waitForFunction(() => document.querySelector('#gameMissionSelect option[value="m1"]'));
    await page.selectOption('#gameMissionSelect', 'm1'); await page.click('#missionContinueBtn');
  };
  const bobsRequest = (at) => ({ id: 'bobs', campaign_id: 'c1', from_user_id: 'b', to_user_id: 'a', status: 'pending', mission_id: 'm1', scenario: 'Open field',
    active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0, created_at: at });
  // 3a. Bob's request already there when Alice asks: she joins his
  const w3 = world();
  page = await openApp(browser, w3);
  await page.evaluate((r) => window.__FAKE_DB.game_invites.push(r), bobsRequest(new Date().toISOString()));
  await askBob(page);
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  let invs = await db(page, (d) => d.game_invites.map(i => `${i.from_user_id}>${i.to_user_id}:${i.status}`));
  check(invs.length === 1 && invs[0] === 'b>a:accepted', `asked already: Alice joins Bob's battle, no second request (${invs})`);
  check(/Confirm ready/.test(await page.textContent('#spellsContinueBtn')), 'asked already: Alice gets ready as the one who accepted');
  await page.close();
  // 3a'. Bob's lands between Alice's check and her request (108's index refuses hers): she joins his
  const w3b = world();
  page = await openApp(browser, w3b);
  await page.evaluate((r) => {
    window.__FAKE_REFUSE = { game_invites: (row, d) => {
      if (row.from_user_id !== 'a') return null;
      if (!d.game_invites.some(i => i.id === 'bobs')) d.game_invites.push(r);
      return { code: '23505', message: 'duplicate key value violates unique constraint "game_invites_one_open_per_pair"' };
    } };
  }, bobsRequest(new Date().toISOString()));
  await askBob(page);
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  invs = await db(page, (d) => d.game_invites.map(i => `${i.from_user_id}>${i.to_user_id}:${i.status}`));
  check(invs.length === 1 && invs[0] === 'b>a:accepted', `refused as a second request: Alice joins Bob's (${invs})`);
  check(!(await page.isVisible('#gameMissionErr')), 'refused as a second request: no error shown');
  await page.close();
  // 3b. Bob's arrives just after Alice's but was sent first: hers gives way
  const w4 = world();
  page = await openApp(browser, w4);
  await askBob(page);
  await page.waitForSelector('#gameStageWaiting:not(.hide)');
  await page.evaluate((r) => window.__FAKE_DB.game_invites.push(r), bobsRequest(new Date(Date.now() - 2000).toISOString()));
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  invs = await db(page, (d) => d.game_invites.map(i => `${i.from_user_id}>${i.to_user_id}:${i.status}`).sort());
  check(invs.join() === 'a>b:cancelled,b>a:accepted', `crossed, Bob's first: Alice's withdrawn, Bob's accepted (${invs})`);
  check(await page.$eval('#incomingInviteOverlay', e => e.classList.contains('hide')), 'crossed: no Accept / Decline to answer');
  check(!page.errors.length, 'no script errors (crossed)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();
  // 3c. Bob's sent after Alice's: she keeps waiting, his left for him to withdraw
  const w5 = world();
  page = await openApp(browser, w5);
  await askBob(page);
  await page.waitForSelector('#gameStageWaiting:not(.hide)');
  await page.evaluate((r) => window.__FAKE_DB.game_invites.push(r), bobsRequest(new Date(Date.now() + 2000).toISOString()));
  await page.waitForTimeout(4000);
  invs = await db(page, (d) => d.game_invites.map(i => `${i.from_user_id}>${i.to_user_id}:${i.status || 'pending'}`).sort()); // the fake has no column defaults
  check(invs.join() === 'a>b:pending,b>a:pending' && await page.isVisible('#gameStageWaiting'), `crossed, Alice's first: she keeps waiting for Bob (${invs})`);
  // Bob's side then withdraws his and accepts hers
  await db(page, (d) => { d.game_invites.find(i => i.id === 'bobs').status = 'cancelled'; Object.assign(d.game_invites.find(i => i.id !== 'bobs'), { status: 'accepted' }); });
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  check(/Continue to battle/.test(await page.textContent('#spellsContinueBtn')), 'crossed, Alice\'s first: Bob joins, and she goes on as the one who asked');
  await page.close();

  // 4. One player logs: whoever ends the battle; the other waits
  const w6 = world();
  w6.session.user = { id: 'b', email: 'b@example.com', user_metadata: {} };
  w6.db.game_invites.push({ id: 'inv1', campaign_id: 'c1', from_user_id: 'a', to_user_id: 'b', status: 'pending', mission_id: 'm1', scenario: 'Open field',
    active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0, created_at: new Date().toISOString() });
  page = await openApp(browser, w6);
  await page.waitForSelector('#incomingInviteOverlay:not(.hide)', { timeout: 20000 });
  await page.click('#incomingInviteAcceptBtn');
  await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 });
  await page.click('#spellsContinueBtn');
  await db(page, (d) => Object.assign(d.game_invites[0], { from_ready_at: 'now', first_player_id: 'a' }));
  await page.waitForSelector('#gameStagePlaying:not(.hide)', { timeout: 20000 });
  // Bob ends it: he's the one logging it, and Back hands it back
  await page.click('#endGameBtn'); await page.waitForSelector('#gameStageEnd:not(.hide)'); await page.waitForTimeout(300);
  check((await db(page, (d) => d.game_invites[0].submitter_id)) === 'b', 'Bob ends the battle: he logs it');
  await page.click('#endBackBtn'); await page.waitForTimeout(500);
  check((await db(page, (d) => d.game_invites[0].submitter_id)) == null && await page.isVisible('#gameStagePlaying'), 'Bob goes back: nobody logging it, still playing');
  // Alice ends it: Bob waits, without the result to fill in
  await db(page, (d) => { d.game_invites[0].submitter_id = 'a'; });
  await page.waitForSelector('#gameStageHold:not(.hide)', { timeout: 8000 });
  check(/Alice/.test(await page.textContent('#holdLine')) && !(await page.isVisible('#gameStageEnd')), 'Alice ends it: Bob waits for her to log it');
  await db(page, (d) => { d.game_invites[0].submitter_id = null; });
  await page.waitForSelector('#gameStagePlaying:not(.hide)', { timeout: 8000 });
  check(true, 'Alice goes back: so does Bob');
  // both end it at once: Alice's claim first, so Bob's End battle waits too
  await db(page, (d) => { d.game_invites[0].submitter_id = 'a'; });
  await page.click('#endGameBtn'); await page.waitForSelector('#gameStageHold:not(.hide)', { timeout: 8000 });
  check((await db(page, (d) => d.game_invites[0].submitter_id)) === 'a', 'both at once: the first to end it logs it');
  // Alice logs it: Bob's battle closes
  await db(page, (d) => { d.game_invites[0].staged_game_id = 'g1'; });
  await page.waitForSelector('#gameStageStart:not(.hide)', { timeout: 8000 });
  check(true, 'Alice logs it: Bob\'s battle ends, to confirm or dispute');
  check(!page.errors.length, 'no script errors (one logger)' + (page.errors.length ? ': ' + page.errors.join(' | ') : ''));
  await page.close();

  await browser.close();
  console.log(fails.length ? `\n${fails.length} failed` : '\nAll passed');
  process.exit(fails.length ? 1 : 0);
})();
