// The battlefield builder's rivers and roads: Turn swaps a river between
// top to bottom and side to side, and the way it's turned stays through a
// shuffle, mirrored or not:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/map-lines.cjs
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
const tick = (page, id) => page.evaluate((id) => document.getElementById(id).click(), id).then(() => page.waitForTimeout(300));
// which way the added river runs, from its drawing: 'down' (top to bottom) or 'side'
const riverWay = (page) => page.evaluate(() => {
  const lines = [...document.querySelectorAll('.map-line[data-line]')];
  const river = lines.find(g => /^River\./.test(g.getAttribute('aria-label') || ''));
  if (!river) return null;
  const b = river.getBBox();
  return b.height > b.width ? 'down' : 'side';
});

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await openApp(browser, world());
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  await page.evaluate(() => document.getElementById('missionsAdminTabBtn').click()); await page.waitForTimeout(600);
  await page.evaluate(() => document.getElementById('missionCreateBtn').click()); await page.waitForTimeout(800);
  // (the scenario builder shows the steps as fold-outs, terrain switched on)
  await page.evaluate(() => { document.getElementById('bfTab-terrain')?.click(); const t = document.getElementById('mapTerrainToggle'); if (t && !t.checked) t.click(); });
  await page.waitForTimeout(300);
  await page.evaluate(() => { const d = document.getElementById('mapTerrainBtn').closest('details'); if (d && !d.open) d.querySelector('summary').click(); });
  await page.waitForTimeout(300);
  check(!(await page.$('[data-line-turn]')), 'no Turn without a river or road');
  await tick(page, 'mapRiverToggle');
  check(!!(await page.$('[data-line-turn="River"]')), 'a river has a Turn button');
  check(await page.$eval('[data-line-turn="River"]', b => b.classList.contains('mini-btn') && b.getAttribute('aria-label') === 'Turn the river'), 'Turn is a small button, labelled for the river');

  for (const mirrored of [true, false]) {
    if (!mirrored) {
      await page.evaluate(() => { const b = document.getElementById('bfTerrainOptsBtn'); if (b.getAttribute('aria-expanded') !== 'true') b.click(); });
      await page.waitForTimeout(300);
      await tick(page, 'mapMirrorToggle');
    }
    const label = mirrored ? 'mirrored' : 'asymmetric';
    let way = await riverWay(page);
    check(!!way, `${label}: the river is drawn`);
    for (let i = 0; i < 2; i++) {
      await page.click('[data-line-turn="River"]'); await page.waitForTimeout(300);
      const now = await riverWay(page);
      check(now && now !== way, `${label}: Turn swaps it (${way} to ${now})`);
      way = now;
    }
    let kept = true;
    for (let i = 0; i < 4; i++) { await page.click('#mapTerrainBtn'); await page.waitForTimeout(300); if (await riverWay(page) !== way) kept = false; }
    check(kept, `${label}: it stays turned through a shuffle`);
    await tick(page, 'mapRiverToggle'); await tick(page, 'mapRiverToggle');
    check(await riverWay(page) === way, `${label}: and when taken away and added again`);
  }
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
