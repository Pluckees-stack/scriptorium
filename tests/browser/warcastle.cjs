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
  check('the map comes first on the tab', await p.$eval('[data-panel="standings"]', e => e.firstElementChild.id === 'wcMapSection'));
  check('no script errors', !p.errors.length, p.errors.join(' | '));

  console.log('A player, after their battle');
  const wd = world({ me: 'p03' }); wd.db.tournament_pairings[1].result = 'draw';
  const pd = await openApp(b, wd, { phone: true });
  const cta = await text(pd, '#tournamentGameCta');
  check('Play: their result, waiting for the round to end', cta.includes('a draw') && cta.includes('Waiting for the round to end.'), cta);
  check('Play: no Play this battle once it\'s played', !(await pd.$('[data-tournament-cta]')));

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
  check('Run opens on the Map step', (await text(a, '#tournamentSteps [aria-selected="true"]')).includes('Map'));
  check('caption', (await text(a, '#tournamentMapRound')) === 'Round 2: moving');
  check('checklist: winners, draws, losers', (await a.$$eval('#tournamentMapPlan h4', es => es.map(e => e.textContent))).join() === 'Winners,Draws,Losers');
  check('no (i) on the Map heading', !(await a.$('#tournamentMapHeading .info-btn')));
  await a.click('[data-wc-pick="p03"]'); await a.waitForTimeout(1000);
  await tapArea(a, '#tournamentMapWrap', 1715, 195);
  check('a move: tap the army, then the area', (await a.$eval('[data-wc-pick="p03"]', e => e.closest('li').innerText)).includes('area 2 to 12'));
  await a.click('[data-wc-pick="p01"]'); await a.waitForTimeout(1000); await a.click('[data-wc-stay]'); await a.waitForTimeout(500);
  check('a draw staying put is flagged', (await text(a, '.wc-flags')).includes('wc-test-01 drew, so has to move.'));
  await a.click('[data-wc-undo]'); await a.waitForTimeout(500);
  check('undo', !(await a.$eval('[data-wc-pick="p01"]', e => e.closest('li').innerText)).includes('stays'));
  await a.click('[data-wc-make]'); await a.waitForTimeout(1500);
  const made = await a.evaluate(() => window.__FAKE_DB.tournament_pairings.filter(p => p.round_id === 'r2'));
  check('pairings made from the map, each on its area\'s table', made.length && made.every(p => p.table_number >= 1 && p.table_number <= 13 && p.mission_id === 'm' + p.table_number));
  check('no script errors', !a.errors.length, a.errors.join(' | '));

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
