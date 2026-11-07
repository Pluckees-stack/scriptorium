// Change players: in a round under way, the organiser opens a battle not
// yet played and changes who plays it; someone taken from another battle
// swaps places with the player they replace (and attacks or defends as
// they did), a battle with a result can't be changed, and a battle with a
// result has no Change players. A bye can be opened too: picking another
// bye's player puts the two together (the empty row goes), and picking
// someone from a battle leaves their opponent the bye:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/pairing-edit.cjs
const { chromium } = require('playwright');
const { world } = require('./warcastle-world.cjs');
const { openApp } = require('./app.cjs');

const fails = [];
const check = (what, ok, detail = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}${!ok && detail ? ` -- ${detail}` : ''}`); if (!ok) fails.push(what); };
const pair = (page, id) => page.evaluate((id) => { const p = window.__FAKE_DB.tournament_pairings.find(x => x.id === id); return { a: p.player_a_id, b: p.player_b_id, att: p.warcastle?.attacker || null }; }, id);

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const w = world({ me: 'g', round: 'active' }), pr = w.db.tournament_pairings.filter(p => p.round_id === w.db.tournament_rounds.find(r => r.status === 'active').id);
  const [p1, p2, p3, p4, p5, p6] = pr;
  // three byes (each army alone in its area)
  [p4, p5, p6].forEach(p => { p.player_b_id = null; p.warcastle = null; });
  p1.warcastle = { ...(p1.warcastle || {}), attacker: p1.player_a_id };
  p2.warcastle = { ...(p2.warcastle || {}), attacker: p2.player_b_id };
  Object.assign(p3, { result: 'a_win', vp_a: 900, vp_b: 400 });
  const was = { p1: { a: p1.player_a_id, b: p1.player_b_id }, p2: { a: p2.player_a_id, b: p2.player_b_id }, p3: { a: p3.player_a_id, b: p3.player_b_id } };
  const page = await openApp(b, w);
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1000);
  await page.evaluate(() => document.getElementById('runNavBtn').click()); await page.waitForTimeout(1500);

  // a battle with a result: no Change players
  await page.click(`#tournamentPairings [data-amend-pairing="${p3.id}"]`); await page.waitForTimeout(800);
  check('a battle with a result has no Change players', await page.evaluate(() => document.getElementById('tAmendPlayers').classList.contains('hide')));
  await page.evaluate(() => document.querySelector('#flowOverlay [data-close-sheet], #flowCloseBtn, #flowOverlay .rules-dialog__close')?.click()); await page.waitForTimeout(500);

  // swap p1's attacker (its player A) for p2's player B, who defends... attacks there
  await page.click(`#tournamentPairings [data-amend-pairing="${p1.id}"]`); await page.waitForTimeout(800);
  check('a battle not yet played has Change players', await page.evaluate(() => !document.getElementById('tAmendPlayers').classList.contains('hide') && !!document.getElementById('tAmendPlayerA')));
  await page.selectOption('#tAmendPlayerA', was.p2.b); await page.click('#tAmendPlayersBtn'); await page.waitForTimeout(1500);
  const n1 = await pair(page, p1.id), n2 = await pair(page, p2.id);
  check('the picked player takes the place', n1.a === was.p2.b && n1.b === was.p1.b, JSON.stringify(n1));
  check('and the player replaced takes theirs in the other battle', n2.a === was.p2.a && n2.b === was.p1.a, JSON.stringify(n2));
  check('each attacks or defends as the player they replaced did', n1.att === was.p2.b && n2.att === was.p1.a, JSON.stringify({ n1, n2 }));
  check('the sheet closes', await page.evaluate(() => document.getElementById('flowOverlay').classList.contains('hide')));

  // the same player twice: an error, nothing saved
  await page.click(`#tournamentPairings [data-amend-pairing="${p1.id}"]`); await page.waitForTimeout(800);
  await page.selectOption('#tAmendPlayerB', n1.a); await page.click('#tAmendPlayersBtn'); await page.waitForTimeout(600);
  check('the same player twice: an error', /two different players/.test(await page.$eval('#tAmendErr', e => e.textContent)) && JSON.stringify(await pair(page, p1.id)) === JSON.stringify(n1));

  // taking a player from a battle with a result: an error, nothing saved
  await page.selectOption('#tAmendPlayerB', was.p3.a); await page.click('#tAmendPlayersBtn'); await page.waitForTimeout(600);
  check('a player from a battle with a result: an error, nothing saved', /already has a result/.test(await page.$eval('#tAmendErr', e => e.textContent))
    && JSON.stringify(await pair(page, p3.id)) === JSON.stringify({ a: was.p3.a, b: was.p3.b, att: null }));

  await page.evaluate(() => document.querySelector('#flowOverlay [data-close-sheet], #flowCloseBtn, #flowOverlay .rules-dialog__close')?.click()); await page.waitForTimeout(500);
  // two byes paired: p4's player against p5's, p5's row gone, a roll-off for who attacks
  await page.click(`#tournamentPairings [data-amend-pairing="${p4.id}"]`); await page.waitForTimeout(800);
  check('a bye opens with its players, no result', await page.evaluate(() => !!document.getElementById('tAmendPlayerB') && document.getElementById('tAmendPlayerB').value === ''
    && document.getElementById('tAmendResult').classList.contains('hide') && !document.getElementById('tAmendPlayersBtn')));
  await page.selectOption('#tAmendPlayerB', p5.player_a_id); await page.click('#flowFinishBtn'); await page.waitForTimeout(1500);
  const m4 = await page.evaluate((id) => window.__FAKE_DB.tournament_pairings.find(x => x.id === id), p4.id);
  check('two byes paired', m4.player_a_id === p4.player_a_id && m4.player_b_id === p5.player_a_id, JSON.stringify(m4));
  check('the other bye gone', await page.evaluate((id) => !window.__FAKE_DB.tournament_pairings.some(x => x.id === id), p5.id));
  check('WarCastle: they roll off for who attacks', m4.warcastle?.rolled === true && m4.warcastle.attacker === p5.player_a_id, JSON.stringify(m4.warcastle));
  check('the sheet closes after the bye', await page.evaluate(() => document.getElementById('flowOverlay').classList.contains('hide')));
  // a bye's player against someone from a battle: their opponent has the bye
  const in2 = await pair(page, p2.id);
  await page.click(`#tournamentPairings [data-amend-pairing="${p6.id}"]`); await page.waitForTimeout(800);
  await page.selectOption('#tAmendPlayerB', in2.a); await page.click('#flowFinishBtn'); await page.waitForTimeout(1500);
  const m6 = await pair(page, p6.id), m2 = await page.evaluate((id) => window.__FAKE_DB.tournament_pairings.find(x => x.id === id), p2.id);
  check('a bye\'s player against someone from a battle', m6.a === p6.player_a_id && m6.b === in2.a, JSON.stringify(m6));
  check('and their opponent has the bye', m2.player_a_id === in2.b && m2.player_b_id === null && !m2.warcastle, JSON.stringify(m2));
  // a battle's result fields come back after a bye
  await page.click(`#tournamentPairings [data-amend-pairing="${p1.id}"]`); await page.waitForTimeout(800);
  check('a battle after a bye: its result again', await page.evaluate(() => !document.getElementById('tAmendResult').classList.contains('hide') && !!document.getElementById('tAmendPlayersBtn')));
  await page.evaluate(() => document.querySelector('#flowOverlay [data-close-sheet], #flowCloseBtn, #flowOverlay .rules-dialog__close')?.click()); await page.waitForTimeout(500);

  check('no page errors', !page.errors.length, page.errors.join('; '));
  await b.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
