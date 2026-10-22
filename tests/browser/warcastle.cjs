// Browser checks for WarCastle (warcastle-brief.md) in the real index.html,
// against a fake Supabase. Serve the repo root, then run:
//   python3 -m http.server 8765 &
//   NODE_PATH=$(npm root -g) node tests/browser/warcastle.cjs
const { chromium } = require('playwright');
const { world } = require('./warcastle-world.cjs');
const { openApp } = require('./app.cjs');

let failures = 0;
const check = (label, cond, detail = '') => { if (cond) console.log(`  ok   ${label}`); else { failures++; console.log(`  FAIL ${label}${detail ? ` -- ${detail}` : ''}`); } };
const text = (p, sel) => p.$eval(sel, e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
async function toRunMap(a) {
  await a.evaluate(() => document.getElementById('adminModeToggle').click()); await a.waitForTimeout(1000);
  await a.evaluate(() => document.getElementById('runNavBtn').click()); await a.waitForTimeout(1200);
}
async function tapArea(a, hostSel, x, y, { mouse = false } = {}) {
  if (mouse) await a.$eval(`${hostSel} .wc-map`, e => e.scrollIntoView({ block: 'center' }));
  const r = await a.$eval(`${hostSel} .wc-map`, e => { const b = e.getBoundingClientRect(); return [b.left, b.top, b.width, b.height]; });
  const at = [r[0] + x / 2000 * r[2], r[1] + y / 1333 * r[3]];
  if (mouse) await a.mouse.click(...at); else await a.touchscreen.tap(...at);
  await a.waitForTimeout(500);
}

(async () => {
  const b = await chromium.launch();

  console.log('A player, round 1 in play');
  const w = world({ me: 'p03' });
  w.db.tournament_pairings.forEach(p => { p.warcastle = { attacker: p.player_b_id, came_from: null, ambush: false, rolled: true }; });
  Object.assign(w.db.tournament_pairings[1], { player_a_id: 'p04', player_b_id: 'p03', warcastle: { attacker: 'p03', came_from: 'nw', ambush: false } });
  const p = await openApp(b, w, { phone: true });
  check('the Standings tab is the Map', (await text(p, '#standingsTabBtn')) === 'Map');
  check('Play: their part and deployment', (await text(p, '#tournamentGameCta')).includes('You attack from the north-west.') && !!(await p.$('#tournamentGameCta svg.wc-dep')));
  check('Play: no Play battle or Free play in a tournament', await p.$eval('#startGameBtn', e => e.classList.contains('hide')) && await p.$eval('#freePlayBtn', e => e.classList.contains('hide')));
  await p.click('#standingsTabBtn'); await p.waitForTimeout(1500);
  const panel = await text(p, '#wcMapWrap .wc-area');
  check('the map opens on their own area', panel.startsWith('Area 2 · River') && panel.includes('wc-test-03 (you)'));
  check('no game nights in Play', await p.$eval('#gameNightsSection', e => e.classList.contains('hide')));
  check('the map comes first on the tab', await p.$eval('[data-panel="standings"]', e => e.firstElementChild.id === 'wcMapSection'));
  check('no script errors', !p.errors.length, p.errors.join(' | '));

  console.log('A player, after their battle');
  const wd = world({ me: 'p03' }); wd.db.tournament_pairings[1].result = 'draw';
  const pd = await openApp(b, wd, { phone: true });
  const cta = await text(pd, '#tournamentGameCta');
  check('Play: their result, waiting for the round to end', cta.includes('a draw') && cta.includes('Waiting for the round to end.'), cta);
  check('Play: no Play this battle once it\'s played', !(await pd.$('[data-tournament-cta]')));
  // the round's tables, read-only: table 1 won with its breakdown, the rest in progress
  const wb = world({ me: 'p03' });
  Object.assign(wb.db.tournament_pairings[0], { result: 'a_win', game_id: 900 });
  wb.db.games = [{ id: 900, player_id: 'p01', opponent_id: 'p02', player_vp: 1250, opponent_vp: 900, confirmation_status: 'confirmed',
    player_breakdown: [{ key: 'units', label: 'Units', vp: 800 }, { key: 'domination', label: 'Domination', vp: 450 }], opponent_breakdown: [{ key: 'units', label: 'Units', vp: 900 }] }];
  const pb = await openApp(b, wb, { phone: true });
  const rows = await pb.$$eval('.tb-board > li', es => es.map(e => e.innerText.replace(/\s+/g, ' ').trim()));
  check('Play: every table in the round', rows.length === 13, String(rows.length));
  check('a finished battle: winner and score', rows[0].startsWith('Area 1: wc-test-01 v wc-test-02 wc-test-01 won, 1,250–900'), rows[0]);
  check('an unfinished one: in progress', rows[2] === 'Area 3: wc-test-05 v wc-test-06 in progress', rows[2]);
  check('their own table marked', rows[1].includes('wc-test-03 (you)'), rows[1]);
  await pb.click('#playerTabBar [data-tab="game"]'); await pb.waitForTimeout(500);
  await pb.click('.tb-board details summary'); await pb.waitForTimeout(300);
  check('tap a finished battle: its score element by element', (await text(pb, '.tb-board details')).includes('Domination: 450'));
  check('read-only: nothing to edit', !(await pb.$('.tb-board button, .tb-board select, .tb-board input')));

  console.log('A player, while the armies move');
  const w2 = world({ me: 'p03', round: 'completed', withMoves: true });
  w2.db.warcastle_moves.push({ id: 'x', tournament_id: 't1', campaign_id: 'c1', round_number: 2, player_id: 'p03', from_area: 2, to_area: 12, seq: 99 });
  const q = await openApp(b, w2, { phone: true });
  await q.click('#standingsTabBtn'); await q.waitForTimeout(1500);
  check('caption', (await text(q, '#wcMapRound')) === 'Round 2: the armies are moving');
  check('they show where they moved to', (await text(q, '#wcMapWrap .wc-area')).startsWith('Area 12'));

  const between = await text(q, '#tournamentGameCta');
  check('Play between rounds: last result, then what\'s next', between.includes('round 1: you won against wc-test-04') && between.includes('Waiting for round 2: the armies are moving.'), between);

  console.log('The organiser, moving the armies');
  const a = await openApp(b, world({ me: 'g', round: 'completed', withMoves: true }), { phone: true });
  await toRunMap(a);
  check('no Game nights in the console', await a.$eval('#nightsAdminTabBtn', e => e.classList.contains('hide')) && !(await text(a, '#adminSubnav')).includes('Game nights'));
  check('Run opens on the Map step', (await text(a, '#tournamentSteps [aria-selected="true"]')).includes('Map'));
  check('caption', (await text(a, '#tournamentMapRound')) === 'Round 2: moving');
  check('the queue: winners, draws, losers, in order', (await a.$$eval('#tournamentMapQueue h4', es => es.map(e => e.textContent))).join() === 'Winners,Draws,Losers');
  check('the queue marks whose turn it is', (await a.$$eval('#tournamentMapQueue li.is-next', es => es.map(e => e.querySelector('strong').textContent))).join() === 'wc-test-03');
  check('no (i) on the Map heading', !(await a.$('#tournamentMapHeading .info-btn')));
  {
    const cls = await a.evaluate(() => Object.fromEntries(['p03', 'p05', 'p17'].map(id => [id, document.querySelector(`#tournamentMapWrap [data-wc-token="${id}"]`).className])));
    check('whose turn it is: a green ring, bigger', /is-turn/.test(cls.p03) && !/is-waiting/.test(cls.p03), cls.p03);
    check('still to move: a red ring, and fixed on the map', /is-waiting/.test(cls.p05) && /is-waiting/.test(cls.p17) && /is-fixed/.test(cls.p17), JSON.stringify(cls));
    const [big, small] = await a.evaluate(() => ['p03', 'p05'].map(id => document.querySelector(`#tournamentMapWrap [data-wc-token="${id}"] .player-icon`).getBoundingClientRect().width));
    check('the ones whose turn it is are bigger', big > small * 1.2, `${big} ${small}`);
    // a piece whose turn it isn't doesn't lift
    await a.$eval('#tournamentMapWrap .wc-map', e => e.scrollIntoView({ block: 'center' })); await a.waitForTimeout(300);
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p17"] .player-icon', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 60, f[1] + 40, { steps: 6 });
    const lifted = await a.evaluate(() => !!document.querySelector('.wc-ghost')); await a.mouse.up(); await a.waitForTimeout(500);
    check('a piece whose turn it isn\'t won\'t drag', !lifted && !(await a.evaluate(() => window.__FAKE_DB.warcastle_moves.some(m => m.player_id === 'p17' && m.round_number === 2))));
  }
  await a.click('[data-wc-pick="p03"]'); await a.waitForTimeout(1000);
  await tapArea(a, '#tournamentMapWrap', 1715, 195);
  check('a move: tap the army, then the area', (await a.$eval('[data-wc-pick="p03"]', e => e.closest('li').innerText)).includes('area 2 to 12'));
  // drag a piece: wc-test-05 from area 3 into area 9
  check('a piece for every army on the map', (await a.$$eval('#tournamentMapWrap [data-wc-token]', es => es.length)) === 26);
  {
    await a.$eval('#tournamentMapWrap .wc-map', e => e.scrollIntoView({ block: 'center' })); await a.waitForTimeout(400);
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p05"] .player-icon', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left + e.clientLeft, q.top + e.clientTop, e.clientWidth, e.clientHeight]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 20, f[1] + 20, { steps: 4 });
    await a.mouse.move(r[0] + 645 / 2000 * r[2], r[1] + 680 / 1333 * r[3], { steps: 8 });
    check('while dragging, the piece itself is lifted off the map', await a.evaluate(() => !!document.querySelector('.wc-ghost') && document.querySelector('#tournamentMapWrap [data-wc-token="p05"]').classList.contains('is-dragging')));
    await a.mouse.up();
    // before anything's saved: already there, no snapping back
    const at = await a.$eval('#tournamentMapWrap [data-wc-token="p05"]', e => [parseFloat(e.style.left), parseFloat(e.style.top), e.classList.contains('is-dragging')]);
    check('it lands where it\'s let go, straight away', Math.abs(at[0] - 32.25) < .6 && Math.abs(at[1] - 51.01) < .6 && !at[2] && !(await a.$('.wc-ghost')), JSON.stringify(at));
    await a.waitForTimeout(700);
  }
  check('drag a piece to move it', (await a.$eval('[data-wc-pick="p05"]', e => e.closest('li').innerText)).includes('area 3 to 9'));
  check('a dragged piece stays where it was dropped', await a.evaluate(() => { const sp = window.__FAKE_DB.campaigns[0].settings.warcastle.spots?.p05; return !!sp && Math.abs(sp[0] - 645) < 8 && Math.abs(sp[1] - 680) < 8; }));
  check('and where it was dropped after the save', await a.$eval('#tournamentMapWrap [data-wc-token="p05"]', e => Math.abs(parseFloat(e.style.left) - 32.25) < .6 && Math.abs(parseFloat(e.style.top) - 51.01) < .6));
  check('a moved army leaves the queue for Moved', (await text(a, '#tournamentMapQueue .wc-done')).includes('wc-test-05'));
  check('each piece has its player\'s name under it', (await text(a, '#tournamentMapWrap [data-wc-token="p05"] .wc-piece-name')) === 'wc-test-05');
  {
    // nudged inside the area it's in: a new spot, not a new move
    const seq0 = await a.evaluate(() => window.__FAKE_DB.warcastle_moves.find(m => m.player_id === 'p05' && m.round_number === 2)?.seq);
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p05"] .player-icon', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left + e.clientLeft, q.top + e.clientTop, e.clientWidth, e.clientHeight]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down();
    await a.mouse.move(r[0] + 690 / 2000 * r[2], r[1] + 720 / 1333 * r[3], { steps: 6 }); await a.mouse.up(); await a.waitForTimeout(700);
    const after = await a.evaluate(() => ({ seq: window.__FAKE_DB.warcastle_moves.find(m => m.player_id === 'p05' && m.round_number === 2)?.seq, spot: window.__FAKE_DB.campaigns[0].settings.warcastle.spots.p05 }));
    check('moved about inside its area: only its spot changes', after.seq === seq0 && Math.abs(after.spot[0] - 690) < 8 && Math.abs(after.spot[1] - 720) < 8, JSON.stringify({ seq0, ...after }));
  }
  // no crossing: wc-test-21 (its turn now) from 11 into 1, already holding two
  {
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p21"] .player-icon', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left + e.clientLeft, q.top + e.clientTop, e.clientWidth, e.clientHeight]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 20, f[1] + 20, { steps: 4 });
    await a.mouse.move(r[0] + 430 / 2000 * r[2], r[1] + 330 / 1333 * r[3], { steps: 8 }); await a.mouse.up(); await a.waitForTimeout(900);
  }
  check('a drop with no crossing goes ahead once confirmed, and is flagged', (await a.$eval('[data-wc-pick="p21"]', e => e.closest('li').innerText)).includes('area 11 to 1')
    && (await text(a, '.wc-flags')).includes("wc-test-21: there's no crossing from area 11 to area 1."));
  check('an area with three armies goes red', await a.evaluate(() => document.getElementById('tournamentMapWrap')._wc.view.crowded.includes(1)) && (await text(a, '.wc-flags')).includes('Area 1 has 3 armies.'));
  await a.click('[data-wc-pick="p01"]'); await a.waitForTimeout(1000); await a.click('[data-wc-stay]'); await a.waitForTimeout(500);
  check('a draw staying put is flagged', (await text(a, '.wc-flags')).includes('wc-test-01 drew, so has to move.'));
  await a.click('[data-wc-undo]'); await a.waitForTimeout(500);
  check('undo', !(await a.$eval('[data-wc-pick="p01"]', e => e.closest('li').innerText)).includes('stays'));
  await a.click('[data-wc-make]'); await a.waitForTimeout(1500);
  const made = await a.evaluate(() => window.__FAKE_DB.tournament_pairings.filter(p => p.round_id === 'r2'));
  check('pairings made from the map, each on its area\'s table', made.length && made.every(p => p.table_number >= 1 && p.table_number <= 13 && p.mission_id === 'm' + p.table_number));
  check('no script errors', !a.errors.length, a.errors.join(' | '));

  console.log('The organiser: attacker and defender on the map');
  {
    const wr = world({ me: 'g', round: 'completed', withMoves: true });
    // wc-test-10 leaves area 5 and wc-test-11 comes in from 6: 11 attacks, 9 (stayed) defends
    wr.db.warcastle_moves.push({ id: 'mvr1', tournament_id: 't1', campaign_id: 'c1', round_number: 2, player_id: 'p10', from_area: 5, to_area: 13, seq: 40 },
      { id: 'mvr2', tournament_id: 't1', campaign_id: 'c1', round_number: 2, player_id: 'p11', from_area: 6, to_area: 5, seq: 41 });
    const ro = await openApp(b, wr);
    await toRunMap(ro);
    const role = (id) => ro.$eval(`#tournamentMapWrap [data-wc-token="${id}"]`, e => e.querySelector('.wc-piece-role')?.className || '');
    check('the attacker has a sword, the defender a shield', /is-attacker/.test(await role('p11')) && /is-defender/.test(await role('p09')) && !(await role('p01')), `${await role('p11')} | ${await role('p09')}`);
    check('no script errors', !ro.errors.length, ro.errors.join(' | '));
  }

  console.log('The organiser, Run as one page');
  {
    const op = await openApp(b, world({ me: 'g', round: 'active' }));
    await toRunMap(op);
    const vis = await op.evaluate(() => ['tournamentMapSection', 'tournamentRoundSection', 'tournamentStandingsSection'].map(id => !document.getElementById(id).classList.contains('hide')));
    check('map, battles and results all on one page', vis.every(Boolean), JSON.stringify(vis));
    const order = await op.evaluate(() => ['tournamentMapSection', 'tournamentBattlesHeading', 'tournamentStandingsSection'].map(id => document.getElementById(id).getBoundingClientRect().top + scrollY));
    check('in the order a round goes: map, battles, results', order[0] < order[1] && order[1] < order[2]);
    check('the step is called Battles', (await text(op, '#tournamentSteps')).includes('Battles'));
    await op.click('#tStepTab-results'); await op.waitForTimeout(900);
    const top = await op.$eval('#tournamentStandingsSection', e => e.getBoundingClientRect().top);
    check('a step jumps down the page to its part', top < 300, String(top));
    check('and the page is still all there', await op.evaluate(() => !document.getElementById('tournamentMapSection').classList.contains('hide')));
  }

  console.log('The organiser, Set up');
  {
    const w3 = world({ me: 'g', round: 'completed', withMoves: true });
    w3.db.tournament_pairings.push({ id: 'd9', round_id: 'r2', tournament_id: 't1', campaign_id: 'c1', player_a_id: 'p17', player_b_id: 'p18', table_number: 9, mission_id: 'm9' });
    const su = await openApp(b, w3);
    await su.evaluate(() => document.getElementById('adminModeToggle').click()); await su.waitForTimeout(1000);
    await su.evaluate(() => document.getElementById('setupNavBtn').click()); await su.waitForTimeout(1500);
    check('Set up shows Tables, not Rounds', (await text(su, '#setupRoundsHeading')) === 'Tables' && (await text(su, '#setupNavBtn')).length > 0);
    check('a card for each of the 13 tables', (await su.$$eval('#setupRounds [data-setup-table-pick]', es => es.length)) === 13);
    check('the tables can be changed while the event runs', await su.$eval('#setupTblPick9', e => !e.disabled));
    await su.selectOption('#setupTblPick9', 'm1'); await su.waitForTimeout(800);
    const after = await su.evaluate(() => ({ set: window.__FAKE_DB.campaigns[0].settings.warcastle.tables[9], draft: window.__FAKE_DB.tournament_pairings.find(p => p.id === 'd9').mission_id, played: window.__FAKE_DB.tournament_pairings.find(p => p.round_id === 'r1' && p.table_number === 9).mission_id }));
    check('a table\'s scenario changes for the rounds still to come', after.set === 'm1' && after.draft === 'm1' && after.played === 'm9', JSON.stringify(after));
    await su.click('#setupTblScn4'); await su.waitForTimeout(1200);
    check('a table\'s scenario has no deployment step', !(await su.$('#mapShapeSelect')) && (await su.$eval('#battlefieldOverlay .battlefield-svg title', e => e.textContent)).includes('No deployment'));
    await su.fill('#bfEventName', 'Table four'); await su.click('#mapRandomBtn'); await su.waitForTimeout(400);
    check('nor after a random set-up', !(await su.$('#mapShapeSelect')));
    await su.click('#battlefieldOverlayDone'); await su.waitForTimeout(1500);
    const saved = await su.evaluate(() => { const id = window.__FAKE_DB.campaigns[0].settings.warcastle.tables[4]; return window.__FAKE_DB.missions.find(m => m.id === id)?.terrain; });
    check('it saves with no deployment', saved && saved.deployment === null && saved.builder?.shape === 'none', JSON.stringify(saved?.deployment));
    check('no script errors', !su.errors.length, su.errors.join(' | '));
  }

  console.log('The organiser, before the event: Set up › Map and Entrants');
  {
    const w4 = world({ me: 'g' });
    Object.assign(w4.db.tournaments[0], { status: 'setup', current_round: 0, entrants_locked_at: null });
    w4.db.tournament_rounds = []; w4.db.tournament_pairings = []; w4.db.tournament_entrants = [];
    w4.db.campaign_member_admin = w4.db.campaign_members.filter(m => m.role === 'player').map(m => ({ campaign_id: 'c1', user_id: m.user_id, checked_in_at: null, list_checked_at: null, note: null }));
    // placed the night before: all but wc-test-23 and 24 (area 12's)
    const pid = i => `p${String(i).padStart(2, '0')}`;
    w4.db.warcastle_moves = Array.from({ length: 26 }, (_, i) => i).filter(i => i !== 22 && i !== 23)
      .map((i, k) => ({ id: 'mv' + i, tournament_id: 't1', campaign_id: 'c1', round_number: 1, player_id: pid(i + 1), from_area: null, to_area: Math.floor(i / 2) + 1, seq: k + 1 }));
    const en = await openApp(b, w4);
    en.on('dialog', d => d.accept());
    await en.evaluate(() => document.getElementById('adminModeToggle').click()); await en.waitForTimeout(1000);
    await en.evaluate(() => document.getElementById('setupNavBtn').click()); await en.waitForTimeout(1200);
    const tabs = await en.$$eval('#adminSubnav [data-section]', es => es.map(e => e.textContent.trim()));
    check('Set up: Map, then Entrants', tabs.slice(-2).join() === 'Map,Entrants', tabs.join());
    check('Run has no Map step before the event', !(await en.$eval('#tournamentSteps', e => e.innerText)).includes('Map'));
    await en.click('#adminSubnav [data-section="admin-wcmap"]'); await en.waitForTimeout(1200);
    check('the map is in Set up, a piece for everyone, before the lock', await en.$eval('#tournamentMapSection', e => !!e.closest('#adminWcMapPanel') && !e.classList.contains('hide'))
      && (await en.$$eval('#adminWcMapPanel [data-wc-token]', es => es.length)) === 26);
    check('two still to place', (await en.$$eval('#tournamentMapQueue [data-wc-pick]', es => es.filter(e => e.textContent.trim() === 'Place').length)) === 2);
    check('no Make pairings in Set up', !(await en.$('#adminWcMapPanel [data-wc-make]')));
    await en.click('[data-wc-pick="p23"]'); await en.waitForTimeout(800);
    await tapArea(en, '#tournamentMapWrap', 1715, 195, { mouse: true });
    check('placed before the lock', (await en.evaluate(() => window.__FAKE_DB.warcastle_moves.find(m => m.player_id === 'p23')?.to_area)) === 12);

    await en.click('#adminSubnav [data-section="admin-entrants"]'); await en.waitForTimeout(1200);
    check('check-in, the picker and Lock entrants are there', await en.evaluate(() => ['adminCheckInSection', 'tournamentEntrantsSection'].every(id => { const e = document.getElementById(id); return e.closest('#adminEntrantsPanel') && !e.classList.contains('hide'); })
      && !!document.querySelector('#adminEntrantsPanel #tournamentLockEntrantsBtn')));
    check('everyone to check in', (await text(en, '#adminCheckInCount')).startsWith('0 of 26'));
    for (let i = 0; i < 26; i++) { await en.evaluate(k => document.querySelectorAll('#adminCheckInList [data-check-in]')[k].click(), i); await en.waitForTimeout(80); }
    await en.waitForTimeout(600);
    check('all checked in', (await text(en, '#adminCheckInCount')).startsWith('26 of 26'), await text(en, '#adminCheckInCount'));
    await en.click('#checkInLockBtn'); await en.waitForTimeout(1500);
    await en.click('#tournamentLockEntrantsBtn'); await en.waitForTimeout(2000);
    check('locked: Start event', await en.$eval('#tournamentLockedActionsSection', e => !e.classList.contains('hide') && !!e.closest('#adminEntrantsPanel')) && (await text(en, '#tournamentStartBtn')) === 'Start event');
    check('26 entrants', (await en.evaluate(() => window.__FAKE_DB.tournament_entrants.filter(e => e.status === 'active').length)) === 26);
    await en.click('#tournamentStartBtn'); await en.waitForTimeout(1500);
    check('it won\'t start with an army still to place', (await en.evaluate(() => window.__FAKE_DB.tournaments[0].status)) === 'setup'
      && (await text(en, '#setupEntrantsErr')).includes('wc-test-24'), await text(en, '#setupEntrantsErr'));
    await en.click('#adminSubnav [data-section="admin-wcmap"]'); await en.waitForTimeout(1000);
    await en.click('[data-wc-pick="p24"]'); await en.waitForTimeout(800);
    await tapArea(en, '#tournamentMapWrap', 1715, 195, { mouse: true });
    await en.click('#adminSubnav [data-section="admin-entrants"]'); await en.waitForTimeout(1000);
    await en.click('#tournamentStartBtn'); await en.waitForTimeout(2500);
    const db = await en.evaluate(() => ({ status: window.__FAKE_DB.tournaments[0].status, pr: window.__FAKE_DB.tournament_pairings }));
    check('started: round 1\'s pairings made from the map', db.status === 'active' && db.pr.length === 13 && db.pr.every(p => p.mission_id === 'm' + p.table_number && p.warcastle?.rolled), `${db.status} ${db.pr.length}`);
    check('on to Run, at the map', await en.$eval('#adminTournamentsPanel', e => !e.classList.contains('hide')) && (await text(en, '#tournamentSteps [aria-selected="true"]')).includes('Map')
      && await en.$eval('#tournamentMapSection', e => !e.closest('#adminWcMapPanel')));
    check('Run has no Entrants step', !(await text(en, '#tournamentSteps')).includes('Entrants'));
    check('round 1 is fixed: nothing to place or move', !(await en.$('#tournamentMapSection [data-wc-pick]')) && !(await en.$('#tournamentMapSection [data-wc-make]')));
    check('its tables: each a roll-off', (await text(en, '#tournamentMapPlan .wc-tables')).includes('Area 12 wc-test-23 v wc-test-24, roll-off to attack'), await text(en, '#tournamentMapPlan'));
    check('Set up has no Map once it\'s running', await en.$eval('#wcMapAdminTabBtn', e => e.classList.contains('hide')));
    check('no script errors', !en.errors.length, en.errors.join(' | '));
  }
  console.log('A player, round 1: a roll-off');
  {
    const w5 = world({ me: 'p03' });
    w5.db.tournament_pairings.forEach(p => { p.warcastle = { attacker: p.player_b_id, came_from: null, ambush: false, rolled: true }; });
    const pr = await openApp(b, w5, { phone: true });
    check('Play: roll off for who attacks', (await text(pr, '#tournamentGameCta')).includes('Roll off: the winner attacks.'), await text(pr, '#tournamentGameCta'));
  }

  console.log('The organiser, once the set-up is finalised');
  {
    const w7 = world({ me: 'g' });
    Object.assign(w7.db.tournaments[0], { status: 'setup', current_round: 0, entrants_locked_at: null }); w7.db.tournament_rounds = []; w7.db.tournament_pairings = [];
    const now = new Date().toISOString(); w7.db.campaigns[0].settings.setup = { finalised_at: now, sent_at: now };
    const fz = await openApp(b, w7);
    await fz.evaluate(() => document.getElementById('adminModeToggle').click()); await fz.waitForTimeout(1000);
    await fz.evaluate(() => document.getElementById('setupNavBtn').click()); await fz.waitForTimeout(1200);
    await fz.click('#adminSubnav [data-section="admin-campaign"]'); await fz.waitForTimeout(1500);
    check('Event details says it\'s finalised, and its Edits look switched off', await fz.$eval('#setupLockNote', e => !e.classList.contains('hide'))
      && await fz.$eval('#campaignDatesChangeBtn', e => e.disabled && getComputedStyle(e).opacity < .6));
    await fz.click('#setupLockUnlockBtn'); await fz.waitForTimeout(1500);
    check('Unlock there: the Edits work again', await fz.$eval('#campaignDatesChangeBtn', e => !e.disabled) && await fz.$eval('#setupLockNote', e => e.classList.contains('hide'))
      && (await fz.evaluate(() => window.__FAKE_DB.campaigns[0].settings.setup.finalised_at)) === null);
    await fz.click('#campaignDatesChangeBtn'); await fz.waitForTimeout(900);
    check('and Edit dates opens', await fz.evaluate(() => !document.getElementById('flowOverlay').classList.contains('hide')));
    check('no script errors', !fz.errors.length, fz.errors.join(' | '));
  }

  console.log('The organiser: when and where, together');
  {
    const w8 = world({ me: 'g' });
    Object.assign(w8.db.tournaments[0], { status: 'setup', current_round: 0 }); w8.db.tournament_rounds = []; w8.db.tournament_pairings = [];
    const ww = await openApp(b, w8);
    await ww.evaluate(() => document.getElementById('adminModeToggle').click()); await ww.waitForTimeout(1000);
    await ww.evaluate(() => document.getElementById('setupNavBtn').click()); await ww.waitForTimeout(1200);
    await ww.click('#adminSubnav [data-section="admin-campaign"]'); await ww.waitForTimeout(1500);
    const rows = await ww.$$eval('#adminCampaignPanel .set-row', es => es.filter(e => e.offsetParent).map(e => e.querySelector('.set-k').innerText.replace(/\s*i$/, '').trim()));
    check('one When and where row, no separate Dates, Times or Venue', rows.includes('When and where') && !rows.some(r => ['Dates', 'Times', 'Venue'].includes(r)), rows.join(', '));
    await ww.click('#campaignDatesChangeBtn'); await ww.waitForTimeout(900);
    const opts = await ww.$$eval('#eventStartTime option', o => o.map(x => x.value));
    check('times in 5-minute steps', opts.length === 289 && opts[1] === '00:00' && opts[2] === '00:05' && opts[288] === '23:55');
    await ww.fill('#campaignStartsOn', '2026-11-07'); await ww.selectOption('#eventStartTime', '09:30'); await ww.fill('#eventVenueName', 'Fortenhaf Hall');
    await ww.click('#flowFinishBtn'); await ww.waitForTimeout(1500);
    const st = await ww.evaluate(() => window.__FAKE_DB.campaigns[0].settings);
    check('one Save keeps the day, the start time and the venue', st.starts_on === '2026-11-07' && st.start_time === '09:30' && st.venue_name === 'Fortenhaf Hall');
    check('and the row shows them', (await text(ww, '#campaignDatesValue')).includes('09:30') && (await text(ww, '#campaignDatesValue')).includes('Fortenhaf Hall'));
    check('no script errors', !ww.errors.length, ww.errors.join(' | '));
  }

  console.log('A player, before the event starts');
  {
    const w6 = world({ me: 'p03' });
    Object.assign(w6.db.tournaments[0], { status: 'setup', current_round: 0 }); w6.db.tournament_rounds = []; w6.db.tournament_pairings = [];
    w6.db.warcastle_moves = [{ id: 'mv1', tournament_id: 't1', campaign_id: 'c1', round_number: 1, player_id: 'p03', from_area: null, to_area: 7, seq: 1 }];
    Object.assign(w6.db.campaigns[0].settings, { setup: { sent_at: new Date().toISOString() }, starts_on: '2026-11-14', venue_name: 'Fortenhaf Hall', start_time: '09:30' });
    const h = await openApp(b, w6, { phone: true });
    await h.evaluate(() => [...document.querySelectorAll('#playerTabBar .tab-btn')].find(x => x.dataset.tab === 'game')?.click()); await h.waitForTimeout(1500);
    const hold = await text(h, '#tournamentGameCta .t-hold');
    check('a holding card: the event, not started, their emblem and a countdown', /^NOT STARTED YET WarCastle In \d+ days?, \d+ hours?, \d+ mins?, \d+ secs?/.test(hold)
      && !!(await h.$('#tournamentGameCta .t-hold-emblem[data-faction="dark-elves"]')), hold);
    const c0 = await text(h, '#tHoldCount'); await h.waitForTimeout(1300);
    check('the countdown ticks', (await text(h, '#tHoldCount')) !== c0);
    const tiles = await h.$$eval('#tournamentGameCta .t-hold .dash-kpi', es => es.map(e => e.innerText.replace(/\s+/g, ' ').trim()));
    check('tiles for the briefing, quest, magic items and the war so far', tiles.join() === 'Player briefing SOON,Your quest SOON,Your magic items SOON,The war so far SOON', JSON.stringify(tiles));
    check('the details fold away, with nothing about standings', await h.$eval('#tournamentGameCta .t-hold details', e => !e.open && !/Ties|Scoring|Swiss/.test(e.textContent)));
    check('the pack card isn\'t shown twice', await h.$eval('#eventPackCard', e => e.classList.contains('hide')));
    check('no script errors', !h.errors.length, h.errors.join(' | '));
  }

  console.log('The organiser, on a tablet');
  {
    const tb = await openApp(b, world({ me: 'g', round: 'completed', withMoves: true }));
    await toRunMap(tb);
    const [m, qq] = await tb.$$eval('#tournamentMapWrap .wc-map, #tournamentMapQueue', es => es.map(e => e.getBoundingClientRect().left));
    check('the moves sit to the right of the map', qq > m + 300, `${m} ${qq}`);
    const y0 = await tb.evaluate(() => scrollY);
    await tb.evaluate(() => document.querySelector('#tournamentMapQueue [data-wc-pick="p05"]').click()); await tb.waitForTimeout(600);
    check('picking an army doesn\'t scroll the page', (await tb.evaluate(() => scrollY)) === y0);
  }

  console.log('An ordinary tournament is unchanged');
  const pw = world({ me: 'g' }); pw.db.campaigns[0].settings = {};
  const o = await openApp(b, pw);
  check('Standings tab', (await text(o, '#standingsTabBtn')) === 'Standings');
  check('a narrative campaign keeps Play battle and Free play', await (async () => {
    const nw = world({ me: 'p03' }); Object.assign(nw.db.campaigns[0], { format: 'narrative', settings: {} }); nw.db.tournaments = [];
    const n = await openApp(b, nw);
    return !(await n.$eval('#startGameBtn', e => e.classList.contains('hide'))) && !(await n.$eval('#freePlayBtn', e => e.classList.contains('hide')));
  })());
  await toRunMap(o);
  check('no Map step, and Entrants is in Set up', (await text(o, '#tournamentSteps')).replace(/\(done\)/g, '').replace(/\s+/g, ' ') === '1 Rounds 2 Results');

  await b.close();
  console.log(failures ? `\n${failures} failed` : '\nAll passed');
  process.exit(failures ? 1 : 0);
})();
