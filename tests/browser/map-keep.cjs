// The battlefield builder keeps its terrain where it is when a setting
// changes: table and game size scale the pieces' places to the new table,
// a new deployment map moves only pieces that clash with it, and more or
// fewer features add or take away pieces (twin pairs when mirrored) without
// moving the rest. Shuffle positions still places everything afresh:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/map-keep.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

function world() {
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }],
      campaign_members: [{ user_id: 'a', campaign_id: 'c1', role: 'organiser', faction_id: 'empire-of-man', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }],
      rosters: [], units: [], missions: [], custom_objectives: [],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };
const press = (page, sel) => page.evaluate((sel) => document.querySelector(sel).click(), sel).then(() => page.waitForTimeout(300));
const tick = (page, id) => press(page, '#' + id);
const pick = (page, id, value) => page.evaluate(([id, value]) => {
  const s = document.getElementById(id); s.value = value; s.dispatchEvent(new Event('change', { bubbles: true }));
}, [id, value]).then(() => page.waitForTimeout(300));
// the table's size and the terrain pieces drawn on it (name and centre)
const layout = (page) => page.evaluate(() => {
  const vb = document.querySelector('#gameMap .battlefield-svg').getAttribute('viewBox').split(' ').map(Number);
  const pieces = [...document.querySelectorAll('#gameMap .map-piece')].map(g => {
    const [, x, y] = g.getAttribute('transform').match(/translate\(([-\d.]+),([-\d.]+)\)/);
    return { name: g.getAttribute('aria-label').split('.')[0], x: +x, y: +y };
  }).filter(p => !/special feature|landmark/i.test(p.name));
  return { W: vb[2] - 3.2, D: vb[3] - 3.2, pieces };
});
// how many of the old pieces are still where they were (scaled to the new table)
const stayed = (before, after) => {
  const sx = after.W / before.W, sy = after.D / before.D, left = after.pieces.slice();
  let n = 0;
  before.pieces.forEach(p => {
    const i = left.findIndex(q => q.name === p.name && Math.hypot(q.x - p.x * sx, q.y - p.y * sy) < .15);
    if (i >= 0) { left.splice(i, 1); n++; }
  });
  return n;
};
// every piece has a twin of the same name turned about the centre
const paired = ({ W, D, pieces }) => pieces.every(p => pieces.some(q => q !== p && q.name === p.name && Math.hypot(q.x - (W - p.x), q.y - (D - p.y)) < .15));
const riverWay = (page) => page.evaluate(() => {
  const river = [...document.querySelectorAll('.map-line[data-line]')].find(g => /^River\./.test(g.getAttribute('aria-label') || ''));
  if (!river) return null;
  const b = river.getBBox();
  return b.height > b.width ? 'down' : 'side';
});
const shapes = (page) => page.evaluate(() => [...document.querySelectorAll('#mapShapeSelect option')].map(o => o.value));

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await openApp(browser, world());
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  await page.evaluate(() => document.getElementById('missionsAdminTabBtn').click()); await page.waitForTimeout(600);
  await page.evaluate(() => document.getElementById('missionCreateBtn').click()); await page.waitForTimeout(800);
  await page.evaluate(() => { document.getElementById('bfTab-terrain')?.click(); const t = document.getElementById('mapTerrainToggle'); if (t && !t.checked) t.click(); });
  await page.waitForTimeout(300);
  await page.evaluate(() => { const b = document.getElementById('bfTerrainOptsBtn'); if (b.getAttribute('aria-expanded') !== 'true') b.click(); });
  await page.waitForTimeout(300);
  await tick(page, 'mapRiverToggle');
  await press(page, '[data-line-turn="River"]');
  const way = await riverWay(page);

  for (const mirrored of [true, false]) {
    if (!mirrored) await tick(page, 'mapMirrorToggle');
    const label = mirrored ? 'mirrored' : 'asymmetric', step = mirrored ? 2 : 1;
    let a = await layout(page);
    check(a.pieces.length > 2, `${label}: terrain is drawn (${a.pieces.length} pieces)`);

    // more and fewer features
    await press(page, `[data-map-terrain="${step}"]`);
    let b = await layout(page);
    check(b.pieces.length === a.pieces.length + step && stayed(a, b) === a.pieces.length, `${label}: + adds ${step} and keeps all ${a.pieces.length} where they were (${stayed(a, b)} kept, ${b.pieces.length} now)`);
    a = b;
    await press(page, `[data-map-terrain="-${step}"]`);
    b = await layout(page);
    check(b.pieces.length === a.pieces.length - step && stayed(a, b) === b.pieces.length, `${label}: − takes away ${step} and the rest stay put`);
    a = b;
    await pick(page, 'mapDensitySelect', 'dense');
    b = await layout(page);
    check(b.pieces.length > a.pieces.length && stayed(a, b) === a.pieces.length, `${label}: dense adds pieces and keeps the others (${a.pieces.length} to ${b.pieces.length})`);
    if (mirrored) check(paired(b), 'mirrored: the added pieces come in twin pairs');
    a = b;
    await pick(page, 'mapDensitySelect', 'light');
    b = await layout(page);
    check(b.pieces.length < a.pieces.length && stayed(a, b) === b.pieces.length, `${label}: light takes pieces away and keeps the rest (${a.pieces.length} to ${b.pieces.length})`);
    if (mirrored) check(paired(b), 'mirrored: and takes them away in twin pairs');
    await pick(page, 'mapDensitySelect', 'normal');

    // a bigger table: every piece keeps its place in proportion
    a = await layout(page);
    await pick(page, 'mapTableSelect', '72x48');
    a = await layout(page);
    await pick(page, 'mapTableSelect', '90x44');
    b = await layout(page);
    check(b.W === 90 && stayed(a, b) === Math.min(a.pieces.length, b.pieces.length), `${label}: 72" × 48" to 90" × 44" scales the pieces (${stayed(a, b)} of ${a.pieces.length} kept, ${b.pieces.length} now)`);
    // a smaller one: most stay, scaled; any that no longer fit are moved
    a = b;
    await pick(page, 'mapTableSelect', '60x44');
    b = await layout(page);
    check(stayed(a, b) >= Math.min(a.pieces.length, b.pieces.length) / 2, `${label}: 90" × 44" to 60" × 44" keeps most pieces in proportion (${stayed(a, b)} of ${Math.min(a.pieces.length, b.pieces.length)})`);
    if (mirrored) check(paired(b), 'mirrored: still in twin pairs on the new table');
    await pick(page, 'mapTableSelect', '72x48');

    // game size (sets the table)
    a = await layout(page);
    const sizes = await page.evaluate(() => [...document.querySelectorAll('#mapGameSize option')].map(o => o.value));
    const big = sizes.find(v => /^normal:3000/.test(v)) || sizes.find(v => v.startsWith('normal:') && !v.includes('2000'));
    await pick(page, 'mapGameSize', big);
    b = await layout(page);
    check(stayed(a, b) >= Math.min(a.pieces.length, b.pieces.length) / 2, `${label}: game size ${big} keeps the pieces in proportion (${stayed(a, b)} of ${Math.min(a.pieces.length, b.pieces.length)})`);
    await pick(page, 'mapGameSize', 'normal:2000-2499');
    await pick(page, 'mapTableSelect', '72x48');

    // deployment maps: only pieces that clash with the new one move
    let total = 0, kept = 0;
    for (const key of (await shapes(page)).slice(0, 8)) {
      a = await layout(page);
      await pick(page, 'mapShapeSelect', key);
      b = await layout(page);
      total += a.pieces.length; kept += stayed(a, b);
    }
    check(kept >= total * .7, `${label}: changing the deployment map keeps most pieces where they were (${kept} of ${total})`);
    check(await riverWay(page) === way, `${label}: the river keeps its direction through all that`);

    // Shuffle positions still places them afresh
    a = await layout(page);
    await tick(page, 'mapTerrainBtn');
    b = await layout(page);
    check(stayed(a, b) < a.pieces.length / 2, `${label}: Shuffle positions places the terrain afresh`);
  }
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
