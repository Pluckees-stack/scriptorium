// A table's own bridges: a river saved with line.bridges draws them where
// set (a share of the way along), a wooden footbridge (foot) or the usual
// stone one, in Set up › Tables:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/map-bridges.cjs
const { chromium } = require('playwright');
const { world } = require('./warcastle-world.cjs');
const { openApp } = require('./app.cjs');

const fails = [];
const check = (ok, what, detail = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}${!ok && detail ? ` -- ${detail}` : ''}`); if (!ok) fails.push(what); };
const river = (bridges) => {
  const pts = []; for (let x = -1; x <= 73; x++) pts.push([x, 24]);
  return { table: '72x48', mode: 'normal', gameSize: '2000-2499', shape: 'none', markers: 0, objectivesOn: false, featureOn: false, featurePos: null,
    placement: 'asymmetric', swap: false, decoration: false, measure: false, showTerrain: true, density: 'normal', river: true, road: false,
    lineWidth: { water: 4 }, terrainRandom: false, objectives: null, rules: { happenings: [], weather: null, custom: [] }, vp: {}, customObjectives: [],
    secretOn: false, magic: { mode: null }, terrain: { generator: '', scattered: false, count: 1, picks: [{ value: 'Hill', rolled: false }] },
    layout: { markers: [], scatter: [], pieces: [], lines: [{ name: 'River', kind: 'water', h: 4, pts, across: false, seed: 7, ...(bridges ? { bridges } : {}) }] } };
};
// each bridge drawn over the river: where it is, and whether it's a footbridge (timber rails)
const bridges = (page) => page.$$eval('#battlefieldOverlay .battlefield-svg .map-line[data-line] > g[transform^="translate"]', gs => gs.map(g => ({
  x: Number(/translate\(([-\d.]+)/.exec(g.getAttribute('transform'))[1]), foot: !!g.querySelector('line[stroke="#8a6a44"]') })));

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const w = world({ me: 'g', round: 'completed', withMoves: true });
  const m = (n) => w.db.missions.find(x => x.id === `m${n}`);
  m(1).terrain = { deployment: null, scattered: false, builder: river([{ at: .5 }, { at: .86, foot: true }]) };
  m(2).terrain = { deployment: null, scattered: false, builder: river(null) };
  const page = await openApp(b, w);
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1000);
  await page.evaluate(() => document.getElementById('setupNavBtn').click()); await page.waitForTimeout(1500);

  await page.click('#setupTblScn1'); await page.waitForTimeout(1200);
  let got = await bridges(page);
  check(got.length === 2, 'two bridges, as set', JSON.stringify(got));
  check(got.some(g => !g.foot && Math.abs(g.x - 36) < 1.5), 'a stone bridge in the centre', JSON.stringify(got));
  check(got.some(g => g.foot && Math.abs(g.x - 62.6) < 1.5), 'a wooden footbridge on the right', JSON.stringify(got));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1500);
  const saved = await page.evaluate(() => window.__FAKE_DB.missions.find(x => x.id === window.__FAKE_DB.campaigns[0].settings.warcastle.tables[1])?.terrain?.builder?.layout?.lines?.[0]?.bridges);
  check(JSON.stringify(saved) === JSON.stringify([{ at: .5 }, { at: .86, foot: true }]), 'saving keeps them', JSON.stringify(saved));

  await page.click('#setupTblScn2'); await page.waitForTimeout(1200);
  got = await bridges(page);
  check(got.length === 1 && !got[0].foot, 'a river without its own still has one stone bridge', JSON.stringify(got));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1200);

  check(!page.errors.length, 'no page errors', page.errors.join('; '));
  await b.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
