// Static tables: each table keeps its terrain all event, and each round's
// scenario brings the deployment and objectives, the same on every table.
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/static-tables.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');
const { world: wcWorld } = require('./warcastle-world.cjs');

// the WarCastle world as an ordinary Swiss tournament: one scenario a round
function world(me = 'g', extra = {}) {
  const w = wcWorld({ me, round: 'active' });
  const c = w.db.campaigns[0];
  c.name = 'Static cup';
  c.settings = { ...(extra.settings || {}) };
  w.db.tournaments[0].name = 'Static cup';
  w.db.missions = [{ id: 'mR', campaign_id: 'c1', name: 'Round scenario', mode: 'normal', common_objectives: [], secondary_objectives: [], game_sizes: ['2000-2499'] }, ...(extra.missions || [])];
  w.db.tournament_rounds.forEach(r => { r.per_table_scenarios = false; r.mission_id = r.round_number === 1 ? (extra.round1 || 'mR') : null; });
  w.db.tournament_pairings.forEach(p => { p.mission_id = null; });
  return w;
}
const fails = [];
const check = (what, ok, info = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}${ok || !info ? '' : `  (${info})`}`); if (!ok) fails.push(what); };
const stepKeys = (pg) => pg.$$eval('#gameMap [data-step], #gameMap .bf-tabs [id^="bfTab-"]', es => [...new Set(es.map(e => e.dataset.step || e.id.replace('bfTab-', '')))]);

(async () => {
  const b = await chromium.launch();
  let tableMission, roundMission;

  console.log('The organiser, Set up');
  {
    const pg = await openApp(b, world());
    await pg.evaluate(() => document.getElementById('adminModeToggle').click()); await pg.waitForTimeout(1000);
    await pg.evaluate(() => document.getElementById('setupNavBtn').click()); await pg.waitForTimeout(1500);
    check('a Static tables switch, off, and no tables', await pg.isVisible('#setupStaticRow') && !(await pg.isChecked('#setupStaticToggle')) && !(await pg.isVisible('#setupStaticTables')));
    await pg.click('#setupStaticRow .toggle-switch'); await pg.waitForTimeout(800);
    const s = await pg.evaluate(() => window.__FAKE_DB.campaigns[0].settings.static_tables);
    check('switched on: saved, a table for every two players', s?.on === true && s.count === 13, JSON.stringify(s));
    check('a card for each table', (await pg.$$eval('#setupTables [data-static-pick]', es => es.length)) === 13);

    // a table: terrain alone
    await pg.click('#setupStaticScn1'); await pg.waitForTimeout(1200);
    const tSteps = await stepKeys(pg);
    check('a table has no deployment, objectives or special feature', tSteps.includes('terrain') && !tSteps.some(k => ['deployment', 'objectives', 'feature'].includes(k)), tSteps.join());
    await pg.evaluate(() => { const t = document.getElementById('mapTerrainToggle'); if (!t.checked) t.click(); }); await pg.waitForTimeout(400);
    await pg.evaluate(() => document.getElementById('mapTerrainRandomBtn').click()); await pg.waitForTimeout(400);
    await pg.fill('#bfEventName', 'Hill table');
    await pg.click('#battlefieldOverlayDone'); await pg.waitForTimeout(1200);
    const after = await pg.evaluate(() => ({ set: window.__FAKE_DB.campaigns[0].settings.static_tables, m: window.__FAKE_DB.missions.find(x => x.name === 'Hill table') }));
    tableMission = after.m;
    check('saved as table 1, with its terrain', after.m && after.set.tables[1] === after.m.id && after.m.terrain.builder.layout.pieces.length > 0 && after.m.terrain.deployment === null, JSON.stringify(after.set));
    check('table 1 shows its name', /Hill table/.test(await pg.textContent('#setupTables')));

    // a round's scenario: deployment and objectives, no terrain
    await pg.click('#setupScn1'); await pg.waitForTimeout(1200);
    const rSteps = await stepKeys(pg);
    check('a round\'s scenario has deployment and objectives, no terrain', rSteps.includes('deployment') && rSteps.includes('objectives') && !rSteps.includes('terrain'), rSteps.join());
    await pg.evaluate(() => { const t = document.getElementById('mapObjectivesToggle'); if (!t.checked) t.click(); }); await pg.waitForTimeout(400);
    await pg.fill('#bfEventName', 'Round 2 scenario');
    await pg.click('#battlefieldOverlayDone'); await pg.waitForTimeout(1200);
    roundMission = await pg.evaluate(() => window.__FAKE_DB.missions.find(x => x.name === 'Round 2 scenario'));
    check('saved as round 2\'s scenario, with no terrain', roundMission && (await pg.evaluate(id => window.__FAKE_DB.tournament_rounds.find(r => r.round_number === 2).mission_id === id, roundMission.id))
      && roundMission.terrain.builder.layout.pieces.every(p => p.featured || p.special) && roundMission.terrain.builder.layout.markers.length > 0);

    // a table removed: the ones after it move up
    await pg.click('#setupTables [data-static-remove="1"]'); await pg.waitForTimeout(800);
    const s2 = await pg.evaluate(() => window.__FAKE_DB.campaigns[0].settings.static_tables);
    check('a table removed', s2.count === 12 && !s2.tables[1], JSON.stringify(s2));
    await pg.click('#setupStaticRow .toggle-switch'); await pg.waitForTimeout(800);
    check('switched off: the tables hide', !(await pg.isVisible('#setupStaticTables')) && (await pg.evaluate(() => window.__FAKE_DB.campaigns[0].settings.static_tables.on)) === false);
    check('no script errors', !pg.errors.length, pg.errors.join(' | '));
    await pg.close();
  }

  console.log('A player, Play');
  {
    const r1 = { ...roundMission, id: 'mR1' };
    const pg = await openApp(b, world('p01', { settings: { static_tables: { on: true, count: 13, tables: { 1: tableMission.id } } }, missions: [tableMission, r1], round1: 'mR1' }));
    await pg.waitForTimeout(1500);
    const card = await pg.evaluate(() => {
      const svg = document.querySelector('#tournamentGameCta svg.static-table-map');
      return svg && { label: svg.getAttribute('aria-label'), zones: svg.querySelectorAll('.map-zones-over path').length, markers: svg.querySelectorAll('.map-marker').length,
        focusable: svg.querySelectorAll('[tabindex]').length, ids: svg.querySelectorAll('[id^="wcT"]').length === svg.querySelectorAll('[id]').length };
    });
    check('the table\'s card draws its map, the deployment over the terrain', card && /^Table 1: /.test(card.label) && card.zones === 2 && card.markers === r1.terrain.builder.layout.markers.length && !card.focusable && card.ids, JSON.stringify(card));
    await pg.evaluate(() => document.querySelector('#tournamentGameCta button[data-tournament-cta]')?.click()); await pg.waitForTimeout(1500);
    const st = await pg.evaluate(() => {
      const svg = document.querySelector('#gameMap svg');
      return { pick: document.getElementById('gameMissionSelect').value, title: svg?.querySelector('title')?.textContent || '',
        pieces: svg ? new Set([...svg.querySelectorAll('[data-piece]')].map(e => e.dataset.piece)).size : 0,
        markers: svg ? new Set([...svg.querySelectorAll('[data-marker]')].map(e => e.dataset.marker)).size : 0 };
    });
    const rb = r1.terrain.builder, tb = tableMission.terrain.builder;
    check('table 1\'s battle: the round\'s scenario on the table\'s terrain', st.pick === 'mR1'
      && st.pieces === rb.layout.pieces.length + tb.layout.pieces.length && st.markers === rb.layout.markers.length && tb.layout.pieces.length > 0, JSON.stringify({ ...st, r: rb.layout.pieces.length, t: tb.layout.pieces.length, m: rb.layout.markers.length }));
    check('no script errors', !pg.errors.length, pg.errors.join(' | '));
    await pg.close();
  }

  console.log('The organiser, the event builder');
  {
    const w = world();
    w.db.campaigns[0].status = 'draft';
    w.db.campaigns[0].player_cap = 8;
    w.db.campaign_phases = [];
    w.db.alliances = [];
    w.rpcSource = `{
      save_campaign_draft(a, db) { return { data: { id: 'c1', join_code: 'WAR-1' }, error: null }; },
      save_draft_scenarios(a, db) { const ids = a.p_scenarios.map((x, k) => { const id = 'saved' + k; db.missions.push({ ...x, id, campaign_id: a.p_campaign }); return id; }); return { data: ids, error: null }; },
      set_draft_round_scenarios() { return { data: null, error: null }; },
      set_draft_settings() { return { data: null, error: null }; },
    }`;
    const pg = await openApp(b, w);
    await pg.evaluate(() => document.getElementById('draftCampaignContinueBtn').click()); await pg.waitForTimeout(1500);
    await pg.evaluate(() => document.getElementById('cbTab-scenarios').click()); await pg.waitForTimeout(800);
    check('the Scenarios step has a TO-set tables switch, off', !!(await pg.$('#cbStaticToggle')) && !(await pg.isChecked('#cbStaticToggle')) && !(await pg.$('#cbT1')));
    await pg.evaluate(() => document.getElementById('cbStaticToggle').click()); await pg.waitForTimeout(500);
    check('switched on: a table for every two players', (await pg.$$eval('[data-cb-static-table]', es => es.length)) === 4 && await pg.inputValue('#cbStaticCount') === '4');
    await pg.fill('#cbStaticCount', '2'); await pg.press('#cbStaticCount', 'Tab'); await pg.waitForTimeout(500);
    check('the number of tables changes', (await pg.$$eval('[data-cb-static-table]', es => es.length)) === 2);
    await pg.evaluate(() => document.getElementById('cbNewT1').click()); await pg.waitForTimeout(1200);
    const tSteps = await stepKeys(pg);
    check('Build new for a table: terrain, no deployment or objectives', tSteps.includes('terrain') && !tSteps.some(k => ['deployment', 'objectives', 'feature'].includes(k)), tSteps.join());
    await pg.evaluate(() => { const t = document.getElementById('mapTerrainToggle'); if (!t.checked) t.click(); }); await pg.waitForTimeout(400);
    await pg.fill('#bfEventName', 'Ruined farm');
    await pg.click('#battlefieldOverlayDone'); await pg.waitForTimeout(1000);
    check('the new table is picked for table 1', /Ruined farm/.test(await pg.$eval('#cbT1', e => e.selectedOptions[0]?.textContent || '')));
    await pg.evaluate(() => document.getElementById('cbNewR0').click()); await pg.waitForTimeout(1200);
    const rSteps = await stepKeys(pg);
    check('Build new for a round: deployment, no terrain', rSteps.includes('deployment') && !rSteps.includes('terrain'), rSteps.join());
    await pg.evaluate(() => document.getElementById('battlefieldOverlayClose')?.click()); await pg.waitForTimeout(400);
    await pg.evaluate(() => document.getElementById('cbTab-review').click()); await pg.waitForTimeout(600);
    check('Review lists the tables', /TO-set tables: 2/.test(await pg.textContent('#cbPanel')));
    await pg.evaluate(() => document.getElementById('cbNextBtn').click()); await pg.waitForTimeout(2000);
    const st = await pg.evaluate(() => ({ s: window.__FAKE_DB.campaigns[0].settings.static_tables, m: window.__FAKE_DB.missions.find(m => m.name === 'Ruined farm') }));
    check('saved with the event: on, two tables, table 1 the new set-up', st.s?.on === true && st.s.count === 2 && st.m && st.s.tables[1] === st.m.id, JSON.stringify(st.s));
    check('no script errors', !pg.errors.length, pg.errors.join(' | '));
    await pg.close();
  }

  await b.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
