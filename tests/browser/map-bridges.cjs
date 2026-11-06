// A table's own bridges: a river saved with line.bridges draws them where
// set (a share of the way along), a wooden footbridge (foot) or a stone one
// of the width (w) and length (len) set; and hills rectangular unless
// shape 'round'; a table's ground (cobbles, snow) and the altar, wall and
// gatehouse pieces, low walls and hedges, and a special feature that keeps
// its own look (and glows) when the terrain is placed again; on snow, only
// rocks are scattered; wheat fields, a crater, a warpstone shard and an
// eerie glow (unlabelled, in nothing's way), in Set up › Tables:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/map-bridges.cjs
const { chromium } = require('playwright');
const { world } = require('./warcastle-world.cjs');
const { openApp } = require('./app.cjs');

const fails = [];
const check = (ok, what, detail = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}${!ok && detail ? ` -- ${detail}` : ''}`); if (!ok) fails.push(what); };
const river = (bridges, pieces = []) => {
  const pts = []; for (let x = -1; x <= 73; x++) pts.push([x, 24]);
  return { table: '72x48', mode: 'normal', gameSize: '2000-2499', shape: 'none', markers: 0, objectivesOn: false, featureOn: false, featurePos: null,
    placement: 'asymmetric', swap: false, decoration: false, measure: false, showTerrain: true, density: 'normal', river: true, road: false,
    lineWidth: { water: 4 }, terrainRandom: false, objectives: null, rules: { happenings: [], weather: null, custom: [] }, vp: {}, customObjectives: [],
    secretOn: false, magic: { mode: null }, terrain: { generator: '', scattered: false, count: 1, picks: [{ value: 'Hill', rolled: false }] },
    layout: { markers: [], scatter: [], pieces, lines: [{ name: 'River', kind: 'water', h: 4, pts, across: false, seed: 7, ...(bridges ? { bridges } : {}) }] } };
};
// each bridge drawn over the river: where it is, and whether it's a footbridge (timber rails)
const bridges = (page) => page.$$eval('#battlefieldOverlay .battlefield-svg .map-line[data-line] > g[transform^="translate"]', gs => gs.map(g => ({
  x: Number(/translate\(([-\d.]+)/.exec(g.getAttribute('transform'))[1]), foot: !!g.querySelector('line[stroke="#8a6a44"]'),
  deck: ((r) => r && { width: Number(r.getAttribute('width')), height: Number(r.getAttribute('height')) })(g.querySelector('rect[fill="url(#mapPlanks)"]')) })));

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const w = world({ me: 'g', round: 'completed', withMoves: true });
  // an event at 2,500 points: tables drawn for 2,000 open as drawn all the same
  w.db.tournaments.forEach(t => { t.points_limit = 2500; });
  const m = (n) => w.db.missions.find(x => x.id === `m${n}`);
  m(1).terrain = { deployment: null, scattered: false, builder: river([{ at: .5, w: 6, len: 12 }, { at: .86, foot: true }], [
    { x: 10, y: 10, rot: 0, name: 'Hill', kind: 'hill', w: 12, h: 6, id: 0 }, { x: 60, y: 38, rot: 0, name: 'Hill', kind: 'hill', w: 10, h: 6, id: 1, shape: 'round' }]) };
  m(2).terrain = { deployment: null, scattered: false, builder: river(null) };
  m(3).terrain = { deployment: null, scattered: false, builder: { ...river(null, [
    { x: 36, y: 10, rot: 0, name: 'Altar', kind: 'altar', w: 24, h: 10, id: 0 }, { x: 12, y: 40, rot: 0, name: 'Wall', kind: 'wall', w: 16, h: 2.4, id: 1 },
    { x: 60, y: 40, rot: 0, name: 'Gates of Fortenhaf', kind: 'gate', w: 10, h: 6, id: 2 }]), river: false, ground: 'cobbles', layout: { markers: [], scatter: [], lines: [], pieces: [
    { x: 36, y: 10, rot: 0, name: 'Altar', kind: 'altar', w: 24, h: 10, id: 0, fixed: true, special: true }, { x: 12, y: 40, rot: 0, name: 'Wall', kind: 'wall', w: 16, h: 2.4, id: 1 },
    { x: 60, y: 40, rot: 0, name: 'Gates of Fortenhaf', kind: 'gate', w: 10, h: 6, id: 2 },
    { x: 12, y: 26, rot: 30, name: 'Low Wall', kind: 'lowwall', w: 6, h: 1.2, id: 3, bend: .2 }, { x: 60, y: 26, rot: 0, name: 'Hedge', kind: 'hedge', w: 8, h: 1.3, id: 4 }] },
    featureOn: true, featurePos: { x: 36, y: 10 } } };
  m(4).terrain = { deployment: null, scattered: false, builder: { ...river(null), ground: 'snow' } };
  m(5).terrain = { deployment: null, scattered: false, builder: { ...river(null), river: false, featureOn: true, featurePos: { x: 36, y: 24 }, layout: { markers: [], scatter: [], lines: [], pieces: [
    { x: 36, y: 24, rot: 0, name: 'Eerie Glow', kind: 'glow', w: 84, h: 60, id: 0 }, { x: 36, y: 24, rot: 0, name: 'Crater', kind: 'crater', w: 20, h: 16, id: 1 },
    { x: 36, y: 24, rot: 0, name: 'Shard of Morr', kind: 'warpstone', w: 18, h: 6, id: 2, fixed: true, special: true }, { x: 10, y: 8, rot: 0, name: 'Wheat Field', kind: 'wheat', w: 14, h: 9, id: 3 }] } } };
  const page = await openApp(b, w);
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1000);
  await page.evaluate(() => document.getElementById('setupNavBtn').click()); await page.waitForTimeout(1500);

  await page.click('#setupTblScn1'); await page.waitForTimeout(1200);
  let got = await bridges(page);
  check(got.length === 2, 'two bridges, as set', JSON.stringify(got));
  check(got.some(g => !g.foot && Math.abs(g.x - 36) < 1.5), 'a stone bridge in the centre', JSON.stringify(got));
  check(got.some(g => g.foot && Math.abs(g.x - 62.6) < 1.5), 'a wooden footbridge on the right', JSON.stringify(got));
  const stone = got.find(g => !g.foot);
  check(stone && Math.abs(stone.deck.width - 6) < .1 && Math.abs(stone.deck.height - 11.4) < .2, 'the stone one as wide and long as set', JSON.stringify(stone?.deck));
  // how much of its outline's box each hill fills: a rectangular one nearly all, a round one about π/4
  const hills = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => {
    const outer = g.querySelector('path'), b = outer.getBBox(); let n = 0;
    for (let i = 0; i < 40; i++) for (let j = 0; j < 40; j++) if (outer.isPointInFill(new DOMPoint(b.x + (i + .5) * b.width / 40, b.y + (j + .5) * b.height / 40))) n++;
    return n / 1600;
  }));
  check(hills.length === 2 && hills[0] > .86 && hills[1] < .82, 'a hill is rectangular (fills its box), unless set round', JSON.stringify(hills));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1500);
  const saved = await page.evaluate(() => window.__FAKE_DB.missions.find(x => x.id === window.__FAKE_DB.campaigns[0].settings.warcastle.tables[1])?.terrain?.builder?.layout?.lines?.[0]?.bridges);
  check(JSON.stringify(saved) === JSON.stringify([{ at: .5, w: 6, len: 12 }, { at: .86, foot: true }]), 'saving keeps them', JSON.stringify(saved));

  await page.click('#setupTblScn2'); await page.waitForTimeout(1200);
  got = await bridges(page);
  check(got.length === 1 && !got[0].foot, 'a river without its own still has one stone bridge', JSON.stringify(got));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1200);

  // the ground: the table's own, and plain parchment again on one without
  const ground = () => page.$eval('#battlefieldOverlay .battlefield-svg', svg => [...svg.querySelectorAll(':scope > rect')].map(r => r.getAttribute('fill')).find(f => /mapCobbles|mapSnow|#efe6cf/.test(f || '')));
  await page.click('#setupTblScn3'); await page.waitForTimeout(1200);
  const placed = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => g.getAttribute('transform').match(/translate\(([-\d.]+),([-\d.]+)\)/).slice(1).map(Number).join(',')));
  const drawnAt = w.db.missions.find(x => x.id === 'm3').terrain.builder.layout.pieces.map(p => `${p.x},${p.y}`);
  check(JSON.stringify(placed) === JSON.stringify(drawnAt), 'at another points limit (2,500), a drawn table opens with every piece where it was drawn', JSON.stringify(placed));
  check(await ground() === 'url(#mapCobbles)', 'a cobbled table is drawn on cobbles', await ground());
  const drawn = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => g.getAttribute('aria-label').split('.')[0] + ':' + g.querySelectorAll('path, rect, line').length));
  check(drawn.length === 5 && drawn.every(d => Number(d.split(':')[1]) >= 3), 'the altar, wall, gatehouse, low wall and hedge are each drawn', JSON.stringify(drawn));
  await page.evaluate(() => document.getElementById('mapTerrainBtn').click()); await page.waitForTimeout(500);
  const feature = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => g.getAttribute('aria-label').split('.')[0]));
  check(feature.includes('Altar') && !feature.some(n => /special feature/i.test(n)), 'the altar, the special feature, stays an altar when the terrain is placed again', JSON.stringify(feature));
  const glows = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.filter(g => g.querySelector('[filter="url(#mapGlow)"]')).map(g => g.getAttribute('aria-label').split('.')[0]));
  check(JSON.stringify(glows) === '["Altar"]', 'only the special feature glows', JSON.stringify(glows));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1500);
  const kept = await page.evaluate(() => window.__FAKE_DB.missions.find(x => x.id === window.__FAKE_DB.campaigns[0].settings.warcastle.tables[3])?.terrain?.builder?.ground);
  check(kept === 'cobbles', 'saving keeps the ground', kept);
  await page.click('#setupTblScn4'); await page.waitForTimeout(1200);
  check(await ground() === 'url(#mapSnow)', 'a snowy table is drawn on snow', await ground());
  await page.evaluate(() => document.getElementById('mapTerrainBtn').click()); await page.waitForTimeout(500);
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1500);
  const snowBits = await page.evaluate(() => [...new Set((window.__FAKE_DB.missions.find(x => x.id === window.__FAKE_DB.campaigns[0].settings.warcastle.tables[4])?.terrain?.builder?.layout?.scatter || []).map(d => d.kind))].sort());
  check(snowBits.length && snowBits.every(k => k === 'rock' || k === 'rocks'), 'on snow, only rocks are scattered', JSON.stringify(snowBits));
  await page.click('#setupTblScn4'); await page.waitForTimeout(1200);
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1200);
  await page.click('#setupTblScn2'); await page.waitForTimeout(1200);
  check(await ground() === '#efe6cf', 'and a table without one on plain parchment again', await ground());
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1200);

  await page.click('#setupTblScn5'); await page.waitForTimeout(1200);
  const moller = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => ({ name: g.getAttribute('aria-label').split('.')[0], parts: g.querySelectorAll('path, rect, line, ellipse, polygon').length, gold: !!g.querySelector('[filter="url(#mapGlow)"][fill="#f2c94c"]') })));
  check(moller.length === 4 && moller.every(p => p.parts >= 1), 'the glow, crater, shard and wheat field are each drawn', JSON.stringify(moller));
  check(!moller.some(p => p.gold), 'the warpstone glows green, not gold', JSON.stringify(moller));
  const labels = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece-label', gs => gs.map(g => g.textContent.trim()));
  check(!labels.some(l => /Eerie/.test(l)) && labels.some(l => /Wheat/.test(l)), 'the eerie glow has no label', JSON.stringify(labels));
  await page.focus('#battlefieldOverlay .map-piece[data-piece="3"]'); await page.keyboard.press('ArrowRight'); await page.waitForTimeout(400);
  const after = await page.$$eval('#battlefieldOverlay .battlefield-svg .map-piece', gs => gs.map(g => g.getAttribute('transform')));
  check(after[1] === 'translate(36,24) rotate(0)', 'moving a piece in the glow leaves the crater where it was', JSON.stringify(after));
  await page.click('#battlefieldOverlayDone'); await page.waitForTimeout(1200);

  check(!page.errors.length, 'no page errors', page.errors.join('; '));
  await b.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
