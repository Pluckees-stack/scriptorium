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
async function tapArea(a, hostSel, x, y) {
  const r = await a.$eval(`${hostSel} .wc-map`, e => { const b = e.getBoundingClientRect(); return [b.left, b.top, b.width, b.height]; });
  await a.touchscreen.tap(r[0] + x / 2000 * r[2], r[1] + y / 1333 * r[3]); await a.waitForTimeout(500);
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
  check('the queue marks who moves next', (await a.$$eval('#tournamentMapQueue li.is-next', es => es.length)) === 1);
  check('no (i) on the Map heading', !(await a.$('#tournamentMapHeading .info-btn')));
  await a.click('[data-wc-pick="p03"]'); await a.waitForTimeout(1000);
  await tapArea(a, '#tournamentMapWrap', 1715, 195);
  check('a move: tap the army, then the area', (await a.$eval('[data-wc-pick="p03"]', e => e.closest('li').innerText)).includes('area 2 to 12'));
  // drag a piece: wc-test-05 from area 3 into area 9
  check('a piece for every army on the map', (await a.$$eval('#tournamentMapWrap [data-wc-token]', es => es.length)) === 26);
  {
    await a.$eval('#tournamentMapWrap .wc-map', e => e.scrollIntoView({ block: 'center' })); await a.waitForTimeout(400);
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p05"]', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left, q.top, q.width, q.height]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 20, f[1] + 20, { steps: 4 });
    await a.mouse.move(r[0] + 645 / 2000 * r[2], r[1] + 680 / 1333 * r[3], { steps: 8 }); await a.mouse.up(); await a.waitForTimeout(700);
  }
  check('drag a piece to move it', (await a.$eval('[data-wc-pick="p05"]', e => e.closest('li').innerText)).includes('area 3 to 9'));
  check('a dragged piece stays where it was dropped', await a.evaluate(() => { const sp = window.__FAKE_DB.campaigns[0].settings.warcastle.spots?.p05; return !!sp && Math.abs(sp[0] - 645) < 40 && Math.abs(sp[1] - 680) < 40; }));
  check('a moved army leaves the queue for Moved', (await text(a, '#tournamentMapQueue .wc-done')).includes('wc-test-05'));
  // no crossing: 9 into 12 is turned away
  {
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p17"]', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left, q.top, q.width, q.height]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 20, f[1] + 20, { steps: 4 });
    await a.mouse.move(r[0] + 1715 / 2000 * r[2], r[1] + 195 / 1333 * r[3], { steps: 8 }); await a.mouse.up(); await a.waitForTimeout(700);
  }
  check('a drop with no crossing goes ahead once confirmed, and is flagged', (await a.$eval('[data-wc-pick="p17"]', e => e.closest('li').innerText)).includes('area 9 to 12')
    && (await text(a, '.wc-flags')).includes("wc-test-17: there's no crossing from area 9 to area 12."));
  await a.click('[data-wc-pick="p01"]'); await a.waitForTimeout(1000); await a.click('[data-wc-stay]'); await a.waitForTimeout(500);
  check('a draw staying put is flagged', (await text(a, '.wc-flags')).includes('wc-test-01 drew, so has to move.'));
  await a.click('[data-wc-undo]'); await a.waitForTimeout(500);
  check('undo', !(await a.$eval('[data-wc-pick="p01"]', e => e.closest('li').innerText)).includes('stays'));
  await a.click('[data-wc-make]'); await a.waitForTimeout(1500);
  const made = await a.evaluate(() => window.__FAKE_DB.tournament_pairings.filter(p => p.round_id === 'r2'));
  check('pairings made from the map, each on its area\'s table', made.length && made.every(p => p.table_number >= 1 && p.table_number <= 13 && p.mission_id === 'm' + p.table_number));
  check('no script errors', !a.errors.length, a.errors.join(' | '));

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
  check('no Map step', (await text(o, '#tournamentSteps')).replace(/\(done\)/g, '').replace(/\s+/g, ' ') === '1 Entrants 2 Rounds 3 Results');

  await b.close();
  console.log(failures ? `\n${failures} failed` : '\nAll passed');
  process.exit(failures ? 1 : 0);
})();
