// Unit strength as the lists show it: the phone unit cards ("Unit strength N",
// your own list and another player's) and Game view's badge on a computer,
// worked out by troop type, not wounds:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/unit-strength.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

const unit = (id, rosterId, name, size, wargear = {}) => ({ id, roster_id: rosterId, name, category: 'core', size, points: 100, experience: 0, status: null, archived_at: null, wargear, current_wounds: null });
// a few real statlines (W and troop type) from the rules index
const rulesIndex = {
  'empire knights': { url: 'unit/empire-knights', troopType: 'HCa', stats: [{ Name: 'Empire Knight', W: '1' }, { Name: 'Preceptor', W: '1' }, { Name: 'Barded Warhorse', W: '-' }] },
  'general of the empire': { url: 'unit/general-of-the-empire', troopType: 'RI', stats: [{ Name: 'General of the Empire', W: '3' }] },
  'imperial griffon': { url: 'unit/imperial-griffon', troopType: 'Be', stats: [{ Name: 'Imperial Griffon', W: '(+4)' }] },
  'ogre bulls': { url: 'unit/ogre-bulls', troopType: 'MI', stats: [{ Name: 'Ogre', W: '3' }] },
};
function world() {
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    rulesIndex,
    db: {
      players: [{ id: 'a', display_name: 'Alice' }, { id: 'b', display_name: 'Bob' }],
      campaign_members: [
        { user_id: 'a', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true },
        { user_id: 'b', campaign_id: 'c1', role: 'player', faction_id: 'ogre-kingdoms', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }, { id: 'ogre-kingdoms', name: 'Ogre Kingdoms' }],
      rosters: [{ id: 'ra', player_id: 'a', campaign_id: 'c1', faction_id: 'empire-of-man', name: 'Alice list', points_limit: 2000 },
        { id: 'rb', player_id: 'b', campaign_id: 'c1', faction_id: 'ogre-kingdoms', name: 'Bob list', points_limit: 2000 }],
      units: [unit('a1', 'ra', 'Empire Knights', 5),
        unit('a2', 'ra', 'General of the Empire', 1, { mounts: [{ name_en: 'Imperial Griffon', active: true }] }),
        unit('b1', 'rb', 'Ogre Bulls', 3)],
      missions: [], game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };
const cardMeta = (page, id) => page.$eval(`.unit-card[data-unit-id="${id}"] .unit-card-meta`, e => e.textContent).catch(() => '');

(async () => {
  const browser = await chromium.launch();

  console.log('On a phone: your own list');
  let page = await openApp(browser, world(), { phone: true });
  await page.click('#playerTabBar .tab-btn[data-tab="muster"]'); await page.waitForTimeout(800);
  let knights = await cardMeta(page, 'a1'), general = await cardMeta(page, 'a2');
  check(/Unit strength 10\b/.test(knights), `5 Empire Knights: Unit strength 10 (${knights})`);
  check(/Unit strength 7\b/.test(general), `General on an Imperial Griffon: Unit strength 7 (${general})`);
  check(!/(^|[^t] )Strength \d/.test(knights + general), 'no bare "Strength"');
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await page.context().close();

  console.log("Admin › Players › View list: another player's list");
  const wv = world();
  wv.db.campaign_members[0].role = 'organiser';
  page = await openApp(browser, wv, { phone: true });
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  await page.evaluate(() => document.getElementById('playersOpenBtn').click()); await page.waitForTimeout(800);
  await page.evaluate(() => document.querySelector('[data-action="member-view-list"][data-uid="b"]').click()); await page.waitForTimeout(1200);
  const ogres = await cardMeta(page, 'b1');
  check(/Unit strength 9\b/.test(ogres), `3 Ogre Bulls: Unit strength 9 (${ogres})`);
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await page.context().close();

  console.log('On a computer: Game view');
  page = await openApp(browser, world());
  await page.click('.tab-btn[data-tab="game"]'); await page.waitForTimeout(800);
  const rows = await page.$$eval('#rostersGame .unit-row', l => l.map(e => e.querySelector('.unit-name').textContent + ' | ' + e.querySelector('.row-right .pts').textContent));
  const row = name => rows.find(t => t.includes(name)) || '';
  check(/\| Unit strength: 10$/.test(row('Empire Knights')), `5 Empire Knights: Unit strength: 10 (${row('Empire Knights')})`);
  check(/\| Unit strength: 7$/.test(row('General of the Empire')), `General on an Imperial Griffon: Unit strength: 7 (${row('General of the Empire')})`);
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));

  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
