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
// waits on what the page shows rather than a set time (a slow run would
// otherwise look too soon)
async function until(a, fn, ms = 8000) {
  for (const end = Date.now() + ms; Date.now() < end; await a.waitForTimeout(100)) if (await fn()) return true;
  return false;
}
// the map at rest: picking an army scrolls to it smoothly, and a tap
// measured mid-scroll lands somewhere else
async function mapSettled(a, hostSel) {
  let last = '';
  await until(a, async () => { const now = await a.$eval(`${hostSel} .wc-map`, e => JSON.stringify(e.getBoundingClientRect())); const still = now === last; last = now; return still; });
}
const rowText = (a, id) => a.$eval(`[data-wc-pick="${id}"]`, e => e.closest('li').innerText).catch(() => '');
async function tapArea(a, hostSel, x, y, { mouse = false } = {}) {
  if (mouse) await a.$eval(`${hostSel} .wc-map`, e => e.scrollIntoView({ block: 'center' }));
  await mapSettled(a, hostSel);
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
  {
    // playing the pairing: the table's scenario, as the organiser set it up
    const q = await openApp(b, w, { phone: true });
    await q.evaluate(() => document.querySelector('[data-tournament-cta]').click());
    await q.waitForSelector('#gameStageMission:not(.hide)', { state: 'attached' });
    await until(q, () => q.$eval('#gameMissionSelect', e => e.value === 'm2'));
    check('Play the pairing: the table\'s scenario, locked', await q.$eval('#gameMissionSelect', e => e.value === 'm2' && e.disabled) && await q.$eval('#gameMissionRandomBtn', e => e.classList.contains('hide')));
    check('Play the pairing: no Edit set-up', await q.$eval('#buildScenarioBtn', e => e.classList.contains('hide')) && await q.$eval('#battlefieldSummaryGame', e => !e.classList.contains('hide')));
    await q.close();
  }
  await p.click('#standingsTabBtn'); await p.waitForTimeout(1500);
  const panel = await text(p, '#wcMapWrap .wc-area');
  check('the map opens on their own area', panel.startsWith('Area 2 · River') && panel.includes('wc-test-03 (you)'));
  check('no game nights in Play', await p.$eval('#gameNightsSection', e => e.classList.contains('hide')));
  check('the map comes first on the tab', await p.$eval('[data-panel="standings"]', e => e.firstElementChild.id === 'wcMapSection'));
  {
    // the organiser's map, without its controls: every army's piece, none to move
    const pieces = await p.evaluate(() => ({ n: document.querySelectorAll('#wcMapWrap .wc-piece').length, counts: document.querySelectorAll('#wcMapWrap .wc-pin-count').length,
      fixed: [...document.querySelectorAll('#wcMapWrap .wc-piece')].every(e => e.classList.contains('is-fixed')), sword: !!document.querySelector('#wcMapWrap [data-wc-token="p03"] .wc-piece-role.is-attacker') }));
    check('Map: every army\'s piece, not counts, none to move', pieces.n === 26 && !pieces.counts && pieces.fixed, JSON.stringify(pieces));
    check('Map: who attacks', pieces.sword, JSON.stringify(pieces));
    check('Map: the round over its corner', (await text(p, '#wcMapWrap .wc-map > .wc-map-round')) === 'Round 1 being played');
    check('Map: no tray, queue or move buttons', !(await p.$('#wcMapSection .wc-tray, #wcMapSection [data-wc-pick], #wcMapSection [data-wc-undo], #wcMapSection [data-wc-make]')));
    check('Map and Battles, Map first', (await text(p, '#wcMapTabs')) === 'Map Battles' && (await text(p, '#wcMapTabs [aria-selected="true"]')) === 'Map');
    await p.click('#wcMapTabs [data-swipe="1"]'); await p.waitForTimeout(800);
    check('Battles: chosen', (await text(p, '#wcMapTabs [aria-selected="true"]')) === 'Battles');
    const tables = await p.$$eval('#wcBattlesCard .t-tables > li', es => es.length);
    check('Battles: every table in the round', tables === 13, String(tables));
    check('Battles: their badges and names', (await text(p, '#wcBattlesCard .t-tables > li:nth-child(2)')).includes('wc-test-03'));
    check('Battles: nothing to tap or edit', !(await p.$('#wcBattlesCard button, #wcBattlesCard [data-amend-pairing], #wcBattlesCard input, #wcBattlesCard select')));
    const open = () => p.evaluate(() => [...document.querySelectorAll('[role="dialog"], dialog')].filter(e => e.offsetParent || e.open).length);
    const before = await open();
    await p.click('#wcBattlesCard .t-match'); await p.waitForTimeout(400);
    check('Battles: a tap opens nothing', (await open()) === before);
  }
  check('no script errors', !p.errors.length, p.errors.join(' | '));

  console.log('A player who lost: their battle names their defeat');
  {
    const wl = world({ me: 'p04' }), pr = wl.db.tournament_pairings;
    Object.assign(pr[1], { result: 'a_win', vp_a: 900, vp_b: 500 });   // p03 v p04, 400: marginal at 2,000
    Object.assign(pr[0], { result: 'b_win', vp_a: 50, vp_b: 1500 });   // someone else's: the winner named
    const lp = await openApp(b, wl, { phone: true });
    await lp.click('#standingsTabBtn'); await lp.waitForTimeout(1500);
    await lp.click('#wcMapTabs [data-swipe="1"]'); await lp.waitForTimeout(800);
    const res = await lp.$$eval('#wcBattlesCard .t-tables > li', es => es.slice(0, 2).map(e => e.querySelector('.t-table-res')?.innerText.trim()));
    check('their own: "Marginal Defeat"', res[1] === 'wc-test-04: Marginal Defeat · 900–500', res.join(' | '));
    check('another battle: the winner\'s victory', res[0] === 'wc-test-02: Crushing Victory · 50–1,500', res.join(' | '));
    check('no script errors', !lp.errors.length, lp.errors.join(' | '));
    await lp.close();
  }

  console.log('A player, after their battle');
  const wd = world({ me: 'p03' }); Object.assign(wd.db.tournament_pairings[1], { result: 'draw', game_id: 950 });
  wd.db.games = [{ id: 950, campaign_id: 'c1', player_id: 'p03', opponent_id: 'p04', result: 'draw', player_vp: 1100, opponent_vp: 1000, confirmation_status: 'confirmed',
    player_breakdown: [{ key: 'units', label: 'Units', vp: 800 }, { key: 'king-is-dead', label: 'King is Dead', vp: 300 }], opponent_breakdown: [{ key: 'units', label: 'Units', vp: 1000 }] }];
  const pd = await openApp(b, wd, { phone: true });
  const cta = await text(pd, '#tournamentGameCta');
  check('Play: their result, waiting for the round to end', cta.includes('Draw') && cta.includes('Round 1') && cta.includes('Waiting for the round to end…'), cta);
  // settled: both players' badges and the score, the detail to look at, nothing to change
  const people = await pd.$$eval('#tournamentGameCta .t-match [data-person]', es => es.map(e => e.dataset.person));
  check('Play: settled, the two players head to head', people.length === 2 && people.includes('p03') && people.includes('p04'), people.join());
  check('Play: settled, the score', /1,000–1,100|1,100–1,000/.test(cta), cta);
  await pd.click('#playerTabBar [data-tab="game"]'); await pd.waitForTimeout(500);
  const detail = await text(pd, '#tournamentGameCta .vp-cols');
  check('Play: settled, each side\'s victory points shown', /King is Dead\s*300 VP/.test(detail) && !(await pd.$('#tournamentGameCta details')), detail);
  check('Play: settled, nothing to amend', !(await pd.$('#tournamentGameCta input, #tournamentGameCta [data-amend-pairing], #tournamentGameCta [data-action]')));
  check('Play: no Play this battle once it\'s played', !(await pd.$('[data-tournament-cta]')));
  // Play: the area and the two players head to head over the button, not the round's other tables
  {
    const h2h = await p.$$eval('#tournamentGameCta .t-match', es => es.map(e => ({ label: e.getAttribute('aria-label'), people: [...e.querySelectorAll('[data-person]')].map(x => x.dataset.person), n: e.querySelector('.t-table-n')?.textContent })));
    check('Play: area and head to head', h2h.length === 1 && h2h[0].label === 'Area 2: wc-test-04 v wc-test-03' && h2h[0].n === undefined && h2h[0].people.join() === 'p04,p03', JSON.stringify(h2h));
    check('Play: the round, then the area in italics', await p.$eval('#tournamentGameCta .wc-play', e => e.querySelector('h3')?.textContent === 'Round 1' && getComputedStyle(e.querySelector('h3 + p')).fontStyle === 'italic' && e.querySelector('h3 + p').textContent === 'Area 2'));
    check('Play: each badge above its name', await p.$eval('#tournamentGameCta .t-side', e => { const b = e.querySelector('.t-side-badge').getBoundingClientRect(), n = e.querySelector('.t-side-who').getBoundingClientRect(); return b.bottom <= n.top + 1; }));
    check('Play: head to head above the button', await p.$eval('#tournamentGameCta .t-match', e => !!(e.compareDocumentPosition(document.querySelector('[data-tournament-cta]')) & Node.DOCUMENT_POSITION_FOLLOWING)));
    check('Play: no other battles listed', !(await p.$('#tournamentGameCta .tb-board')));
    check('Play: the battle centred', await p.$eval('#tournamentGameCta .wc-play', e => getComputedStyle(e).textAlign === 'center'));
  }
  // Briefing, once it's been sent, under the head to head before and after the battle
  check('Play: no Briefing before it\'s sent', !(await p.$('#tournamentGameCta [data-wc-briefing]')));
  check('Play: no Your quest before the quests are sent', !(await p.$('#tournamentGameCta [data-wc-quest]')));
  {
    const wbr = world({ me: 'p03' });
    wbr.db.tournament_pairings.forEach(x => { x.warcastle = { attacker: x.player_b_id, came_from: null, ambush: false, rolled: true }; });
    wbr.db.campaigns[0].settings.setup = { sent_at: '2026-10-25T10:00:00Z' };
    const br = await openApp(b, wbr, { phone: true });
    await br.click('#playerTabBar [data-tab="game"]'); await br.waitForTimeout(800);
    check('Play: Briefing once it\'s sent', !!(await br.$('#tournamentGameCta .wc-play [data-wc-briefing]')));
    await br.click('#tournamentGameCta [data-wc-briefing]');
    check('Briefing opens the event pack', await until(br, async () => !(await br.$eval('#wcBriefingOverlay', e => e.classList.contains('hide'))) && !!(await br.$('#wcBriefingBody dl'))), await text(br, '#wcBriefingBody'));
    const dl = br.waitForEvent('download', { timeout: 10000 }).catch(() => null);
    await br.click('#wcBriefingBody [data-pack-download]');
    check('Briefing: the player pack downloads from it', !!(await dl));
    await br.keyboard.press('Escape'); await br.waitForTimeout(200);
    check('Escape closes it, back on Briefing', await br.$eval('#wcBriefingOverlay', e => e.classList.contains('hide')) && await br.evaluate(() => document.activeElement?.hasAttribute('data-wc-briefing')));
    check('no script errors (Briefing)', !br.errors.length, br.errors.join(' | '));
    await br.close();
    // and after the battle
    wbr.db.tournament_pairings.find(x => x.player_a_id === 'p03' || x.player_b_id === 'p03').result = 'draw';
    const ba = await openApp(b, wbr, { phone: true });
    await ba.click('#playerTabBar [data-tab="game"]'); await ba.waitForTimeout(800);
    check('Play: Briefing after the battle too', (await text(ba, '#tournamentGameCta')).includes('Waiting for the round to end') && !!(await ba.$('#tournamentGameCta [data-wc-briefing]')), await text(ba, '#tournamentGameCta'));
    await ba.close();
  }
  // the round's tables, read-only (the organiser's Play): table 1 won with its breakdown, the rest in progress
  const wb = world({ me: 'g' });
  Object.assign(wb.db.tournament_pairings[0], { result: 'a_win', game_id: 900 });
  wb.db.games = [{ id: 900, player_id: 'p01', opponent_id: 'p02', player_vp: 1250, opponent_vp: 900, confirmation_status: 'confirmed',
    player_breakdown: [{ key: 'units', label: 'Units', vp: 800 }, { key: 'domination', label: 'Domination', vp: 450 }], opponent_breakdown: [{ key: 'units', label: 'Units', vp: 900 }] }];
  const pb = await openApp(b, wb, { phone: true });
  const rows = await pb.$$eval('.tb-board > li', es => es.map(e => e.innerText.replace(/\s+/g, ' ').trim()));
  check('Play: every table in the round', rows.length === 13, String(rows.length));
  check('a finished battle: winner and score', rows[0].startsWith('Area 1: wc-test-01 v wc-test-02 wc-test-01 won, 1,250–900'), rows[0]);
  check('an unfinished one: in progress', rows[2] === 'Area 3: wc-test-05 v wc-test-06 in progress', rows[2]);
  await pb.click('#playerTabBar [data-tab="game"]'); await pb.waitForTimeout(500);
  await pb.click('.tb-board details summary'); await pb.waitForTimeout(300);
  check('tap a finished battle: its score element by element, in columns', /Domination\s*450 VP/.test(await text(pb, '.tb-board details')) && !!(await pb.$('.tb-board details .vp-cols')));
  check('read-only: nothing to edit', !(await pb.$('.tb-board button, .tb-board select, .tb-board input')));

  console.log('A player, their opponent logged the battle');
  {
    const wl = world({ me: 'p03' });
    Object.assign(wl.db.tournament_pairings[1], { game_id: 901 });
    wl.db.games = [{ id: 901, campaign_id: 'c1', player_id: 'p04', opponent_id: 'p03', result: 'win', player_vp: 1500, opponent_vp: 700, campaign_points: 4, opponent_campaign_points: 1,
      confirmation_status: 'pending', played_on: '2026-10-25', player_breakdown: [{ key: 'units', label: 'Units', vp: 1500 }], opponent_breakdown: [{ key: 'units', label: 'Units', vp: 700 }] }];
    wl.rpcSource = `{ confirm_game_result: (args, db) => { const g = db.games.find(x => String(x.id) === String(args.p_game_id)); g.confirmation_status = 'confirmed';
      const pr = db.tournament_pairings.find(x => x.game_id === g.id); if (pr) pr.result = pr.player_a_id === g.player_id ? 'a_win' : 'b_win'; return { data: null, error: null }; } }`;
    const pl = await openApp(b, wl, { phone: true });
    await pl.click('#playerTabBar [data-tab="game"]'); await pl.waitForTimeout(800);
    const cta = await text(pl, '#tournamentGameCta');
    check('Play: what they logged, to confirm there', cta.includes('wc-test-04 logged') && cta.includes('a win for them') && !!(await pl.$('#tournamentGameCta button.act[data-action="confirm-game"]')), cta);
    check('Play: not "waiting for them to confirm"', !cta.includes('Waiting for wc-test-04 to confirm'), cta);
    check('no campaign points in a tournament', !/\bCP\b|campaign points/i.test(cta), cta);
    await pl.click('#tournamentGameCta [data-action="dispute-game-toggle"]'); await pl.waitForTimeout(200);
    check('Something\'s not right opens the dispute box', await pl.$eval('#tournamentGameCta .dispute-form', e => !e.classList.contains('hide'))
      && (await pl.$eval('#tournamentGameCta [data-action="dispute-game-toggle"]', e => e.getAttribute('aria-expanded'))) === 'true');
    await pl.click('#tournamentGameCta [data-action="dispute-game-toggle"]');
    // Needs your attention's Check the result stays on Play, not the Map tab
    await until(pl, async () => !!(await pl.$('#waitingOnYouList [data-wq="confirm"]')));
    await pl.click('#waitingOnYouList [data-wq="confirm"]'); await pl.waitForTimeout(1000);
    check('Check the result stays on Play', await pl.$eval('[data-panel="game"]', e => !e.classList.contains('hide')) && await pl.evaluate(() => document.activeElement?.dataset.action === 'confirm-game'));
    await pl.click('#tournamentGameCta [data-action="confirm-game"]');
    check('confirmed on Play: the result, no button', await until(pl, async () => (await text(pl, '#tournamentGameCta')).includes('Waiting for the round to end…')) && !(await pl.$('#tournamentGameCta [data-action="confirm-game"]')));
    check('no script errors', !pl.errors.length, pl.errors.join(' | '));
    // the one who logged it waits
    const wm = world({ me: 'p04' }); Object.assign(wm.db.tournament_pairings[1], { game_id: 901 }); wm.db.games = wl.db.games.map(g => ({ ...g, confirmation_status: 'pending' }));
    const pm = await openApp(b, wm, { phone: true });
    const mine = await text(pm, '#tournamentGameCta');
    check('who logged it: waiting for the other to confirm', mine.includes('Waiting for wc-test-03 to confirm the result.') && !(await pm.$('#tournamentGameCta [data-action="confirm-game"]')), mine);
    // the other confirms on their device: this one catches up without a reload
    await pm.evaluate(() => { const d = window.__FAKE_DB, g = d.games.find(x => x.id === 901); g.confirmation_status = 'confirmed';
      const pr = d.tournament_pairings.find(x => x.game_id === 901); pr.result = pr.player_a_id === g.player_id ? 'a_win' : 'b_win'; });
    check('who logged it: sees the confirmation within seconds', await until(pm, async () => (await text(pm, '#tournamentGameCta')).includes('Waiting for the round to end…'), 15000), await text(pm, '#tournamentGameCta'));
  }

  console.log('A player, the standings');
  {
    const ws = world({ me: 'p03', round: 'completed' });
    const ps = await openApp(b, ws, { phone: true });
    await ps.click('#standingsTabBtn'); await ps.waitForTimeout(1500);
    const hidden = await text(ps, '#standings');
    check('hidden until the organiser reveals the results', hidden.includes('The standings will be revealed at the end of the event.') && !(await ps.$('#standings table')), hidden);
    const wr = world({ me: 'p03', round: 'completed' });
    wr.db.tournaments[0].final_results_revealed_at = new Date().toISOString();
    wr.db.campaigns[0].settings.soft_results = { p01: { painting: 9 } };
    wr.db.campaigns[0].settings.scoring = { preset: 'official', final: 'overall', soft: { painting: { on: true, weight: 20 }, sports: { on: true, weight: 10 }, favourite: { on: true, weight: 10 } } };
    const pr = await openApp(b, wr, { phone: true });
    await pr.click('#standingsTabBtn'); await pr.waitForTimeout(1500);
    const heads = await pr.$$eval('#standings table.standings th', es => es.map(e => e.textContent.trim()));
    check('once revealed: #, player, W–D–L and score alone', heads.join('|') === '#|Player|W–D–L|Score', heads.join('|'));
    const below = await text(pr, '#standings');
    check('no Best Overall or tie-break lines', !/Best Overall|Ties are split/.test(below), below);
    check('no script errors', !pr.errors.length, pr.errors.join(' | '));
  }

  console.log('A player, while the armies move');
  const w2 = world({ me: 'p03', round: 'completed', withMoves: true });
  w2.db.warcastle_moves.push({ id: 'x', tournament_id: 't1', campaign_id: 'c1', round_number: 2, player_id: 'p03', from_area: 2, to_area: 12, seq: 99 });
  const q = await openApp(b, w2, { phone: true });
  await q.click('#standingsTabBtn'); await q.waitForTimeout(1500);
  check('caption, as the organiser\'s', (await text(q, '#wcMapWrap .wc-map-round')) === 'Round 2 moving');
  check('moved and still to move, as the organiser sees them', await q.evaluate(() => /is-moved/.test(document.querySelector('#wcMapWrap [data-wc-token="p03"]')?.className) && !!document.querySelector('#wcMapWrap .wc-piece.is-waiting')));
  await q.click('#wcMapTabs [data-swipe="1"]'); await q.waitForTimeout(800);
  check('Battles while moving: the round just played', (await text(q, '#wcBattlesCard h3')) === 'Round 1');
  check('they show where they moved to', (await text(q, '#wcMapWrap .wc-area')).startsWith('Area 12'));

  const between = await text(q, '#tournamentGameCta');
  check('Play between rounds: last result, then what\'s next', between.includes('round 1: you won against wc-test-04') && between.includes('Waiting for round 2: the armies are moving.'), between);

  console.log('The organiser, moving the armies');
  const a = await openApp(b, world({ me: 'g', round: 'completed', withMoves: true }), { phone: true });
  await toRunMap(a);
  check('no Game nights in the console', await a.$eval('#nightsAdminTabBtn', e => e.classList.contains('hide')) && !(await text(a, '#adminSubnav')).includes('Game nights'));
  check('between rounds, Event opens on the Map tab', (await text(a, '#wcRunTabs [aria-selected="true"]')) === 'Map');
  check('the round, over the map\'s corner', (await text(a, '#tournamentMapWrap .wc-map > .wc-map-round')) === 'Round 2 Winners · Elves' && await a.$eval('.wc-round-name', e => getComputedStyle(e).fontFamily.includes('Old London')));
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
  check('a move: tap the army, then the area', await until(a, async () => (await rowText(a, 'p03')).includes('area 2 to 12')));
  check('each army\'s faction in the list', (await a.$eval('[data-wc-pick="p03"]', e => e.closest('li').innerText)).includes('Dark Elves'));
  {
    // an area holds two to fight: wc-test-23 and 24 are in area 12, still to move
    await a.click('[data-wc-pick="p05"]'); await a.waitForTimeout(800);
    check('the army being moved: its result and faction', /Losers|Draws|Winners/.test(await text(a, '.wc-picking')) && (await text(a, '.wc-picking')).includes('Warriors of Chaos'), await text(a, '.wc-picking'));
    await tapArea(a, '#tournamentMapWrap', 1715, 195);
    await until(a, async () => (await rowText(a, 'p23')).includes('has to leave'));
    check('a second moving in: those still to move there are told to leave', /wc-test-2[34] and wc-test-2[34] have to leave area 12 on their turn\./.test(await text(a, '#toast'))
      && (await text(a, '.wc-flags')).includes('has to leave area 12 on their turn: wc-test-03 and wc-test-05 hold it.')
      && (await a.$eval('[data-wc-pick="p23"]', e => e.closest('li').innerText)).includes('has to leave'), await text(a, '#toast'));
    a.dialogs.length = 0;
    await a.click('[data-wc-pick="p07"]'); await a.waitForTimeout(800);
    await tapArea(a, '#tournamentMapWrap', 1715, 195);
    await until(a, async () => a.dialogs.length > 0 && (await rowText(a, 'p07')).includes('to 12'));
    check('a third: asked, and flagged as unable to fight there', a.dialogs.some(m => m.startsWith("wc-test-07 can't fight in area 12: wc-test-03 and wc-test-05 already hold it. Move there anyway?"))
      && (await text(a, '.wc-flags')).includes("wc-test-07 can't fight in area 12"), a.dialogs.join(' | '));
    // undo the third's move, then the second's, each once it's gone
    for (const id of ['p07', 'p05']) {
      await a.click('[data-wc-undo]');
      check(`undo: ${id}'s move taken back`, await until(a, async () => !(await rowText(a, id)).includes('to 12') && await a.isEnabled('[data-wc-undo]')));
    }
  }
  // drag a piece: wc-test-05 from area 3 into area 9
  check('a piece for every army on the map', (await a.$$eval('#tournamentMapWrap [data-wc-token]', es => es.length)) === 26);
  {
    await a.$eval('#tournamentMapWrap .wc-map', e => e.scrollIntoView({ block: 'center' })); await mapSettled(a, '#tournamentMapWrap');
    const f = await a.$eval('#tournamentMapWrap [data-wc-token="p05"] .player-icon', e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    const r = await a.$eval('#tournamentMapWrap .wc-map', e => { const q = e.getBoundingClientRect(); return [q.left + e.clientLeft, q.top + e.clientTop, e.clientWidth, e.clientHeight]; });
    await a.mouse.move(f[0], f[1]); await a.mouse.down(); await a.mouse.move(f[0] + 20, f[1] + 20, { steps: 4 });
    await a.mouse.move(r[0] + 645 / 2000 * r[2], r[1] + 680 / 1333 * r[3], { steps: 8 });
    check('while dragging, the piece itself is lifted off the map', await a.evaluate(() => !!document.querySelector('.wc-ghost') && document.querySelector('#tournamentMapWrap [data-wc-token="p05"]').classList.contains('is-dragging')));
    await a.mouse.up();
    // before anything's saved: already there, no snapping back
    const at = await a.$eval('#tournamentMapWrap [data-wc-token="p05"]', e => [parseFloat(e.style.left), parseFloat(e.style.top), e.classList.contains('is-dragging')]);
    check('it lands where it\'s let go, straight away', Math.abs(at[0] - 32.25) < .6 && Math.abs(at[1] - 51.01) < .6 && !at[2] && !(await a.$('.wc-ghost')), JSON.stringify(at));
    await until(a, () => a.evaluate(() => !!window.__FAKE_DB.campaigns[0].settings.warcastle.spots?.p05));
  }
  check('drag a piece to move it', await until(a, async () => (await rowText(a, 'p05')).includes('area 3 to 9')));
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
  check('moving in where two are still to move: not red, no flag (they move on)', await a.evaluate(() => !document.getElementById('tournamentMapWrap')._wc.view.crowded.includes(1)) && !(await text(a, '.wc-flags')).includes('Area 1 has'));
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
    check('Play, not playing in it: every table in the round', (await op.$$('#tournamentGameCta .tb-board > li')).length === 13);
    // and Go to Event, which opens the Event tab
    await op.evaluate(() => document.querySelector('#tournamentGameCta [data-open-event]').click()); await op.waitForTimeout(1800);
    check('Play\'s Go to Event opens the Event tab', await op.evaluate(() => document.body.classList.contains('admin-mode') && document.getElementById('runNavBtn').classList.contains('active')));
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
    check('with the round over its corner', (await text(op, '#tournamentMapWrap .wc-map-round')) === 'Round 1 being played');
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
    // the score on the players' Victory points card: a total from before
    // breakdowns opens in Other; a switch adds its points; Save keeps both
    check('the score on the players\' Victory points card, its total as it was', !!(await bt.$('#tAmendScores .vp-cols')) && /1500/.test(await text(bt, '#amendTotal-player')) && /50/.test(await text(bt, '#amendTotal-opponent')));
    await bt.click('#tAmendScores details:nth-of-type(2) summary'); await bt.waitForTimeout(300);
    await bt.click('label:has(#amend-player-kingIsDead)'); await bt.waitForTimeout(200);
    check('a switch adds its points (King is Dead: 1,600)', /1600/.test(await text(bt, '#amendTotal-player')));
    await bt.click('#flowFinishBtn'); await bt.waitForTimeout(1500);
    const saved = await bt.evaluate(() => window.__FAKE_DB.tournament_pairings.find(x => x.id === 'pr1'));
    check('saved: the new total, each element and what was entered', saved.vp_a === 1600 && saved.vp_detail?.a?.['king-is-dead'] === 100 && saved.vp_detail?.a?.other === 1500 && saved.vp_detail?.entries?.a?.kingIsDead === true, JSON.stringify({ vp_a: saved.vp_a, d: saved.vp_detail }));
    await bt.click('#tournamentPairings [data-amend-pairing="pr1"]'); await bt.waitForTimeout(800);
    check('opened again: as it was saved', /1600/.test(await text(bt, '#amendTotal-player')) && await bt.isChecked('#amend-player-kingIsDead'));
    await bt.click('#flowCloseBtn'); await bt.waitForTimeout(400);
    await bt.click('#tournamentPairings [data-amend-pairing="pr5"]'); await bt.waitForTimeout(800);
    l = await lock();
    check('no result yet: straight in to enter it', l.fields.every(f => !f) && l.btn === 'Save');
    await bt.click('#flowCloseBtn'); await bt.waitForTimeout(400);
    check('no script errors', !bt.errors.length, bt.errors.join(' | '));
  }

  console.log('The organiser re-marks a unit on the amend table');
  {
    const wr = world({ me: 'g', round: 'active' }), pr = wr.db.tournament_pairings[1];
    const army = (list) => list.map(([id, name, points, status]) => ({ id, name, size: 1, points, status }));
    Object.assign(pr, { result: 'a_win', game_id: 'gx' });
    wr.db.games.push({ id: 'gx', campaign_id: 'c1', player_id: pr.player_a_id, opponent_id: pr.player_b_id, result: 'win', player_vp: 300, opponent_vp: 0, confirmation_status: 'confirmed',
      player_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 300, entries: { unitsVp: 300, units: army([['x1', 'Dryads', 300, 'dead']]) } }],
      opponent_breakdown: [{ key: 'units', label: 'Units destroyed', vp: 0, entries: { unitsVp: 0, units: army([['y1', 'Spearmen', 150, null], ['y2', 'Dragon', 600, null]]) } }] });
    const ra = await openApp(b, wr);
    await ra.evaluate(() => document.getElementById('adminModeToggle').click()); await ra.waitForTimeout(1000);
    await ra.evaluate(() => document.getElementById('runNavBtn').click()); await ra.waitForTimeout(1500);
    await ra.click('#tournamentPairings [data-amend-pairing="pr2"]'); await ra.waitForTimeout(800);
    await ra.click('#tAmendScores [data-vp-units="opponent"]'); await ra.waitForTimeout(400);
    check('read before Edit: the units listed, their buttons off', await ra.isVisible('#vpUnitsOverlay') && (await ra.$$eval('#vpUnitsBody .seg-btn', bs => bs.length && bs.every(x => x.disabled))));
    await ra.click('#vpUnitsOverlay [data-close-sheet]'); await ra.waitForTimeout(300);
    await ra.click('#flowFinishBtn'); await ra.waitForTimeout(400);
    await ra.click('#tAmendScores [data-vp-units="opponent"]'); await ra.waitForTimeout(400);
    await ra.click('#vpUnitsBody .seg-btn[data-unit-id="y1"][data-v="dead"]'); await ra.waitForTimeout(200);
    await ra.click('#vpUnitsBody .seg-btn[data-unit-id="y2"][data-v="dead"]'); await ra.waitForTimeout(200);
    check('re-marked: the units\' VP and total follow (750)', /750 VP/.test(await text(ra, '#vpUnitsTotal')) && /750/.test(await text(ra, '#amendTotal-opponent')), await text(ra, '#amendTotal-opponent'));
    await ra.click('#vpUnitsOverlay [data-close-sheet]'); await ra.waitForTimeout(300);
    check('the result follows the score', await ra.inputValue('#tAmendResult') === 'b_win', await ra.inputValue('#tAmendResult'));
    await ra.click('#flowFinishBtn'); await ra.waitForTimeout(1500);
    const saved = await ra.evaluate(() => window.__FAKE_DB.tournament_pairings.find(x => x.id === 'pr2'));
    check('saved: the new total, result and each unit as re-marked', saved.vp_b === 750 && saved.result === 'b_win' && saved.vp_detail?.entries?.b?.units?.map(u => u.status).join() === 'dead,dead', JSON.stringify({ vp_b: saved.vp_b, r: saved.result, e: saved.vp_detail?.entries?.b?.units }));
    await ra.click('#tournamentPairings [data-amend-pairing="pr2"]'); await ra.waitForTimeout(800);
    await ra.click('#tAmendScores [data-vp-units="opponent"]'); await ra.waitForTimeout(400);
    check('opened again: as it was saved', /750/.test(await text(ra, '#amendTotal-opponent')) && await ra.getAttribute('#vpUnitsBody .seg-btn[data-unit-id="y2"][data-v="dead"]', 'aria-pressed') === 'true');
    check('no script errors', !ra.errors.length, ra.errors.join(' | '));
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
    w4.db.tournament_rounds = []; w4.db.tournament_pairings = []; w4.db.tournament_entrants = []; w4.db.warcastle_allegiances = [];
    w4.db.campaign_member_admin = w4.db.campaign_members.filter(m => m.role === 'player').map(m => ({ campaign_id: 'c1', user_id: m.user_id, checked_in_at: null, list_checked_at: null, note: null }));
    // placed the night before: all but wc-test-23 and 24 (area 12's)
    const pid = i => `p${String(i).padStart(2, '0')}`;
    w4.db.warcastle_moves = Array.from({ length: 26 }, (_, i) => i).filter(i => i !== 22 && i !== 23)
      .map((i, k) => ({ id: 'mv' + i, tournament_id: 't1', campaign_id: 'c1', round_number: 1, player_id: pid(i + 1), from_area: null, to_area: Math.floor(i / 2) + 1, seq: k + 1 }));
    const en = await openApp(b, w4);
    await en.evaluate(() => document.getElementById('adminModeToggle').click()); await en.waitForTimeout(1000);
    await en.evaluate(() => document.getElementById('setupNavBtn').click()); await en.waitForTimeout(1200);
    const tabs = await en.$$eval('#adminSubnav [data-section]', es => es.map(e => e.textContent.trim()));
    check('Set up: Map, Entrants, Allegiances, then Start', tabs.slice(-4).join() === 'Map,Entrants,Allegiances,Start', tabs.join());
    check('Run has no Map step before the event', !(await en.$eval('#tournamentSteps', e => e.innerText)).includes('Map'));
    await en.click('#adminSubnav [data-section="admin-wcmap"]'); await en.waitForTimeout(1200);
    check('the map is in Set up, a piece for everyone, before the lock', await en.$eval('#tournamentMapSection', e => !!e.closest('#adminWcMapPanel') && !e.classList.contains('hide'))
      && (await en.$$eval('#adminWcMapPanel [data-wc-token]', es => es.length)) === 26);
    check('two still to place', (await en.$$eval('#tournamentMapQueue [data-wc-pick]', es => es.filter(e => e.textContent.trim() === 'Place').length)) === 2);
    check('no Make pairings in Set up', !(await en.$('#adminWcMapPanel [data-wc-make]')));
    await en.click('[data-wc-pick="p23"]'); await en.waitForTimeout(800);
    await tapArea(en, '#tournamentMapWrap', 1715, 195, { mouse: true });
    check('placed before the lock', (await en.evaluate(() => window.__FAKE_DB.warcastle_moves.find(m => m.player_id === 'p23')?.to_area)) === 12);

    // Allegiances, before the lock: the allegiances and their trackers, no armies yet
    await en.click('#adminSubnav [data-section="admin-wcsides"]'); await en.waitForTimeout(1000);
    check('Set up › Allegiances: the list, open, no fold-out heading', await en.$eval('#tournamentMapSidesWrap', e => !!e.closest('#adminWcSidesPanel') && e.open && !e.classList.contains('hide') && getComputedStyle(e.querySelector('summary')).display === 'none'));
    await en.fill('#wcSideName', 'Chaos'); await en.click('#wcSideAddBtn');
    check('an allegiance added before the lock', await until(en, async () => (await text(en, '#tournamentMapSides .chip')).startsWith('Chaos')) && await en.evaluate(() => window.__FAKE_DB.warcastle_allegiances.length === 1));
    check('no armies to set before the lock', !(await en.$('#tournamentMapSides select')));
    await until(en, async () => !!(await en.$('#wcTrackersAdmin [data-kind="corruption"]')));
    await en.click('#wcTrackersAdmin [data-kind="corruption"]');
    check('its tracker set before the lock', await until(en, () => en.evaluate(() => Object.values(window.__FAKE_DB.campaigns[0].settings.warcastle.trackers?.kinds || {}).includes('corruption'))));
    await en.click('#adminSubnav [data-section="admin-entrants"]'); await en.waitForTimeout(1200);
    check('the picker and Lock entrants are there', await en.evaluate(() => { const e = document.getElementById('tournamentEntrantsSection'); return !!e.closest('#adminEntrantsPanel') && !e.classList.contains('hide'); })
      && !!(await en.$('#adminEntrantsPanel #tournamentLockEntrantsBtn')));
    check('no check-in in Entrants: it\'s on Start', await en.$eval('#adminCheckInSection', e => e.classList.contains('hide')));
    // checked in on Start before the lock
    await en.click('#adminSubnav [data-section="admin-wcstart"]'); await en.waitForTimeout(1000);
    check('everyone to check in, on Start', (await text(en, '#wcCheckInCount')).startsWith('0 of 26'), await text(en, '#wcCheckInCount'));
    for (let i = 0; i < 26; i++) { await en.evaluate(k => document.querySelectorAll('#wcCheckInList [data-wc-check-in]')[k].click(), i); await en.waitForTimeout(80); }
    await until(en, async () => (await text(en, '#wcCheckInCount')).startsWith('26 of 26'));
    check('all checked in', (await text(en, '#wcCheckInCount')).startsWith('26 of 26'), await text(en, '#wcCheckInCount'));
    await en.click('#adminSubnav [data-section="admin-entrants"]'); await en.waitForTimeout(1200);
    await en.evaluate(() => document.querySelectorAll('#tournamentEntrantsPicker .tournament-entrant-pick:not(:checked)').forEach(c => c.click()));
    await en.click('#tournamentLockEntrantsBtn'); await en.waitForTimeout(2000);
    check('locked: Unlock stays in Entrants, Start is in its own tab', await en.$eval('#tournamentLockedActionsSection', e => !e.classList.contains('hide') && !!e.closest('#adminEntrantsPanel'))
      && await en.$eval('#tournamentStartBtn', e => e.classList.contains('hide')));
    check('26 entrants', (await en.evaluate(() => window.__FAKE_DB.tournament_entrants.filter(e => e.status === 'active').length)) === 26);
    // once locked: each army's allegiance, in Set up
    await en.click('#adminSubnav [data-section="admin-wcsides"]'); await en.waitForTimeout(1000);
    check('locked: every army to set', (await en.$$('#tournamentMapSides select[data-wc-side]')).length === 26);
    const chaosId = await en.evaluate(() => window.__FAKE_DB.warcastle_allegiances[0].id);
    await en.selectOption('#wcSide-p05', chaosId);
    check('an army\'s allegiance set before the start', await until(en, () => en.evaluate(id => window.__FAKE_DB.tournament_entrants.find(e => e.player_id === 'p05')?.warcastle_allegiance === id, chaosId)));
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
    check('nor Allegiances: back in Event, as set', await en.$eval('#wcSidesAdminTabBtn', e => e.classList.contains('hide'))
      && await en.$eval('#tournamentMapSidesWrap', e => e.parentElement.id === 'tournamentMapSection' && e.nextElementSibling?.id === 'wcTokensAdminWrap'));
    check('no script errors', !en.errors.length, en.errors.join(' | '));
  }
  console.log('A player, round 1: a roll-off');
  {
    const w5 = world({ me: 'p03' });
    w5.db.tournament_pairings.forEach(p => { p.warcastle = { attacker: p.player_b_id, came_from: null, ambush: false, rolled: true }; });
    const pr = await openApp(b, w5, { phone: true });
    check('Play: a roll-off, no line of text, just the deployment', !(await text(pr, '#tournamentGameCta')).includes('Roll off') && !!(await pr.$('#tournamentGameCta svg.wc-dep')), await text(pr, '#tournamentGameCta'));
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
    // a Favour of the Gods (112, 113): spent when the round it's carried into ends, so no Used button; a spent one is gone
    const wf = world({ me: 'p03', round: 'active' }); wf.rpcSource = WARCASTLE_RPC;
    const favour = (id, used_at) => ({ ...own(id, 'Favour of the Gods', 0, 'enchanted-item'), source: 'favour', unit_id: astro, used_at });
    wf.db.warcastle_tokens = []; wf.db.warcastle_items = [own('i1', 'Talisman of Protection', 30, 'talisman'), favour('f1', null), favour('f0', at)];
    wf.db.warcastle_items[0].unit_id = astro;
    wf.db.rosters = wr.db.rosters; wf.db.units = wr.db.units;
    const fa = await openApp(b, wf, { phone: true });
    await fa.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await fa.waitForTimeout(1800);
    await fa.click('#myBattalions [data-wc-battalion="recruit"]'); await fa.waitForTimeout(1500);
    const items = await text(fa, `${card} .wc-card-items`);
    check('a Favour on its card like any item; a spent one not shown', items.split('Favour of the Gods').length === 2 && items.includes('Talisman of Protection')
      && (await fa.$$(`${card} [data-wc-unequip]`)).length === 2 && !(await fa.$(`${card} [data-wc-unequip="f0"]`)), items);
    check('their items: the spent one not listed', (await text(fa, '#wcMyItems')).split('Favour of the Gods').length === 2, await text(fa, '#wcMyItems'));
    check('no script errors', !fa.errors.length, fa.errors.join(' | '));
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
    // a Warriors of Chaos player: Favour of the Gods is earned, not bought (112)
    const wv = world({ me: 'p05' }); wv.rpcSource = WARCASTLE_RPC;
    wv.db.warcastle_tokens = [{ id: 'v1', campaign_id: 'c1', player_id: 'p05', kind: 'warpstone', amount: 3, reason: 'award', created_at: at }]; wv.db.warcastle_items = [];
    const sv = await openApp(b, wv);
    await sv.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await sv.waitForTimeout(1800);
    await sv.click('#wcShopBtn'); await sv.waitForTimeout(900);
    await sv.click('#wcShopScope [data-wc-scope="faction"]'); await sv.waitForTimeout(300);
    const rows = await sv.$$eval('#wcShopList li', es => es.map(e => ({ name: e.querySelector('strong').textContent, off: e.querySelector('button').disabled, grey: e.classList.contains('is-disabled') })));
    const fav = rows.filter(r => r.name.startsWith('Favour of the Gods'));
    check('Warriors of Chaos: Favour of the Gods greyed out, can’t be bought', fav.length === 1 && fav[0].off && fav[0].grey, JSON.stringify(fav));
    check('the rest of their list can', rows.length > 1 && rows.filter(r => !r.name.startsWith('Favour of the Gods')).every(r => !r.off && !r.grey));
    check('no script errors', !sv.errors.length, sv.errors.join(' | '));
    await sv.close();
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
    const res = await ta.evaluate(() => { const p = window.__FAKE_DB.tournament_pairings.find(x => x.id === 'pr2');
      return { result: p.result, got: window.__FAKE_DB.warcastle_tokens.filter(t => t.reason === 'result').map(t => `${t.player_id === p.player_a_id ? 'a' : 'b'}:${t.kind}:${t.amount}`).sort().join() }; });
    const want = { a_win: 'a:supply:3,b:supply:1', b_win: 'a:supply:1,b:supply:3', draw: 'a:supply:2,b:supply:2' }[res.result];
    check('and the result’s Supply: win 3, draw 2, loss 1', !!want && res.got === want, JSON.stringify(res));
    check('no script errors', !ta.errors.length, ta.errors.join(' | '));
  }

  console.log('Trackers: corruption and Waaagh! energy (111)');
  {
    // Chaos: p02, p03; Orcs: p04; Order: p01. p03 beat p04 on table 2; p01 (Order) beat p02 (Chaos)
    const trackerWorld = (me, { kinds = true } = {}) => {
      const tw = world({ me }); tw.rpcSource = WARCASTLE_RPC;
      tw.db.tournament_pairings.forEach(x => { x.warcastle = { attacker: x.player_b_id, came_from: null, ambush: false, rolled: true }; });
      tw.db.warcastle_allegiances = [['C', 'Chaos'], ['O', 'Orcs'], ['D', 'Order']].map(([id, name]) => ({ id, tournament_id: 't1', campaign_id: 'c1', name, created_at: '2026-10-01T00:0' + id.charCodeAt(0) % 10 + ':00Z' }));
      Object.entries({ p02: 'C', p03: 'C', p04: 'O', p01: 'D' }).forEach(([id, side]) => { tw.db.tournament_entrants.find(e => e.player_id === id).warcastle_allegiance = side; });
      if (kinds) tw.db.campaigns[0].settings.warcastle.trackers = { kinds: { C: 'corruption', O: 'waaagh', D: 'order' } };
      tw.db.warcastle_tracker_submissions = [];
      tw.db.tournament_pairings[0].result = 'a_win'; tw.db.tournament_pairings[1].result = 'a_win'; tw.db.tournament_pairings[2].result = 'draw';
      return tw;
    };
    const tw = trackerWorld('p03');
    const pc = await openApp(b, tw, { phone: true });
    check('after the result: the Chaos player\'s pop-up opens by itself', await until(pc, async () => !(await pc.$eval('#wcTrackerOverlay', e => e.classList.contains('hide')))) && (await text(pc, '#wcTrackerTitle')) === 'Corruption');
    const body = await text(pc, '#wcTrackerBody');
    check('no special feature off its table, no totals', !/Shard|World Roots|Manor|Ritual/.test(body) && !/\b(points|total)\b/i.test(body), body);
    await pc.click('[data-wc-tr="burned"][data-step="1"]'); await pc.click('[data-wc-tr="burned"][data-step="1"]');
    await pc.selectOption('#wcTrKillRank', 'warlord'); await pc.check('#wcTrKillWarlord'); await pc.click('#wcTrKillAdd');
    await pc.selectOption('#wcTrKillRank', 'castellan'); await pc.click('#wcTrKillAdd');
    check('a kill each as a chip', (await pc.$$eval('#wcTrackerBody .chip', es => es.map(e => e.innerText.replace(/\s+/g, ' ').replace('×', '').trim()))).join('|') === 'Warlord · your Warlord|Castellan');
    await pc.click('#wcTrackerSave');
    await until(pc, () => pc.$eval('#wcTrackerOverlay', e => e.classList.contains('hide')));
    const sub = await pc.evaluate(() => window.__FAKE_DB.warcastle_tracker_submissions.find(x => x.player_id === 'p03'));
    check('saved: 2 burned + Warlord 5 + Castellan by another 2 = 9, two Favours', sub?.points === 9 && sub.favour === 2 && sub.track === 'corruption', JSON.stringify(sub));
    check('Play: a Corruption button to change it', await until(pc, async () => (await text(pc, '#tournamentGameCta [data-wc-tracker]')) === 'Corruption'));
    await pc.click('#playerTabBar [data-tab="game"]'); await pc.waitForTimeout(500);
    await pc.click('#tournamentGameCta [data-wc-tracker]');
    check('opens as saved', (await pc.$eval('[data-wc-tr="burned"] + output, #wcTrackerBody output', e => e.textContent)) === '2' && (await pc.$$('#wcTrackerBody .chip')).length === 2);
    await pc.keyboard.press('Escape'); await pc.waitForTimeout(200);
    check('Escape closes it, back on the button', await pc.evaluate(() => document.activeElement?.hasAttribute('data-wc-tracker')));
    // the bars over the map: no numbers
    await pc.click('#standingsTabBtn');
    check('Map: two bars over the map', await until(pc, async () => (await pc.$$('#wcTrackBars .wc-bar')).length === 2));
    const bars = await pc.evaluate(() => ({ text: document.getElementById('wcTrackBars').innerText, labels: [...document.querySelectorAll('#wcTrackBars .wc-bar')].map(e => e.getAttribute('aria-label')),
      first: document.getElementById('wcMapCard').firstElementChild.id }));
    check('no numbers on them, said in words', !/\d/.test(bars.text) && bars.labels.every(l => /^(Chaos corruption|Waaagh! energy): [a-z !]+$/.test(l)) && !/\d/.test(bars.labels.join()), JSON.stringify(bars));
    check('at the top of the map', bars.first === 'wcTrackBars');
    check('no script errors (Chaos player)', !pc.errors.length, pc.errors.join(' | '));
    await pc.close();
    // the Orc player: their own pop-up; a winner on a feature's table gets it offered
    tw.db.tournament_pairings[1].table_number = 4;
    const po = await openApp(b, { ...tw, session: { ...tw.session, user: { ...tw.session.user, id: 'p04' } } }, { phone: true });
    check('the Orc player\'s pop-up: Waaagh! energy', await until(po, async () => !(await po.$eval('#wcTrackerOverlay', e => e.classList.contains('hide'))) && (await text(po, '#wcTrackerTitle')) === 'Waaagh! energy'));
    check('a loser on World Roots\'s table isn\'t offered it', !(await text(po, '#wcTrackerBody')).includes('World Roots'));
    await po.click('[data-wc-tr="monuments"][data-step="1"]'); await po.click('#wcTrackerSave');
    await until(po, () => po.evaluate(() => !!window.__FAKE_DB.warcastle_tracker_submissions.find(x => x.player_id === 'p04')));
    const orc = await po.evaluate(() => window.__FAKE_DB.warcastle_tracker_submissions.find(x => x.player_id === 'p04'));
    check('saved to the Waaagh!, no Favour', orc?.track === 'waaagh' && orc.points === 2 && orc.favour === 0, JSON.stringify(orc));
    await po.close();
    tw.db.tournament_pairings[1].table_number = 2;
    const pw = await openApp(b, { ...tw, db: { ...tw.db, tournament_pairings: tw.db.tournament_pairings.map((x, i) => i === 1 ? { ...x, table_number: 4 } : x) } }, { phone: true });
    await until(pw, async () => !!(await pw.$('#tournamentGameCta [data-wc-tracker]')));
    await pw.evaluate(() => document.getElementById('wcTrackerOverlay').classList.contains('hide') || document.querySelector('#wcTrackerOverlay [data-close-sheet]').click());
    await pw.click('#playerTabBar [data-tab="game"]'); await pw.waitForTimeout(500);
    await pw.click('#tournamentGameCta [data-wc-tracker]');
    check('a winner on World Roots\'s table is offered it', (await text(pw, '#wcTrackerBody')).includes('World Roots'));
    await pw.close();
    // a player with no tracker, and an event with none set
    const pn = await openApp(b, { ...tw, session: { ...tw.session, user: { ...tw.session.user, id: 'p05' } } }, { phone: true });
    await pn.waitForTimeout(1500);
    check('no tracker: no button, no pop-up', !(await pn.$('[data-wc-tracker]')) && await pn.$eval('#wcTrackerOverlay', e => e.classList.contains('hide')));
    await pn.close();
    const none = await openApp(b, trackerWorld('p03', { kinds: false }), { phone: true });
    await none.waitForTimeout(1500);
    await none.click('#standingsTabBtn'); await none.waitForTimeout(1500);
    check('no trackers set: no bars, no button', await none.$eval('#wcTrackBars', e => e.classList.contains('hide')) && !(await none.$('[data-wc-tracker]')));
    check('no script errors (no trackers)', !none.errors.length, none.errors.join(' | '));
    await none.close();
    // the organiser: Run › Allegiances
    // (each page keeps its own fake database: the two submissions above, as saved)
    tw.db.warcastle_tracker_submissions = [
      { id: 'ts1', tournament_id: 't1', campaign_id: 'c1', round_id: 'r1', pairing_id: 'pr2', player_id: 'p03', track: 'corruption', points: 9, favour: 2,
        items: { burned: 2, monuments: 0, big_units: 0, kills: [{ rank: 'warlord', by_warlord: true }, { rank: 'castellan', by_warlord: false }], features: [], ritual: false }, updated_at: '2026-10-29T10:00:00Z' },
      { id: 'ts2', tournament_id: 't1', campaign_id: 'c1', round_id: 'r1', pairing_id: 'pr2', player_id: 'p04', track: 'waaagh', points: 2, favour: 0,
        items: { burned: 0, monuments: 1, big_units: 0, kills: [], features: [], ritual: false }, updated_at: '2026-10-29T10:01:00Z' }];
    const ow = { ...tw, session: { ...tw.session, user: { ...tw.session.user, id: 'g' } } };
    const og = await openApp(b, ow);
    await toRunMap(og);
    await og.click('#wcRunTabs [data-wc-run-tab="sides"]');
    check('Allegiances: Trackers, a switch for each', await until(og, async () => (await og.$$('#wcTrackersAdmin [role="radiogroup"]')).length === 3)
      && (await text(og, '#wcTrackersAdmin [role="radiogroup"]')) === 'None Corruption Waaagh! Order');
    await until(og, async () => (await text(og, '#wcTrackersAdmin')).includes('Most corruption'));
    const adm = await text(og, '#wcTrackersAdmin');
    // 2 Chaos armies: the bar ends at 60; 9 scored, less 2 for the Order win over Chaos
    check('corruption: the figures', adm.includes('7/ 60') && /steps passed/i.test(adm) && /1 \(in play\)\s*9\s*1\s*2\s*7 \/ 60\s*wc-test-03/.test(adm), adm);
    check('Waaagh!: the figures', /energy/i.test(adm) && /next rung/i.test(adm) && /1 \(in play\)\s*2\s*6\s*2\s*in play/.test(adm), adm);
    check('the sizes kept for the round', await og.evaluate(() => JSON.stringify(window.__FAKE_DB.campaigns[0].settings.warcastle.trackers.sizes?.['1'])) === '{"chaos":2,"orc":1,"order":1}');
    await og.evaluate(() => { document.getElementById('wcTrackerSubsWrap').open = true; });
    check('every submission', (await og.$$('#wcTrackerSubsWrap li')).length === 2 && (await text(og, '#wcTrackerSubsWrap')).includes('Favour of the Gods 2'));
    await og.evaluate(() => [...document.querySelectorAll('#wcTrackerSubsWrap li')].find(l => l.innerText.includes('wc-test-04')).querySelector('[data-wc-sub-del]').click());
    check('removed, after Are you sure?', await until(og, () => og.evaluate(() => window.__FAKE_DB.warcastle_tracker_submissions.length === 1)) && og.dialogs.some(d => d.startsWith('Are you sure?')));
    await og.click('#wcTrackersAdmin [data-wc-kind="O"][data-kind=""]');
    check('a tracker switched off', await until(og, () => og.evaluate(() => !('O' in window.__FAKE_DB.campaigns[0].settings.warcastle.trackers.kinds)))
      && await og.evaluate(() => document.activeElement?.matches('[data-wc-kind="O"][data-kind=""]')));
    check('no script errors (organiser)', !og.errors.length, og.errors.join(' | '));
    await og.close();
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
    check('no Go to Event for a player', !(await h.$('#tournamentGameCta [data-open-event]')));
    const c0 = await text(h, '#tHoldCount'); await h.waitForTimeout(1300);
    check('the countdown ticks', (await text(h, '#tHoldCount')) !== c0);
    const tiles = await h.$$eval('#tournamentGameCta .t-hold .dash-kpi', es => es.map(e => e.innerText.replace(/\s+/g, ' ').trim()));
    check('tiles for their quest (not sent yet) and magic items', tiles.join() === 'Not sent yet YOUR QUEST,0 Supply · 0 Warpstone YOUR MAGIC ITEMS', JSON.stringify(tiles));
    check('Your quest: nothing to open before it\'s sent', !(await h.$('#tournamentGameCta [data-wc-quest]')));
    check('the details fold away, with nothing about standings', await h.$eval('#tournamentGameCta .t-hold details', e => !e.open && !/Ties|Scoring|Swiss/.test(e.textContent)));
    check('the pack card isn\'t shown twice', await h.$eval('#eventPackCard', e => e.classList.contains('hide')));
    check('no script errors', !h.errors.length, h.errors.join(' | '));
  }

  console.log('The organiser: quests in Set up › Entrants');
  {
    const wq = world({ me: 'g' });
    Object.assign(wq.db.tournaments[0], { status: 'setup', current_round: 0, entrants_locked_at: null });
    wq.db.tournament_rounds = []; wq.db.tournament_pairings = []; wq.db.tournament_entrants = []; wq.db.warcastle_quests = [];
    const o = await openApp(b, wq);
    await o.evaluate(() => document.getElementById('adminModeToggle').click()); await o.waitForTimeout(1000);
    await o.evaluate(() => document.getElementById('setupNavBtn').click()); await o.waitForTimeout(1200);
    await o.click('#adminSubnav [data-section="admin-entrants"]'); await o.waitForTimeout(1200);
    check('Quests under the entrants, everyone who\'s signed up', await o.$eval('#wcQuestsSection', e => !e.classList.contains('hide') && !!e.closest('#adminEntrantsPanel'))
      && (await o.$$eval('#wcQuestsList [data-wc-quest-edit]', es => es.length)) === 26);
    check('the entrants picker is still there', await o.$eval('#tournamentEntrantsSection', e => !e.classList.contains('hide')));
    check('none written yet', (await text(o, '#wcQuestsCount')) === '0 of 26 written', await text(o, '#wcQuestsCount'));
    await o.click('#wcQuestsList [data-wc-quest-edit="p03"]'); await o.waitForTimeout(700);
    const steps = await o.$$eval('#flowBody .bf-tabs [role="tab"]', es => es.map(e => e.getAttribute('aria-label')));
    check('Edit: Briefing, then Quest', steps.join() === '1. Briefing,2. Quest', steps.join());
    // the briefing: typed, then made bold and a heading with the toolbar
    await o.fill('#wcQuestBriefing', 'Orders\n\nHold the bridge.');
    await o.$eval('#wcQuestBriefing', e => e.setSelectionRange(0, 0));
    await o.click('#wcQuestBriefingStep [data-quest-fmt="heading"]');
    check('Heading marks the line', (await o.$eval('#wcQuestBriefing', e => e.value)).startsWith('## Orders\n\nHold the bridge.'), JSON.stringify(await o.$eval('#wcQuestBriefing', e => e.value)));
    await o.$eval('#wcQuestBriefing', e => { const at = e.value.indexOf('bridge'); e.setSelectionRange(at, at + 6); });
    await o.click('#wcQuestBriefingStep [data-quest-fmt="bold"]');
    check('Bold wraps the words', (await o.$eval('#wcQuestBriefing', e => e.value)).includes('Hold the **bridge**.'));
    await o.click('#flowBody .flow-step [data-flow-step="1"]'); await o.waitForTimeout(600);
    // the quest: two lines made a numbered list, then a bulleted one under it
    await o.fill('#wcQuestText', 'Take the ford\nBurn the mill');
    await o.$eval('#wcQuestText', e => e.setSelectionRange(0, e.value.length));
    await o.click('#wcQuestQuestStep [data-quest-fmt="numbered"]');
    check('Numbered list numbers each line', (await o.$eval('#wcQuestText', e => e.value)) === '1. Take the ford\n2. Burn the mill', JSON.stringify(await o.$eval('#wcQuestText', e => e.value)));
    await o.$eval('#wcQuestText', e => { e.focus(); e.setSelectionRange(e.value.length, e.value.length); });
    await o.keyboard.type('\n\nSpare the shrine');
    await o.$eval('#wcQuestText', e => { const at = e.value.indexOf('Spare'); e.setSelectionRange(at, at); });
    await o.click('#wcQuestQuestStep [data-quest-fmt="list"]');
    check('List makes bullets', (await o.$eval('#wcQuestText', e => e.value)).endsWith('\n\n- Spare the shrine'), JSON.stringify(await o.$eval('#wcQuestText', e => e.value)));
    // back to the briefing and on again: both boxes still there, as written
    await o.click('#flowBody .bf-tabs [data-flow-step="0"]'); await o.waitForTimeout(700);
    check('back to Briefing: the box open, as written', await o.$eval('#wcQuestBriefing', e => e.offsetHeight > 100 && e.value.startsWith('## Orders') && !e.closest('[inert]')));
    await o.click('#flowBody .bf-tabs [data-flow-step="1"]'); await o.waitForTimeout(700);
    check('and Quest again', await o.$eval('#wcQuestText', e => e.offsetHeight > 100 && e.value.startsWith('1. Take the ford') && !e.closest('[inert]')));
    check('Submit on the Quest step', (await text(o, '#flowFinishBtn')) === 'Submit');
    // Submit asks first; not yet keeps it open, unsaved
    await o.evaluate(() => { window.__confirm = window.confirm; window.confirm = () => false; });
    await o.click('#flowFinishBtn'); await o.waitForTimeout(600);
    check('not ready: still open, nothing saved', await o.$eval('#flowOverlay', e => !e.classList.contains('hide')) && !(await o.evaluate(() => window.__FAKE_DB.warcastle_quests.length)));
    await o.evaluate(() => { window.confirm = window.__confirm; });
    o.dialogs.length = 0;
    await o.click('#flowFinishBtn'); await o.waitForTimeout(900);
    check('Submit asks if it\'s ready', o.dialogs.join() === 'Is wc-test-03\'s briefing and quest ready to submit?', o.dialogs.join(' | '));
    const row = await o.evaluate(() => window.__FAKE_DB.warcastle_quests.find(q => q.player_id === 'p03'));
    check('saved for that player', row && row.campaign_id === 'c1' && row.briefing === '## Orders\n\nHold the **bridge**.' && row.quest.startsWith('1. Take the ford'), JSON.stringify(row));
    check('the row says what\'s written, and the count', (await text(o, '#wcQuestsList li:has([data-wc-quest-edit="p03"]) .sub')) === 'Briefing and quest' && (await text(o, '#wcQuestsCount')) === '1 of 26 written');
    // editing again: what was saved, and saved over (not a second row)
    await o.click('#wcQuestsList [data-wc-quest-edit="p03"]'); await o.waitForTimeout(700);
    check('Edit again: opens on what was saved', (await o.$eval('#wcQuestBriefing', e => e.value)) === row.briefing);
    await o.click('#flowBody .flow-step [data-flow-step="1"]'); await o.waitForTimeout(400);
    await o.fill('#wcQuestText', '1. Take the ford');
    await o.click('#flowFinishBtn'); await o.waitForTimeout(900);
    check('saved over, one row', (await o.evaluate(() => window.__FAKE_DB.warcastle_quests.filter(q => q.player_id === 'p03').map(q => q.quest))).join() === '1. Take the ford');
    // sending: asks first (25 have none), then sets the switch Start reads
    o.dialogs.length = 0;
    await o.click('#wcQuestsSendBtn'); await o.waitForTimeout(1200);
    check('Send asks about those with no quest', o.dialogs.some(d => d === '25 players have no quest yet. Send anyway?'), o.dialogs.join(' | '));
    check('sent: kept with the event', !!(await o.evaluate(() => window.__FAKE_DB.campaigns[0].settings.warcastle?.quests_sent_at)));
    check('sent: shown, and no Send again', (await text(o, '#wcQuestsCount')).startsWith('1 of 26 written · Sent to players') && await o.$eval('#wcQuestsSendBtn', e => e.classList.contains('hide')));
    check('the event\'s other settings kept', !!(await o.evaluate(() => window.__FAKE_DB.campaigns[0].settings.warcastle?.tables?.[1])));
    await o.click('#adminSubnav [data-section="admin-wcstart"]'); await o.waitForTimeout(1000);
    check('Start: Quests sent out ticks itself', await o.$eval('#wcReadyList [data-wc-quests]', e => e.checked && e.closest('li').classList.contains('done')));
    check('no script errors (quests)', !o.errors.length, o.errors.join(' | '));
    await o.close();
  }

  console.log('A player: Your quest');
  {
    const wy = world({ me: 'p03' });
    Object.assign(wy.db.tournaments[0], { status: 'setup', current_round: 0 }); wy.db.tournament_rounds = []; wy.db.tournament_pairings = [];
    wy.db.campaigns[0].settings.warcastle.quests_sent_at = '2026-10-28T10:00:00Z';
    wy.db.warcastle_quests = [
      { id: 'q1', campaign_id: 'c1', player_id: 'p03', briefing: '## Orders\n\nHold the **bridge**.', quest: '1. Take the ford\n2. Burn the mill\n\n- Spare the shrine' },
      { id: 'q2', campaign_id: 'c1', player_id: 'p04', briefing: 'Someone else\'s orders', quest: 'Someone else\'s quest' },
    ];
    const y = await openApp(b, wy, { phone: true });
    await y.evaluate(() => [...document.querySelectorAll('#playerTabBar .tab-btn')].find(x => x.dataset.tab === 'game')?.click()); await y.waitForTimeout(1500);
    const tiles = await y.$$eval('#tournamentGameCta .t-hold .dash-kpi', es => es.map(e => e.innerText.replace(/\s+/g, ' ').trim()));
    check('before the event: Your quest, ready, and magic items', tiles.join() === 'Ready YOUR QUEST,0 Supply · 0 Warpstone YOUR MAGIC ITEMS', JSON.stringify(tiles));
    await y.click('#tournamentGameCta [data-wc-quest]');
    check('Your quest opens their briefing, then their quest', await until(y, async () => (await text(y, '#wcQuestBody')).startsWith('Briefing Orders Hold the bridge. Quest')), await text(y, '#wcQuestBody'));
    const shown = await y.$eval('#wcQuestBody', e => ({ ol: e.querySelectorAll('ol li').length, ul: e.querySelectorAll('ul li').length, b: e.querySelector('strong')?.textContent, h: e.querySelectorAll('h4').length }));
    check('formatted: heading, bold, numbered and bulleted lists', JSON.stringify(shown) === JSON.stringify({ ol: 2, ul: 1, b: 'bridge', h: 3 }), JSON.stringify(shown));
    check('only their own', !(await text(y, '#wcQuestBody')).includes('Someone else'));
    await y.keyboard.press('Escape'); await y.waitForTimeout(200);
    check('Escape closes it, back on the tile', await y.$eval('#wcQuestOverlay', e => e.classList.contains('hide')) && await y.evaluate(() => document.activeElement?.hasAttribute('data-wc-quest')));
    check('no script errors (Your quest)', !y.errors.length, y.errors.join(' | '));
    await y.close();
    // during a round: on Play, beside Briefing
    const wr = world({ me: 'p03' });
    wr.db.tournament_pairings.forEach(x => { x.warcastle = { attacker: x.player_b_id, came_from: null, ambush: false, rolled: true }; });
    wr.db.campaigns[0].settings.warcastle.quests_sent_at = '2026-10-28T10:00:00Z';
    wr.db.warcastle_quests = wy.db.warcastle_quests;
    const r = await openApp(b, wr, { phone: true });
    await r.click('#playerTabBar [data-tab="game"]'); await r.waitForTimeout(800);
    check('Play: Your quest during the round', !!(await r.$('#tournamentGameCta .wc-play [data-wc-quest]')));
    await r.click('#tournamentGameCta [data-wc-quest]');
    check('and it opens the same', await until(r, async () => (await text(r, '#wcQuestBody')).includes('Take the ford')));
    check('no script errors (Your quest on Play)', !r.errors.length, r.errors.join(' | '));
    await r.close();
    // a player with nothing written yet
    const wn = world({ me: 'p05' });
    Object.assign(wn.db.tournaments[0], { status: 'setup', current_round: 0 }); wn.db.tournament_rounds = []; wn.db.tournament_pairings = [];
    wn.db.campaigns[0].settings.warcastle.quests_sent_at = '2026-10-28T10:00:00Z';
    wn.db.warcastle_quests = wy.db.warcastle_quests;
    const n = await openApp(b, wn, { phone: true });
    await n.evaluate(() => [...document.querySelectorAll('#playerTabBar .tab-btn')].find(x => x.dataset.tab === 'game')?.click()); await n.waitForTimeout(1500);
    await n.click('#tournamentGameCta [data-wc-quest]');
    check('nothing written for them: not ready yet', await until(n, async () => (await text(n, '#wcQuestBody')) === 'Your quest isn’t ready yet.'), await text(n, '#wcQuestBody'));
    await n.close();
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
    await tm.click('[data-t-length="-60"]'); await tm.waitForTimeout(800);
    check('the round length changes for every round: an hour less', (await tm.evaluate(() => window.__FAKE_DB.tournaments[0].round_minutes)) === 120);
    await tm.click('[data-t-length="15"]'); await tm.waitForTimeout(800);
    check('and a quarter hour more', (await tm.evaluate(() => window.__FAKE_DB.tournaments[0].round_minutes)) === 135 && (await tm.$$eval('#tClockActs .t-clock-now', es => es.map(e => e.textContent))).slice(0, 2).join() === '2 h,15 min');
    check('no script errors', !tm.errors.length, tm.errors.join(' | '));
  }

  console.log('The organiser: a timer from none, with the timer\'s (i)');
  {
    const wn = world({ me: 'g', round: 'active' });
    wn.db.tournaments[0].round_minutes = null; wn.db.tournament_rounds[0].activated_at = new Date().toISOString();
    const tn = await openApp(b, wn);
    await tn.evaluate(() => document.getElementById('adminModeToggle').click()); await tn.waitForTimeout(1000);
    await tn.evaluate(() => document.getElementById('runNavBtn').click()); await tn.waitForTimeout(1500);
    await tn.click('#tClockBtn'); await tn.waitForTimeout(500);
    check('no timer: just the round length, nothing to take off', (await tn.$$eval('.t-clock-label', es => es.map(e => e.textContent))).join() === 'Round length' && await tn.$eval('[data-t-length="-60"]', e => e.disabled) && await tn.$eval('[data-t-length="-15"]', e => e.disabled));
    await tn.click('[data-t-length="60"]'); await tn.waitForTimeout(800);
    await tn.click('[data-t-length="60"]'); await tn.waitForTimeout(800);
    await tn.click('[data-t-length="15"]'); await tn.waitForTimeout(800);
    check('+ sets a round length: hours and quarter hours', (await tn.evaluate(() => window.__FAKE_DB.tournaments[0].round_minutes)) === 135);
    check('and the round being played gets its time left and pause', (await tn.$$eval('.t-clock-label', es => es.map(e => e.textContent))).join() === 'Round length,Time left' && !!(await tn.$('[data-t-clock="pause"]')));
    await tn.click('[data-t-clock="300"]'); await tn.waitForTimeout(800);
    check('+ on time left adds 5 minutes', (await tn.evaluate(() => window.__FAKE_DB.tournament_rounds[0].timer_extra_seconds)) === 300);
    await tn.click('[data-t-clock="-300"]'); await tn.waitForTimeout(800);
    check('− on time left takes 5 minutes off', (await tn.evaluate(() => window.__FAKE_DB.tournament_rounds[0].timer_extra_seconds)) === 0);
    check('no script errors', !tn.errors.length, tn.errors.join(' | '));
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

  console.log('The organiser: Channelling for the round');
  {
    // round 1 over, round 2's pairings made, not started
    const cw = world({ me: 'g', round: 'completed', withMoves: true });
    cw.db.tournament_pairings.slice().forEach((p, i) => cw.db.tournament_pairings.push({ ...p, id: 'q' + i, round_id: 'r2', result: null }));
    const c = await openApp(b, cw, { phone: true });
    await c.evaluate(() => document.getElementById('adminModeToggle').click()); await c.waitForTimeout(1000);
    await c.evaluate(() => document.getElementById('runNavBtn').click()); await c.waitForTimeout(1500);
    check('before the round: a Channelling switch, off, beside Start round', await c.evaluate(() => { const t = document.querySelector('#tournamentNext #tRoundChannellingToggle');
      return !!t && !!t.offsetParent && !t.checked && t.closest('.toggle-switch').innerText.trim() === 'Channelling' && !!document.getElementById('tournamentNextBtn')?.textContent.includes('Start round 2'); }));
    await c.click('#tRoundChannelling .toggle-switch'); await c.waitForTimeout(600);
    check('switched on: saved on round 2 only', await c.evaluate(() => window.__FAKE_DB.tournament_rounds.map(r => !!r.channelling).join() === 'false,true,false,false,false,false'));
    await c.click('#wcRunTabs [data-wc-run-tab="battles"]'); await c.waitForTimeout(800);
    check('on every Event tab', await c.$eval('#tRoundChannellingToggle', e => !!e.offsetParent && e.checked));
    c.dialogs.length = 0;
    await c.evaluate(() => document.getElementById('tournamentStartRoundBtn').click()); await c.waitForTimeout(2000);
    check('once the round starts, no switch', await c.$eval('#tRoundChannelling', e => e.classList.contains('hide') && !e.innerHTML));
    check('no script errors', !c.errors.length, c.errors.join(' | '));
    const ac = await openApp(b, world({ me: 'g', round: 'active' }), { phone: true });
    await ac.evaluate(() => document.getElementById('adminModeToggle').click()); await ac.waitForTimeout(1000);
    await ac.evaluate(() => document.getElementById('runNavBtn').click()); await ac.waitForTimeout(1500);
    check('during a round, no switch', !(await ac.$('#tRoundChannellingToggle')));
  }

  console.log('A player: a round with Channelling');
  for (const on of [true, false]) {
    const pw2 = world({ me: 'p03' }); pw2.db.game_invites = [];
    pw2.db.tournament_rounds[0].channelling = on;
    const q = await openApp(b, pw2, { phone: true });
    await q.evaluate(() => document.querySelector('[data-tournament-cta]').click());
    await q.waitForSelector('#gameStageMission:not(.hide)', { state: 'attached' });
    await until(q, () => q.$eval('#gameMissionSelect', e => e.value === 'm2'));
    await q.evaluate(() => document.getElementById('missionContinueBtn').click());
    await until(q, () => q.evaluate(() => window.__FAKE_DB.game_invites.length > 0));
    const magic = await q.evaluate(() => window.__FAKE_DB.game_invites[0]?.battle_setup?.magic ?? null);
    check(on ? 'the request carries Channelling' : 'switched off: the scenario\'s own magic (none)', magic === (on ? 'channelling' : null), String(magic));
    await q.close();
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
  check('no Channelling switch', !(await o.$('#tRoundChannellingToggle')));
  check('no Map step, and Entrants is in Set up', (await text(o, '#tournamentSteps')).replace(/\(done\)/g, '').replace(/\s+/g, ' ') === '1 Rounds 2 Results');
  {
    // before the lock, check-in stays in Entrants (only WarCastle moved it to Start)
    const cw = world({ me: 'g' }); cw.db.campaigns[0].settings = {};
    Object.assign(cw.db.tournaments[0], { status: 'setup', current_round: 0, entrants_locked_at: null });
    cw.db.tournament_rounds = []; cw.db.tournament_pairings = []; cw.db.tournament_entrants = [];
    cw.db.campaign_member_admin = cw.db.campaign_members.filter(m => m.role === 'player').map(m => ({ campaign_id: 'c1', user_id: m.user_id, checked_in_at: null, list_checked_at: null, note: null }));
    const ci = await openApp(b, cw);
    await ci.evaluate(() => document.getElementById('adminModeToggle').click()); await ci.waitForTimeout(1000);
    await ci.evaluate(() => document.getElementById('setupNavBtn').click()); await ci.waitForTimeout(1200);
    await ci.click('#adminSubnav [data-section="admin-entrants"]'); await ci.waitForTimeout(1200);
    check('check-in in Entrants before the lock', await ci.$eval('#adminCheckInSection', e => !e.classList.contains('hide') && !!e.closest('#adminEntrantsPanel')) && (await text(ci, '#adminCheckInCount')).startsWith('0 of 26'), await text(ci, '#adminCheckInCount'));
    check('no Quests outside WarCastle', await ci.$eval('#wcQuestsSection', e => e.classList.contains('hide')));
    await ci.close();
  }

  console.log('An ordinary tournament: Channelling for every battle');
  {
    const ow = world({ me: 'g' }); ow.db.campaigns[0].settings = {};
    const og = await openApp(b, ow);
    await toRunMap(og);
    await og.evaluate(() => document.getElementById('tournamentEditBtn').click()); await og.waitForTimeout(800);
    check('Edit details: a Channelling switch, off', await og.$eval('#tournamentChannellingEdit', e => !e.checked && e.closest('.toggle-switch').innerText.trim() === 'Channelling'));
    await og.evaluate(() => { const t = document.getElementById('tournamentChannellingEdit'); t.checked = true; t.dispatchEvent(new Event('change', { bubbles: true })); });
    await og.evaluate(() => [...document.querySelectorAll('button')].find(x => x.textContent.trim() === 'Save details' && x.offsetParent)?.click()
      || [...document.querySelectorAll('button')].find(x => x.textContent.trim() === 'Next' && x.offsetParent)?.click());
    await og.waitForTimeout(600);
    await og.evaluate(() => [...document.querySelectorAll('button')].find(x => x.textContent.trim() === 'Save details' && x.offsetParent)?.click());
    check('saved on the tournament', await until(og, () => og.evaluate(() => window.__FAKE_DB.tournaments[0].channelling === true)));
    check('no script errors', !og.errors.length, og.errors.join(' | '));
    for (const [label, settings, magic] of [['a player\'s request carries Channelling', {}, 'channelling'], ['WarCastle ignores the tournament\'s setting', null, null]]) {
      const pw3 = world({ me: 'p03' }); pw3.db.game_invites = []; pw3.db.tournaments[0].channelling = true;
      if (settings) pw3.db.campaigns[0].settings = settings;
      const q = await openApp(b, pw3, { phone: true });
      await q.evaluate(() => document.querySelector('[data-tournament-cta]').click());
      await q.waitForSelector('#gameStageMission:not(.hide)', { state: 'attached' });
      await until(q, () => q.$eval('#gameMissionSelect', e => e.value === 'm2'));
      await q.evaluate(() => document.getElementById('missionContinueBtn').click());
      await until(q, () => q.evaluate(() => window.__FAKE_DB.game_invites.length > 0));
      const got = await q.evaluate(() => window.__FAKE_DB.game_invites[0]?.battle_setup?.magic ?? null);
      check(label, got === magic, String(got));
      await q.close();
    }
    const wg = await openApp(b, world({ me: 'g' }));
    await toRunMap(wg);
    await wg.evaluate(() => document.getElementById('tournamentEditBtn').click()); await wg.waitForTimeout(800);
    check('WarCastle: no Channelling in Edit details', !(await wg.$('#tournamentChannellingEdit')));
  }

  console.log('From WarCastle to another tournament');
  {
    const ws = world({ me: 'p03' }); ws.rpcSource = WARCASTLE_RPC;
    ws.db.warcastle_tokens = [{ id: 'a1', campaign_id: 'c1', player_id: 'p03', kind: 'supply', amount: 5, reason: 'award', created_at: new Date().toISOString() }];
    ws.db.warcastle_items = [];
    ws.db.campaigns.push({ id: 'c2', name: 'Test cup', format: 'tournament', status: 'active', join_code: 'T-2', settings: { template: 'tournament' }, created_by: 'g', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: [], player_cap: 16 });
    ws.db.campaign_members.push({ user_id: 'p03', campaign_id: 'c2', role: 'player', faction_id: 'skaven', onboarded: true });
    const sw = await openApp(b, ws, { phone: true });
    const lists = async () => { await sw.evaluate(() => document.querySelector('#playerTabBar .tab-btn[data-tab="muster"]').click()); await sw.waitForTimeout(1800); };
    const shown = () => sw.$eval('#wcItemsRow', e => !e.classList.contains('hide'));
    await lists();
    check('Lists: Supply and Warpstone in WarCastle', await shown());
    await sw.evaluate(() => { const s = document.getElementById('campaignSwitcher'); s.value = 'c2'; s.dispatchEvent(new Event('change')); });
    await sw.waitForTimeout(2000); await lists();
    check('Lists: no Supply and Warpstone once switched to another tournament', !(await shown()));
    check('no script errors', !sw.errors.length, sw.errors.join(' | '));
  }

  await b.close();
  console.log(failures ? `\n${failures} failed` : '\nAll passed');
  process.exit(failures ? 1 : 0);
})();
