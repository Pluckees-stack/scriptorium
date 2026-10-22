// Browser checks for WarCastle (warcastle-brief.md) in the real index.html,
// against a fake Supabase. Serve the repo root, then run:
//   python3 -m http.server 8765 &
//   NODE_PATH=$(npm root -g) node tests/browser/warcastle.cjs
const { chromium } = require('playwright');
const { world } = require('./warcastle-world.cjs');
const { openApp } = require('./app.cjs');
const { WARCASTLE_RPC } = require('./warcastle-rpc.cjs');

let failures = 0;
const check = (label, cond, detail = '') => { if (cond) console.log(`  ok   ${label}`); else { failures++; console.log(`  FAIL ${label}${detail ? ` -- ${detail}` : ''}`); } };
const text = (p, sel) => p.$eval(sel, e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
async function toRunMap(a) {
  await a.evaluate(() => document.getElementById('adminModeToggle').click()); await a.waitForTimeout(1000);
  await a.evaluate(() => document.getElementById('runNavBtn').click()); await a.waitForTimeout(1200);
  // WarCastle, running: its Map tab
  if (await a.evaluate(() => { const b = document.querySelector('#wcRunTabs:not(.hide) [data-wc-run-tab="map"]'); if (b && b.getAttribute('aria-selected') !== 'true') { b.click(); return true; } return false; })) await a.waitForTimeout(1000);
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
  check('between rounds, Event opens on the Map tab', (await text(a, '#wcRunTabs [aria-selected="true"]')) === 'Map');
  check('the round, over the map\'s corner', (await text(a, '#tournamentMapWrap .wc-map > .wc-map-round')) === 'Round 2 moving' && await a.$eval('.wc-round-name', e => getComputedStyle(e).fontFamily.includes('Old London')));
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
    await op.evaluate(() => document.getElementById('adminModeToggle').click()); await op.waitForTimeout(1000);
    await op.evaluate(() => document.getElementById('runNavBtn').click()); await op.waitForTimeout(1200);
    const shown = () => op.evaluate(() => ['tournamentMapSection', 'tournamentRoundSection', 'tournamentStandingsSection'].map(id => { const e = document.getElementById(id); return !e.classList.contains('hide') && !!e.offsetHeight; }));
    check('the tabs, above the box at the top', (await text(op, '#wcRunTabs')) === 'Battles Map Standings Allegiances Supply & Warpstone'
      && await op.evaluate(() => document.getElementById('wcRunTabs').nextElementSibling.id === 'tournamentNext') && await op.$eval('#tournamentSteps', e => e.classList.contains('hide')));
    check('during a round, it opens on Battles, and only Battles', (await text(op, '#wcRunTabs [aria-selected="true"]')) === 'Battles' && JSON.stringify(await shown()) === '[false,true,false]', JSON.stringify(await shown()));
    check('the round arrows in the box', await op.evaluate(() => !!document.querySelector('#tournamentNext > #tRoundTabs .t-round-name')) && !(await op.$('#tRoundTabs [data-t-step]')));
    check('no title, format or points limit', await op.$eval('#tournamentDetailName', e => e.classList.contains('hide')) && await op.$eval('#tournamentDetailMeta', e => !e.offsetParent));
    await op.click('#wcRunTabs [data-wc-run-tab="standings"]'); await op.waitForTimeout(800);
    check('Standings: on its own', JSON.stringify(await shown()) === '[false,false,true]' && await op.$eval('#tRoundTabs', e => !e.offsetParent));
    check('no list of results to amend, but bonuses and penalties', !(await op.$('#tournamentAmendResults')) && (await op.$eval('#tournamentAdjustWrap > summary', e => e.textContent.trim())) === 'Bonuses and penalties', await op.$eval('#tournamentAdjustWrap > summary', e => e.textContent));
    await op.click('#wcRunTabs [data-wc-run-tab="sides"]'); await op.waitForTimeout(800);
    check('Allegiances: just them, open', await op.evaluate(() => { const s = document.getElementById('tournamentMapSection'), w = document.getElementById('tournamentMapSidesWrap');
      return !!s.offsetHeight && w.open && !document.getElementById('tournamentMapConsole').offsetHeight && !document.getElementById('wcTokensAdminWrap').offsetHeight; }));
    await op.click('#wcRunTabs [data-wc-run-tab="tokens"]'); await op.waitForTimeout(800);
    check('Supply & Warpstone: just them', await op.evaluate(() => !!document.getElementById('wcTokensAdmin').offsetParent && !document.getElementById('tournamentMapSidesWrap').offsetHeight));
    await op.click('#wcRunTabs [data-wc-run-tab="map"]'); await op.waitForTimeout(1000);
    const pieces = await op.evaluate(() => ({ n: document.querySelectorAll('#tournamentMapWrap .wc-piece').length, counts: document.querySelectorAll('#tournamentMapWrap .wc-pin-count').length, fixed: [...document.querySelectorAll('#tournamentMapWrap .wc-piece')].every(e => e.classList.contains('is-fixed')) }));
    check('Map during a round: every army\'s piece, not counts, none to move', pieces.n === 26 && !pieces.counts && pieces.fixed, JSON.stringify(pieces));
    check('with the round over its corner', (await text(op, '.wc-map-round')) === 'Round 1 being played');
    check('the bar: Event, then Set up', await op.evaluate(() => { const r = document.getElementById('runNavBtn'), su = document.getElementById('setupNavBtn');
      return r.querySelector('.tab-label').textContent === 'Event' && !!(r.compareDocumentPosition(su) & Node.DOCUMENT_POSITION_FOLLOWING); }));
    check('no script errors', !op.errors.length, op.errors.join(' | '));
  }

  console.log('The organiser: the battles, coloured by result, and a result that\'s in opens to read');
  {
    const wb = world({ me: 'g', round: 'active' }), pr = wb.db.tournament_pairings;
    Object.assign(pr[0], { result: 'a_win', vp_a: 1500, vp_b: 50 });   // 1,450: crushing at 2,000
    Object.assign(pr[1], { result: 'b_win', vp_a: 600, vp_b: 1000 });  // 400: marginal
    Object.assign(pr[2], { result: 'draw', vp_a: 700, vp_b: 700 });
    const bt = await openApp(b, wb);
    await bt.evaluate(() => document.getElementById('adminModeToggle').click()); await bt.waitForTimeout(1000);
    await bt.evaluate(() => document.getElementById('runNavBtn').click()); await bt.waitForTimeout(1500);
    const rows = await bt.$$eval('#tournamentPairings .t-match', es => es.slice(0, 4).map(r => ({ sides: [...r.querySelectorAll('.t-side')].map(x => [x.className.replace(/\s+/g, ' '), x.style.getPropertyValue('--s'), x.innerText.replace(/\s+/g, ' ').trim(), !!x.querySelector('.faction-emblem')]),
      res: r.querySelector('.t-table-res').innerText.trim() })));
    check('each side: badge, name and army', rows[0].sides[0][2] === 'wc-test-01 High Elf Realms' && rows[0].sides[1][2] === 'wc-test-02 Wood Elf Realms' && rows[0].sides.every(x => x[3]), JSON.stringify(rows[0]));
    check('the winner green, the loser red, deeper for a crushing win', rows[0].sides[0][0] === 't-side is-a is-win' && rows[0].sides[1][0] === 't-side is-b is-loss' && rows[0].sides[0][1] === '1' && rows[1].sides[1][1] === '0.35', JSON.stringify(rows.slice(0, 2).map(r => r.sides.map(x => [x[0], x[1]]))));
    check('named results', rows[0].res === 'wc-test-01: Crushing Victory · 1,500–50' && rows[1].res === 'wc-test-04: Marginal Victory · 600–1,000' && rows[2].res === 'Draw · 700–700', rows.map(r => r.res).join(' | '));
    check('a draw yellow both sides; not played, no colour', rows[2].sides.every(x => x[0].endsWith('is-draw')) && rows[3].sides.every(x => !/is-(win|loss|draw)/.test(x[0])) && rows[3].res === 'Playing');
    const lock = async () => bt.evaluate(() => ({ fields: [...document.querySelectorAll('#tAmendStep input, #tAmendStep select')].map(f => f.disabled), btn: document.getElementById('flowFinishBtn').textContent }));
    await bt.click('#tournamentPairings [data-amend-pairing="pr1"]'); await bt.waitForTimeout(800);
    let l = await lock();
    check('a submitted result opens to read, with Edit', l.fields.length > 2 && l.fields.every(Boolean) && l.btn === 'Edit', JSON.stringify(l));
    await bt.click('#flowFinishBtn'); await bt.waitForTimeout(400);
    l = await lock();
    check('Edit unlocks it, and the button saves', l.fields.every(f => !f) && l.btn === 'Save' && !(await bt.evaluate(() => document.getElementById('flowOverlay').classList.contains('hide'))));
    await bt.click('#flowCloseBtn'); await bt.waitForTimeout(400);
    await bt.click('#tournamentPairings [data-amend-pairing="pr5"]'); await bt.waitForTimeout(800);
    l = await lock();
    check('no result yet: straight in to enter it', l.fields.every(f => !f) && l.btn === 'Save');
    await bt.click('#flowCloseBtn'); await bt.waitForTimeout(400);
    check('no script errors', !bt.errors.length, bt.errors.join(' | '));
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
    await en.evaluate(() => document.getElementById('adminModeToggle').click()); await en.waitForTimeout(1000);
    await en.evaluate(() => document.getElementById('setupNavBtn').click()); await en.waitForTimeout(1200);
    const tabs = await en.$$eval('#adminSubnav [data-section]', es => es.map(e => e.textContent.trim()));
    check('Set up: Map, Entrants, then Start', tabs.slice(-3).join() === 'Map,Entrants,Start', tabs.join());
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
    check('locked: Unlock stays in Entrants, Start is in its own tab', await en.$eval('#tournamentLockedActionsSection', e => !e.classList.contains('hide') && !!e.closest('#adminEntrantsPanel'))
      && await en.$eval('#tournamentStartBtn', e => e.classList.contains('hide')));
    check('26 entrants', (await en.evaluate(() => window.__FAKE_DB.tournament_entrants.filter(e => e.status === 'active').length)) === 26);
    await en.click('#adminSubnav [data-section="admin-wcstart"]'); await en.waitForTimeout(1000);
    const ready = () => en.$$eval('#wcReadyList li', es => es.map(e => [e.querySelector('strong').textContent, e.classList.contains('done'), e.querySelector('.sub').textContent, e.querySelector('button, input')?.textContent || e.querySelector('input')?.type || '']));
    let r = await ready();
    check('the checklist, each with where to go', JSON.stringify(r.map(x => [x[0], x[1]])) === JSON.stringify([['Entrants locked', true], ['Map set up', false], ['Scenarios done', true], ['Briefings sent out', false], ['Quests sent out', false], ['Everyone checked in', true]]), JSON.stringify(r));
    check('what\'s left on each', r[1][2] === '1 still to place' && r[1][3] === 'Map' && r[5][2] === '26 of 26 checked in', JSON.stringify(r));
    check('Start waits on the map', await en.$eval('#wcStartBtn', e => e.disabled));
    check('check-in below it, everyone listed', (await en.$$eval('#wcCheckInList [data-wc-check-in]', es => es.length)) === 26 && (await text(en, '#wcCheckInCount')).startsWith('26 of 26'));
    await en.evaluate(() => document.querySelector('#wcCheckInList [data-wc-check-in="p05"]').click()); await en.waitForTimeout(800);
    check('ticking someone off: counted', (await text(en, '#wcCheckInCount')).startsWith('25 of 26') && (await ready())[5][1] === false);
    await en.evaluate(() => document.querySelector('#wcCheckInList [data-wc-check-in="p05"]').click()); await en.waitForTimeout(800);
    await en.click('#wcReadyList [data-wc-ready-go="admin-wcmap"]'); await en.waitForTimeout(1000);
    check('its button goes there', await en.$eval('#adminWcMapPanel', e => !e.classList.contains('hide')));
    await en.click('[data-wc-pick="p24"]'); await en.waitForTimeout(800);
    await tapArea(en, '#tournamentMapWrap', 1715, 195, { mouse: true });
    await en.click('#adminSubnav [data-section="admin-wcstart"]'); await en.waitForTimeout(1000);
    check('placed: Start can go, not gold yet', await en.$eval('#wcStartBtn', e => !e.disabled && !e.classList.contains('is-ready')));
    await en.evaluate(() => document.querySelector('#wcReadyList [data-wc-quests]').click()); await en.waitForTimeout(800);
    check('quests: ticked by hand, and kept', (await ready())[4][1] && !!(await en.evaluate(() => window.__FAKE_DB.campaigns[0].settings.warcastle.quests_sent_at)));
    await en.click('#wcStartBtn'); await en.waitForTimeout(2500);
    const begin = await en.evaluate(() => ({ open: !document.getElementById('wcBeginOverlay').classList.contains('hide'), title: document.getElementById('wcBeginTitle').textContent, sub: document.getElementById('wcBeginSub').textContent, focus: document.activeElement?.id }));
    check('it begins: the moment, on the organiser\'s screen', begin.open && begin.title === 'WarCastle' && begin.sub === 'Round 1 begins' && begin.focus === 'wcBeginGo', JSON.stringify(begin));
    await en.click('#wcBeginGo'); await en.waitForTimeout(900);
    check('To battle closes it', await en.$eval('#wcBeginOverlay', e => e.classList.contains('hide')));
    const db = await en.evaluate(() => ({ status: window.__FAKE_DB.tournaments[0].status, pr: window.__FAKE_DB.tournament_pairings }));
    check('started: round 1\'s pairings made from the map', db.status === 'active' && db.pr.length === 13 && db.pr.every(p => p.mission_id === 'm' + p.table_number && p.warcastle?.rolled), `${db.status} ${db.pr.length}`);
    check('on to Event, at the map', await en.$eval('#adminTournamentsPanel', e => !e.classList.contains('hide')) && (await text(en, '#wcRunTabs [aria-selected="true"]')) === 'Map'
      && await en.$eval('#tournamentMapSection', e => !e.closest('#adminWcMapPanel')));
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

  console.log('A player, importing battalions');
  {
    const wb = world({ me: 'p03' });
    const im = await openApp(b, wb);
    await im.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await im.waitForTimeout(800);
    await im.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="import"]').click()); await im.waitForTimeout(800);
    await im.setInputFiles('#impFile', __dirname + '/fixtures/warcastle-battalions.owb.json'); await im.waitForTimeout(1200);
    const picks = await im.$$eval('#impMuster [data-imp-battalion]', es => es.map(e => e.value));
    check('battalions read from the names, the general as Warlord', picks.join() === 'warlord,lord-commander,recruit,recruit,veteran,recruit,recruit,recruit,veteran,recruit,,veteran', picks.join());
    check('the OWB name, less its tag, is the nickname', (await text(im, '#impMuster li')).startsWith("Urluz Gitstompa (Black Orc Warboss)"));
    check('Recruit as Sam built it: 997 points by slot, nothing to fix', /Recruit 6 units · 997 \/ 1,000 points Characters 262 \(26%\) · Core 535 \(54%\) · Special 200 \(20%\) OK/.test(await text(im, '#impBattalions')), JSON.stringify(await text(im, '#impBattalions')));
    check('a unit with no battalion is flagged', (await text(im, '#impBattalions')).includes('Not in a battalion: Da Wiked Wagun (Orc Boar Chariot).'));
    await im.selectOption('[data-imp-battalion="10"]', 'veteran'); await im.waitForTimeout(400);
    check('picked by hand: the flag goes', !(await text(im, '#impBattalions')).includes('Not in a battalion'));
    await im.selectOption('[data-imp-battalion="6"]', 'warlord'); await im.waitForTimeout(400);
    check('a unit in the wrong battalion is flagged', (await text(im, '#impBattalions')).includes('Warlord (stage 1): Only characters belong here.'));
    await im.selectOption('#impBattalionAll', 'recruit'); await im.waitForTimeout(400);
    check('the whole file into one battalion', (await im.$$eval('#impMuster [data-imp-battalion]', es => es.every(e => e.value === 'recruit'))) && (await text(im, '#impBattalions')).includes('Recruit: Rare: none allowed.'));
    await im.selectOption('#impBattalionAll', ''); await im.waitForTimeout(400);
    await im.selectOption('[data-imp-battalion="10"]', 'veteran'); await im.waitForTimeout(300);
    await im.click('#impBtn'); await im.waitForTimeout(2000);
    const saved = await im.evaluate(() => window.__FAKE_DB.units.map(u => [u.name, u.nickname, u.wargear?.battalion]));
    check('imported with each battalion and nickname', saved.length === 12 && saved[0][1] === 'Urluz Gitstompa' && saved[0][2] === 'warlord' && saved[10][2] === 'veteran' && saved[11][2] === 'veteran', JSON.stringify(saved.slice(0, 2)));
    await im.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="mine"]').click()); await im.waitForTimeout(1500);
    check('Lists shows the battalions, each to view', /Warlord \(stage 1\) 1 unit · 225 \/ 250 points Characters 225 View battalion OK/.test(await text(im, '#myBattalions')), JSON.stringify(await text(im, '#myBattalions')));
    // put right later, in the unit editor
    const cid = await im.evaluate(() => window.__FAKE_DB.units.find(u => u.name === 'Orc Boar Chariot').id);
    await im.evaluate((id) => { const x = document.createElement('button'); x.className = 'unit-edit-btn'; x.dataset.unitId = id; document.getElementById('rostersMuster').append(x); x.click(); }, cid);
    await im.waitForTimeout(1500);
    await im.selectOption('#ueBattalion', 'recruit'); await im.click('#unitEditSave'); await im.waitForTimeout(1500);
    check('the unit editor changes a battalion, and says so in its log', await im.evaluate((id) => { const u = window.__FAKE_DB.units.find(u => u.id === id); return u.wargear.battalion === 'recruit' && u.wargear.changeLog.slice(-1)[0].changes.includes('Battalion: Recruit'); }, cid));
    check('and the checks follow', (await text(im, '#myBattalions')).includes('Recruit: 1,098 points: 1,000 at most.'), await text(im, '#myBattalions'));
    check('no script errors', !im.errors.length, im.errors.join(' | '));
  }

  console.log('A player, importing a battalion at a time');
  {
    const w2f = world({ me: 'p03' });
    const tf = await openApp(b, w2f);
    const toImport = async (file) => {
      await tf.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await tf.waitForTimeout(800);
      await tf.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="import"]').click()); await tf.waitForTimeout(800);
      await tf.setInputFiles('#impFile', __dirname + '/fixtures/' + file); await tf.waitForTimeout(1200);
    };
    await toImport('warcastle-recruit.owb.json');
    await tf.click('#impBtn'); await tf.waitForTimeout(2000);
    await toImport('warcastle-veteran.owb.json');
    check('the preview keeps its one line', (await text(tf, '#impExistingNote')) === 'You already have a roster. Choose how to apply this file:');
    await tf.click('#impMergeBtn'); await tf.waitForTimeout(2500);
    const after = await tf.evaluate(() => ({ overlay: !document.getElementById('reconcileRosterOverlay').classList.contains('hide'), units: window.__FAKE_DB.units,
      roster: window.__FAKE_DB.rosters[0], owbUnits: ['characters', 'core', 'special', 'rare'].reduce((n, k) => n + (window.__FAKE_DB.rosters[0].owb_raw[k] || []).length, 0) }));
    check('Veteran added: nothing archived, nothing to match', !after.overlay && after.units.length === 11 && !after.units.some(u => u.archived_at), `${after.overlay} ${after.units.length}`);
    check('the list keeps its name, and its OWB file has both', after.roster.name === "Sam's Orcs" && after.owbUnits === 11, `${after.roster.name} ${after.owbUnits}`);
    // an updated Veteran file without Jumperz: only Jumperz is asked about
    await toImport('warcastle-veteran-less.owb.json');
    await tf.click('#impMergeBtn'); await tf.waitForTimeout(2000);
    const asked = await tf.evaluate(() => [!document.getElementById('reconcileRosterOverlay').classList.contains('hide'), document.getElementById('reconcileRosterOverlay').innerText]);
    check('a unit gone from a battalion’s file: only that one is asked about', asked[0] && asked[1].includes('Doom Diver Catapult') && !asked[1].includes('Black Orc Warboss') && !asked[1].includes('Orc Bigboss'), asked[1].slice(0, 300));
    check('no script errors', !tf.errors.length, tf.errors.join(' | '));
  }

  console.log('A player, two battalion files copied from one list (the same unit in both)');
  {
    const w2c = world({ me: 'p03' });
    const tc = await openApp(b, w2c);
    const toImport = async (file, battalion) => {
      await tc.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await tc.waitForTimeout(800);
      await tc.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="import"]').click()); await tc.waitForTimeout(800);
      await tc.setInputFiles('#impFile', __dirname + '/fixtures/' + file); await tc.waitForTimeout(1200);
      await tc.selectOption('#impBattalionAll', battalion); await tc.waitForTimeout(400);
    };
    const cannons = () => tc.evaluate(() => window.__FAKE_DB.units.filter(u => u.name === 'Cathayan Grand Cannon' && !u.archived_at).map(u => `${u.wargear.battalion}:${u.instance_ref}`).sort().join());
    await toImport('warcastle-cathay-a.owb.json', 'recruit');
    await tc.click('#impBtn'); await tc.waitForTimeout(2000);
    await toImport('warcastle-cathay-b.owb.json', 'veteran');
    await tc.click('#impMergeBtn'); await tc.waitForTimeout(2500);
    check('both cannons kept, one in each battalion', (await cannons()) === 'recruit:cathayan-grand-cannon.wlkczjos,veteran:cathayan-grand-cannon.wlkczjos~veteran', await cannons());
    const ids = await tc.evaluate(() => window.__FAKE_DB.rosters[0].owb_raw.special.map(x => x.id).filter(x => x.startsWith('cathayan-grand-cannon')).sort().join());
    check('and both in the OWB file, each under its own id', ids === 'cathayan-grand-cannon.wlkczjos,cathayan-grand-cannon.wlkczjos~veteran', ids);
    check('nothing archived', !(await tc.evaluate(() => window.__FAKE_DB.units.some(u => u.archived_at))) && (await tc.evaluate(() => window.__FAKE_DB.units.length)) === 13, String(await tc.evaluate(() => window.__FAKE_DB.units.length)));
    await toImport('warcastle-cathay-b.owb.json', 'veteran');
    await tc.click('#impMergeBtn'); await tc.waitForTimeout(2000);
    check('the Veteran file again: matched, nothing new', (await cannons()) === 'recruit:cathayan-grand-cannon.wlkczjos,veteran:cathayan-grand-cannon.wlkczjos~veteran' && (await text(tc, '#impReport')).includes('Nothing new'), await text(tc, '#impReport'));
    await toImport('warcastle-cathay-a.owb.json', 'recruit');
    await tc.click('#impMergeBtn'); await tc.waitForTimeout(2000);
    check('the Recruit file again: matched, nothing new', (await cannons()) === 'recruit:cathayan-grand-cannon.wlkczjos,veteran:cathayan-grand-cannon.wlkczjos~veteran' && (await text(tc, '#impReport')).includes('Nothing new'), await text(tc, '#impReport'));
    check('no script errors', !tc.errors.length, tc.errors.join(' | '));
  }

  console.log('A player, a battalion at a time, and equipping magic items between rounds');
  {
    const we = world({ me: 'p03', round: 'completed' }); we.rpcSource = WARCASTLE_RPC;
    we.rulesIndex = { 'talisman of protection': { url: 'magic-item/talisman-of-protection' } };
    const at = new Date().toISOString(), own = (id, name, points, type) => ({ id, campaign_id: 'c1', player_id: 'p03', name, points, source: 'common', type, unit_id: null, created_at: at });
    we.db.warcastle_tokens = [];
    we.db.warcastle_items = [own('i1', 'Talisman of Protection', 30, 'talisman'), own('i2', 'Ogre Blade', 75, 'weapon'), own('i3', 'Banner of the Steadfast', 50, 'banner')];
    const eq = await openApp(b, we, { phone: true });
    await eq.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await eq.waitForTimeout(800);
    await eq.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="import"]').click()); await eq.waitForTimeout(800);
    await eq.setInputFiles('#impFile', __dirname + '/fixtures/warcastle-cathay-a.owb.json'); await eq.waitForTimeout(1200);
    await eq.selectOption('#impBattalionAll', 'recruit'); await eq.waitForTimeout(300);
    await eq.click('#impBtn'); await eq.waitForTimeout(2000);
    await eq.evaluate(() => document.querySelector('[data-panel="muster"] [data-lists="mine"]').click()); await eq.waitForTimeout(1800);
    check('Lists: the battalions, not the list below', await eq.evaluate(() => document.getElementById('rostersMuster').classList.contains('hide')) && !!(await eq.$('#myBattalions [data-wc-battalion="recruit"]')));
    await eq.click('#myBattalions [data-wc-battalion="recruit"]'); await eq.waitForTimeout(1500);
    const view = await eq.evaluate(() => ({ open: !document.getElementById('wcBattalionOverlay').classList.contains('hide'), title: document.getElementById('wcBattalionTitle').textContent,
      sub: document.getElementById('wcBattalionSub').textContent, cards: document.querySelectorAll('#wcBattalionBody .unit-card').length, focus: document.activeElement?.id }));
    check('View battalion: its cards in the overlay', view.open && view.title === 'Recruit' && view.cards === 8 && view.focus === 'wcBattalionClose', JSON.stringify(view));
    check('with its points by slot', view.sub === '999 / 1,000 points · Characters 171 (17%) · Core 591 (59%) · Special 237 (24%)', view.sub);
    const astro = await eq.evaluate(() => window.__FAKE_DB.units.find(u => u.name === 'Astromancer').id);
    const card = `#wcBattalionBody .unit-card[data-unit-id="${astro}"]`;
    check('a character’s card: Equip magic item, between rounds', await eq.$eval(`${card} [data-wc-equip]`, e => !e.disabled));
    const levy = await eq.evaluate(() => window.__FAKE_DB.units.find(u => u.name === 'Peasant Levy').id);
    check('a unit that can’t carry one: no button', !(await eq.$(`#wcBattalionBody .unit-card[data-unit-id="${levy}"] [data-wc-equip]`)));
    await eq.evaluate((c) => document.querySelector(`${c} [data-wc-equip]`).click(), card); await eq.waitForTimeout(900);
    const pick = await eq.$$eval('#wcEquipList li', es => es.map(e => [e.innerText.replace(/\s+/g, ' ').trim(), e.querySelector('button').disabled]));
    check('only what fits its allowance can go on', JSON.stringify(pick) === JSON.stringify([['Ogre Blade Magic weapon · 75 points · Over its allowance Equip', true], ['Banner of the Steadfast Magic standard · 50 points · Can’t carry a magic standard Equip', true], ['Talisman of Protection Talisman · 30 points Equip', false]]), JSON.stringify(pick));
    await eq.click('#wcEquipList [data-wc-give="i1"]'); await eq.waitForTimeout(1200);
    check('equipped', (await eq.evaluate(() => window.__FAKE_DB.warcastle_items.find(i => i.id === 'i1').unit_id)) === astro);
    await eq.click('#flowFinishBtn'); await eq.waitForTimeout(600);
    check('on its card, with Remove', (await text(eq, `${card} .wc-card-items`)).includes('Talisman of Protection Talisman · 30 points'));
    await eq.evaluate((c) => document.querySelector(`${c} [data-wc-unequip]`).click(), card); await eq.waitForTimeout(1200);
    check('removed: back with their items', (await eq.evaluate(() => window.__FAKE_DB.warcastle_items.find(i => i.id === 'i1').unit_id)) === null && !(await eq.$(`${card} [data-wc-unequip]`)));
    await eq.evaluate((c) => document.querySelector(`${c} .unit-edit-btn`).click(), card); await eq.waitForTimeout(1500);
    check('Edit unit opens over the battalion', await eq.evaluate(() => { const b = document.getElementById('unitEditSave'), r = b.getBoundingClientRect(); return !document.getElementById('unitEditOverlay').classList.contains('hide') && document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2) === b; }));
    await eq.keyboard.press('Escape'); await eq.waitForTimeout(600);
    check('Escape there closes only the editor', await eq.evaluate(() => document.getElementById('unitEditOverlay').classList.contains('hide') && !document.getElementById('wcBattalionOverlay').classList.contains('hide')));
    await eq.click('#wcBattalionClose'); await eq.waitForTimeout(1000);
    check('closed: the list hidden again, focus back on its button', await eq.evaluate(() => document.getElementById('wcBattalionOverlay').classList.contains('hide') && document.getElementById('rostersMuster').classList.contains('hide')
      && document.getElementById('rostersMuster').previousElementSibling?.id === 'allianceSelectRow' && document.activeElement?.dataset.wcBattalion === 'recruit'));
    check('no script errors', !eq.errors.length, eq.errors.join(' | '));
    // while a round is being played, items stay where they are
    const wr = world({ me: 'p03', round: 'active' }); wr.rpcSource = WARCASTLE_RPC;
    wr.db.warcastle_tokens = []; wr.db.warcastle_items = [own('i1', 'Talisman of Protection', 30, 'talisman')];
    wr.db.rosters = await eq.evaluate(() => window.__FAKE_DB.rosters); wr.db.units = await eq.evaluate(() => window.__FAKE_DB.units);
    wr.db.warcastle_items[0].unit_id = astro;
    const ra = await openApp(b, wr, { phone: true });
    await ra.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await ra.waitForTimeout(1800);
    await ra.click('#myBattalions [data-wc-battalion="recruit"]'); await ra.waitForTimeout(1500);
    check('during a round: no equipping or removing', await ra.$eval(`${card} [data-wc-unequip]`, e => e.disabled) && await ra.$eval(`${card} [data-wc-equip]`, e => e.disabled));
    check('no script errors', !ra.errors.length, ra.errors.join(' | '));
  }

  console.log('A player: Supply, Warpstone and magic items');
  {
    const wt = world({ me: 'p03' }); wt.rpcSource = WARCASTLE_RPC;
    wt.rulesIndex = { 'talisman of protection': { url: 'magic-item/talisman-of-protection' } };
    const at = new Date().toISOString();
    wt.db.warcastle_tokens = [{ id: 'a1', campaign_id: 'c1', player_id: 'p03', kind: 'supply', amount: 5, reason: 'award', created_at: at },
      { id: 'a2', campaign_id: 'c1', player_id: 'p03', kind: 'warpstone', amount: 1, reason: 'swap', created_at: at }];
    wt.db.warcastle_items = [];
    const sh = await openApp(b, wt);
    await sh.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await sh.waitForTimeout(1800);
    check('Lists: their Supply and Warpstone', (await text(sh, '#wcTokenTiles')) === '5 SUPPLY 1 WARPSTONE', await text(sh, '#wcTokenTiles'));
    await sh.click('#wcShopBtn'); await sh.waitForTimeout(900);
    check('the shop: Common and their faction’s list', (await sh.$$eval('#wcShopScope button', es => es.map(e => e.textContent))).join() === 'Common,Dark Elves' && (await sh.$$eval('#wcShopList li', es => es.length)) === 83);
    const shop = await sh.evaluate(() => ({ heads: [...document.querySelectorAll('#wcShopList .wg-label')].map(e => e.textContent).join(), names: [...document.querySelectorAll('#wcShopList li strong')].map(e => e.textContent) }));
    check('grouped by type, in the rulebook’s order', shop.heads === 'Magic weapons,Magic armour,Talismans,Arcane items,Enchanted items,Magic standards', shop.heads);
    check('the dearest first', shop.names[0] === 'Ogre Blade' && shop.names.indexOf('Armour of Destiny') < shop.names.indexOf('Charmed Shield*'));
    check('no Battle March items', !shop.names.some(n => /Skirmisher|Helm of Courage|Wyrdstone Shard|Banner of Renown/.test(n)));
    await sh.fill('#wcShopSearch', 'talisman of protection'); await sh.waitForTimeout(300);
    check('each item at its price', (await text(sh, '#wcShopList li')).includes('Talisman of Protection 30 points · 2 Supply'), await text(sh, '#wcShopList li'));
    await sh.click('#wcShopList .rule-link'); await sh.waitForTimeout(800);
    check('an item’s name opens its rules, over the shop', await sh.evaluate(() => { const o = document.getElementById('rulesOverlay'); return !o.classList.contains('hide') && document.getElementById('rulesDialogTitle').textContent === 'Talisman of Protection'
      && document.elementFromPoint(innerWidth / 2, innerHeight / 2)?.closest('#rulesOverlay') === o; }));
    await sh.click('#rulesDialogClose'); await sh.waitForTimeout(300);
    await sh.click('#wcShopList [data-wc-buy="0"]'); await sh.waitForTimeout(1200);
    check('bought: the tokens go, the item is theirs', (await text(sh, '#wcShopHave')) === 'You have 3 Supply and 1 Warpstone.' && (await sh.evaluate(() => window.__FAKE_DB.warcastle_items.map(i => `${i.name}:${i.source}`).join())) === 'Talisman of Protection:common');
    await sh.fill('#wcShopSearch', 'ogre blade'); await sh.waitForTimeout(300);
    check('a 75-point Common item: a Warpstone and 3 Supply, affordable', (await text(sh, '#wcShopList li')).includes('75 points · 3 Supply and 1 Warpstone') && await sh.$eval('#wcShopList [data-wc-buy="0"]', e => !e.disabled));
    await sh.fill('#wcShopSearch', ''); await sh.click('#wcShopScope [data-wc-scope="faction"]'); await sh.waitForTimeout(300);
    check('a faction item: a Warpstone', (await text(sh, '#wcShopList li')).includes('1 Warpstone'));
    await sh.click('#flowFinishBtn'); await sh.waitForTimeout(600);
    check('their items listed', (await text(sh, '#wcMyItems')).includes('Talisman of Protection Talisman · 30 points · not on a unit yet'));
    await sh.click('#wcSendBtn'); await sh.waitForTimeout(900);
    await sh.selectOption('#wcSendTo', 'p04'); await sh.fill('#wcSendSupply', '1');
    await sh.click('#flowFinishBtn'); await sh.waitForTimeout(1200);
    check('sending: confirmed, theirs go down, the other player’s up', (await text(sh, '#wcTokenTiles')) === '2 SUPPLY 1 WARPSTONE'
      && (await sh.evaluate(() => window.__FAKE_DB.warcastle_tokens.filter(t => t.reason === 'received' && t.player_id === 'p04').length)) === 1);
    await sh.click('#wcSendBtn'); await sh.waitForTimeout(900);
    await sh.selectOption('#wcSendTo', 'p04'); await sh.fill('#wcSendSupply', '9');
    await sh.click('#flowFinishBtn'); await sh.waitForTimeout(800);
    check('can’t send more than they have', (await text(sh, '#wcFlowErr')) === 'You have 2 Supply and 1 Warpstone.');
    await sh.click('#flowCloseBtn'); await sh.waitForTimeout(400);
    check('no script errors', !sh.errors.length, sh.errors.join(' | '));
  }

  console.log('The organiser: Supply and Warpstone');
  {
    const wo = world({ me: 'g', round: 'completed', withMoves: true }); wo.rpcSource = WARCASTLE_RPC; wo.db.warcastle_tokens = [];
    wo.db.warcastle_battle_objectives = [];
    wo.db.missions.forEach(m => { m.terrain = { builder: { layout: { markers: [{ x: 18, y: 24 }, { x: 36, y: 24 }, { x: 54, y: 24 }] } } }; });
    const ta = await openApp(b, wo);
    await toRunMap(ta);
    await ta.click('#wcRunTabs [data-wc-run-tab="tokens"]'); await ta.waitForTimeout(1000);
    const row5 = () => ta.evaluate(() => [...document.querySelectorAll('#wcTokensAdmin li')].find(l => l.innerText.includes('wc-test-05')).innerText.replace(/\s+/g, ' ').trim());
    check('a row for every army, a − and + on each', (await ta.$$eval('#wcTokensAdmin li', es => es.length)) === 26 && (await row5()) === 'wc-test-05 Supply − 0 + Warpstone − 0 +', await row5());
    check('no +3 or swap any more', !(await ta.$('[data-wc-award], [data-wc-swap-token]')) && await ta.$eval('[data-wc-adjust="p05"][data-kind="supply"][data-step="-1"]', e => e.disabled));
    for (const [kind, step] of [['supply', 1], ['supply', 1], ['warpstone', 1], ['supply', -1]]) { await ta.click(`[data-wc-adjust="p05"][data-kind="${kind}"][data-step="${step}"]`); await ta.waitForTimeout(700); }
    check('one at a time, each a correction', (await row5()) === 'wc-test-05 Supply − 1 + Warpstone − 1 +' && (await ta.evaluate(() => window.__FAKE_DB.warcastle_tokens.every(t => t.reason === 'correction'))), await row5());
    await ta.evaluate(() => document.getElementById('wcTokensAdminLogWrap').open = true);
    await ta.click('#wcTokensAdminLog [data-wc-undo-token]'); await ta.waitForTimeout(900);
    check('undo the last', (await row5()) === 'wc-test-05 Supply − 2 + Warpstone − 1 +', await row5());
    // the Warpstone draw: one objective a table, for the round coming
    await ta.click('[data-wc-warp-draw]'); await ta.waitForTimeout(1000);
    const draw = await ta.evaluate(() => ({ saved: window.__FAKE_DB.campaigns[0].settings.warcastle.warpstone_draw, rows: [...document.querySelectorAll('#wcWarpDraw li')].map(l => l.innerText.replace(/\s+/g, ' ').trim()) }));
    check('drawn: each table, one of its objectives, where it is', draw.rows.length === 13 && draw.rows.every(r => /^Table \d+ Objective [123] of 3 · \d+″ across, \d+″ in$/.test(r)) && Object.keys(draw.saved['2'] || {}).length === 13, JSON.stringify(draw).slice(0, 300));
    check('and kept, to draw again', (await text(ta, '[data-wc-warp-draw]')) === 'Draw round 2 again');
    // a battle's objectives, in its result: tokens follow
    await ta.click('#wcRunTabs [data-wc-run-tab="battles"]'); await ta.waitForTimeout(1000);
    await ta.evaluate(() => document.querySelector('[data-t-round-step="-1"]')?.click()); await ta.waitForTimeout(900);
    await ta.evaluate(() => document.querySelector('#tRoundTrack [data-amend-pairing="pr2"]').click()); await ta.waitForTimeout(900);
    check('the result sheet: objectives held and the Warpstone one, locked till Edit', await ta.evaluate(() => !!document.getElementById('tWcHeld-a') && document.getElementById('tWcHeld-a').disabled && document.getElementById('tWcWarp').disabled));
    await ta.click('#flowFinishBtn'); await ta.waitForTimeout(300);
    await ta.fill('#tWcHeld-a', '2'); await ta.fill('#tWcHeld-b', '1'); await ta.selectOption('#tWcWarp', 'p04');
    await ta.click('#flowFinishBtn'); await ta.waitForTimeout(1500);
    const got = await ta.evaluate(() => window.__FAKE_DB.warcastle_tokens.filter(t => t.reason === 'battle').map(t => `${t.player_id}:${t.kind}:${t.amount}`).sort().join());
    check('saved: 2 Supply to one, 1 Supply and the Warpstone to the other', got === 'p03:supply:2,p04:supply:1,p04:warpstone:1', got);
    check('no script errors', !ta.errors.length, ta.errors.join(' | '));
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
    check('tiles for the briefing, quest, magic items and the war so far', tiles.join() === 'Player briefing SOON,Your quest SOON,0 Supply · 0 Warpstone YOUR MAGIC ITEMS,The war so far SOON', JSON.stringify(tiles));
    check('the details fold away, with nothing about standings', await h.$eval('#tournamentGameCta .t-hold details', e => !e.open && !/Ties|Scoring|Swiss/.test(e.textContent)));
    check('the pack card isn\'t shown twice', await h.$eval('#eventPackCard', e => e.classList.contains('hide')));
    check('no script errors', !h.errors.length, h.errors.join(' | '));
  }

  console.log('A player, as the event starts: the moment on their device');
  {
    const w7 = world({ me: 'p03' }); w7.showBegin = true;
    Object.assign(w7.db.tournaments[0], { status: 'setup', current_round: 0 }); w7.db.tournament_rounds = []; w7.db.tournament_pairings = [];
    const h = await openApp(b, w7, { phone: true });
    await h.evaluate(() => [...document.querySelectorAll('#playerTabBar .tab-btn')].find(x => x.dataset.tab === 'game')?.click()); await h.waitForTimeout(1500);
    check('waiting: no moment yet', await h.$eval('#wcBeginOverlay', e => e.classList.contains('hide')));
    // the organiser presses Start
    await h.evaluate(() => Object.assign(window.__FAKE_DB.tournaments[0], { status: 'active', current_round: 1 }));
    let open = false;
    for (let i = 0; i < 30 && !open; i++) { await h.waitForTimeout(1000); open = await h.$eval('#wcBeginOverlay', e => !e.classList.contains('hide')); }
    check('within 20 seconds, it begins on their screen too', open && (await text(h, '#wcBeginTitle')) === 'WarCastle' && (await text(h, '#wcBeginSub')) === 'Round 1 begins');
    check('with their own emblem', await h.$eval('#wcBeginEmblem', e => e.dataset.faction === 'dark-elves'));
    await h.keyboard.press('Escape'); await h.waitForTimeout(900);
    check('Escape closes it, and it\'s kept as seen', await h.$eval('#wcBeginOverlay', e => e.classList.contains('hide')) && await h.evaluate(() => localStorage.getItem('scriptorium.wcBegun.c1') === '1'));
    check('no script errors', !h.errors.length, h.errors.join(' | '));
    // opening the app later, once it's begun: shown once
    const w8 = world({ me: 'p04', round: 'active' }); w8.showBegin = true;
    const h2 = await openApp(b, w8, { phone: true });
    await h2.waitForTimeout(1500);
    check('a device opened after it began: shown once', await h2.$eval('#wcBeginOverlay', e => !e.classList.contains('hide')));
  }

  console.log('The organiser: the round length from the timer\'s (i)');
  {
    const wt9 = world({ me: 'g', round: 'active' });
    wt9.db.tournaments[0].round_minutes = 180; wt9.db.tournament_rounds[0].activated_at = new Date().toISOString();
    const tm = await openApp(b, wt9);
    await tm.evaluate(() => document.getElementById('adminModeToggle').click()); await tm.waitForTimeout(1000);
    await tm.evaluate(() => document.getElementById('runNavBtn').click()); await tm.waitForTimeout(1500);
    await tm.click('#tClockBtn'); await tm.waitForTimeout(500);
    check('during a round: the round length, the time left, and pause', (await tm.$$eval('.t-clock-label', es => es.map(e => e.textContent))).join() === 'Round length,Time left' && !!(await tm.$('[data-t-clock="pause"]')));
    await tm.click('[data-t-length="-300"]'); await tm.waitForTimeout(800);
    check('the round length changes for every round', (await tm.evaluate(() => window.__FAKE_DB.tournaments[0].round_minutes)) === 175);
    check('no script errors', !tm.errors.length, tm.errors.join(' | '));
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
