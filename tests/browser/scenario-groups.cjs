// Scenario pickers group the rules' scenarios by book:
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/scenario-groups.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

const rules = (id, name, path, book) => ({ id, campaign_id: null, name, mode: path === 'battle-march' ? 'battle-march' : 'normal',
  rules_url: `https://tow.whfb.app/${path}/${id}`, description: `${book} - ${name}`, common_objectives: [], secondary_objectives: [], objective_vp: {}, custom_objective_ids: [] });
function world() {
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }, { id: 'b', display_name: 'Bob' }],
      campaign_members: [
        { user_id: 'a', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true },
        { user_id: 'b', campaign_id: 'c1', role: 'player', faction_id: 'skaven', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }, { id: 'skaven', name: 'Skaven' }],
      rosters: [{ id: 'ra', player_id: 'a', campaign_id: 'c1', faction_id: 'empire-of-man', name: 'Alice list', points_limit: 2000 },
        { id: 'rb', player_id: 'b', campaign_id: 'c1', faction_id: 'skaven', name: 'Bob list', points_limit: 2000 }],
      units: [{ id: 'a1', roster_id: 'ra', name: 'Captain', category: 'core', size: 1, points: 100, experience: 0, status: null, archived_at: null, wargear: { command: [{ active: true, name_en: 'General' }] }, current_wounds: null },
        { id: 'b1', roster_id: 'rb', name: 'Warlord', category: 'core', size: 1, points: 100, experience: 0, status: null, archived_at: null, wargear: { command: [{ active: true, name_en: 'General' }] }, current_wounds: null }],
      missions: [
        { id: 'm1', campaign_id: 'c1', name: 'Open field', mode: 'normal', common_objectives: [], secondary_objectives: [], objective_vp: {}, custom_objective_ids: [] },
        rules('open-battle', 'Open Battle', 'warhammer-battles', 'Warhammer: the Old World rulebook'),
        rules('first-linked', 'First Linked Battle', 'narrative-battles', 'Warhammer: the Old World rulebook'),
        rules('scenario-1', 'Scenario 1: Upon the Field of Glory', 'matched-play', 'Matched Play Guide'),
        rules('timely', 'A Timely Arrival', 'narrative-battles', 'Arcane Journal: Dawn of the Storm Dragon'),
        rules('weisnicht', 'The Weisnicht Bridge', 'battle-march', "Battle March: General's Companion")],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await openApp(browser, world());
  await page.click('.tab-btn[data-tab="game"]');
  await page.click('#startGameBtn');
  await page.waitForFunction(() => document.querySelectorAll('#gameOpponentSelect option').length > 1);
  await page.selectOption('#gameOpponentSelect', 'b');
  await page.click('#opponentContinueBtn');
  await page.waitForFunction(() => document.querySelector('#gameMissionSelect option[value="m1"]'));
  const groups = await page.$$eval('#gameMissionSelect optgroup', gs => gs.map(g => [g.label, [...g.querySelectorAll('option')].map(o => o.textContent)]));
  check(JSON.stringify(groups.map(g => g[0])) === JSON.stringify(['Test campaign', 'Rulebook', 'Matched Play Guide', 'Arcane Journals', 'Battle March']), 'Play: campaign first, then the rules by book');
  check(groups[1][1].includes('First Linked Battle'), 'Play: the rulebook’s narrative battles sit with the rulebook');
  check(groups[3][1].join() === 'A Timely Arrival', 'Play: a journal’s scenario under Arcane Journals');
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await page.close();

  // the organiser: Add a battle's picker, and the Scenarios library's headings
  const wo = world();
  wo.db.campaign_members[0].role = 'organiser';
  const org = await openApp(browser, wo);
  await org.evaluate(() => document.getElementById('adminModeToggle').click()); await org.waitForTimeout(1500);
  const manual = await org.$$eval('#manualGameMission optgroup', gs => gs.map(g => g.label));
  check(JSON.stringify(manual) === JSON.stringify(['Test campaign', 'Rulebook', 'Matched Play Guide', 'Arcane Journals', 'Battle March']), 'Add a battle: grouped the same way');
  const heads = await org.$$eval('#adminMissionsOfficial .scn-lib-group', hs => hs.map(h => h.textContent));
  check(JSON.stringify(heads) === JSON.stringify(['Rulebook', 'Matched Play Guide', 'Arcane Journals']), 'Scenarios library: the rules’ normal battles headed by book');
  check(await org.$$eval('#adminMissionsOfficial .scn-tag', ts => ts.some(t => t.textContent === 'Arcane Journal: Dawn of the Storm Dragon')), 'Scenarios library: a journal’s tile names its journal');
  check(!org.errors.length, 'no page errors (organiser)' + (org.errors.length ? ': ' + org.errors.join('; ') : ''));
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
