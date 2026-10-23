// Admin › Scenarios: the builder makes scenarios (the old form and the CSV
// import are gone), and custom objectives are made in their own fold-out:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/scenarios-admin.cjs
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

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await openApp(browser, world());
  await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1500);
  await page.evaluate(() => document.getElementById('missionsAdminTabBtn').click()); await page.waitForTimeout(600);
  check(!(await page.$('#missionWizard')) && !(await page.$('#missionCsvFile')), 'the old form and the CSV import are gone');

  // a custom objective, from its fold-out
  await page.evaluate(() => { const d = document.getElementById('customObjectiveNewBtn').closest('details'); d.open = true; });
  check(/No custom objectives yet/.test(await page.textContent('#missionCustomObjectives')), 'none to start with');
  await page.click('#customObjectiveNewBtn'); await page.waitForTimeout(400);
  await page.fill('#customObjectiveName', 'Hold the shrine');
  await page.fill('#customObjectiveDesc', 'Have a unit in the shrine at the end of the battle.');
  await page.click('[data-flow-step="1"]'); await page.waitForTimeout(300);
  await page.fill('#customObjectiveVp', '150');
  await page.click('#flowFinishBtn'); await page.waitForTimeout(600);
  const saved = await page.evaluate(() => window.__FAKE_DB.custom_objectives);
  check(saved.length === 1 && saved[0].name === 'Hold the shrine' && saved[0].reward_vp === 150 && saved[0].campaign_id === 'c1', 'saved to this campaign');
  check(/Hold the shrine/.test(await page.textContent('#missionCustomObjectives')), 'listed in the fold-out');

  // the builder offers it
  await page.evaluate(() => document.getElementById('missionCreateBtn').click()); await page.waitForTimeout(800);
  check(await page.isVisible('#battlefieldOverlay'), 'New scenario opens the builder');
  await page.click('#mapReviewBtn'); await page.waitForTimeout(400);
  await page.click('#mapConfirmBtn'); await page.waitForTimeout(400);
  check(!!(await page.$(`.bf-custom[value="${saved[0].id}"]`)), 'the builder offers the custom objective');
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
