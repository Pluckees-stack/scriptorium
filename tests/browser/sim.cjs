// Random battles, played through the real page: random armies, scenario,
// turns (markers held, wounds), end-of-battle marks and Victory points
// entries, then logged. Each checks that the card, Finalise and what's
// logged agree, that the battle opens at the same score in the organiser's
// Edit form, and that nothing throws.
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/sim.cjs [battles] [seed]
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

let seed = Number(process.argv[3]) || 1;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const int = (n) => Math.floor(rnd() * n), pick = (xs) => xs[int(xs.length)];
const N = Number(process.argv[2]) || 6;

function army(prefix, roster) {
  return Array.from({ length: 3 + int(6) }, (_, i) => ({ id: `${prefix}${i}`, roster_id: roster, name: `${prefix.toUpperCase()}${i}`, category: pick(['core', 'special', 'characters']),
    size: i < 2 ? 1 : 1 + int(15), points: 10 + int(150), experience: 0, status: null, archived_at: null, current_wounds: null,
    wargear: { command: [i === 0 ? { active: true, name_en: 'General' } : i === 1 ? { active: true, name_en: 'Battle Standard Bearer' } : { active: false, name_en: '-' }] } }));
}
function world() {
  const common = ['king-is-dead', 'trophies-of-war', 'breaking-the-enemy'].filter(() => rnd() < .6);
  const secondary = ['special-feature', 'baggage-trains', 'domination', 'strategic-locations'].filter(() => rnd() < .5)
    .map(k => k === 'strategic-locations' ? { key: k, count: 1 + int(4) } : { key: k });
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }, { id: 'b', display_name: 'Bob' }],
      campaign_members: [{ user_id: 'a', campaign_id: 'c1', role: 'organiser', faction_id: 'empire-of-man', onboarded: true }, { user_id: 'b', campaign_id: 'c1', role: 'player', faction_id: 'skaven', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Sim', status: 'active', join_code: 'S-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }, { id: 'skaven', name: 'Skaven' }],
      rosters: [{ id: 'ra', player_id: 'a', campaign_id: 'c1', faction_id: 'empire-of-man', name: 'A', points_limit: 2000 }, { id: 'rb', player_id: 'b', campaign_id: 'c1', faction_id: 'skaven', name: 'B', points_limit: 2000 }],
      units: [...army('a', 'ra'), ...army('b', 'rb')],
      missions: [{ id: 'm1', campaign_id: 'c1', name: 'Sim field', mode: 'normal', turn_limit: 6, random_length: false, common_objectives: common, secondary_objectives: secondary, objective_vp: {}, custom_objective_ids: [], game_sizes: ['2000-2499'] }],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
    rpcSource: `{ log_game_with_xp: (args, db) => { window.__lastLogged = args.p_game; db.games.push({ ...args.p_game, id: 99, player_id: 'a', confirmation_status: 'pending', played_on: '2026-10-23' }); return { data: 99, error: null }; } }`,
  };
}
const db = (page, fn) => page.evaluate((f) => new Function('db', `return (${f})(db)`)(window.__FAKE_DB), fn.toString());
const num = (t) => Number(String(t).replace(/[^\d-]/g, '')) || 0;
const problems = [];
const bad = (n, what) => { problems.push(`battle ${n}: ${what}`); console.log(`  FAIL ${what}`); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  for (let n = 1; n <= N; n++) {
    const w = world(), m = w.db.missions[0];
    console.log(`battle ${n}: ${[...m.common_objectives, ...m.secondary_objectives.map(o => o.key)].join(', ') || 'units only'}`);
    const page = await openApp(browser, w, { phone: rnd() < .5 });
    try {
      await page.click('.tab-btn[data-tab="game"]'); await page.click('#startGameBtn');
      await page.waitForFunction(() => document.querySelectorAll('#gameOpponentSelect option').length > 1);
      await page.selectOption('#gameOpponentSelect', 'b'); await page.click('#opponentContinueBtn');
      await page.waitForFunction(() => document.querySelector('#gameMissionSelect option[value="m1"]'));
      await page.selectOption('#gameMissionSelect', 'm1'); await page.click('#missionContinueBtn');
      await page.waitForSelector('#gameStageWaiting:not(.hide)');
      await db(page, (d) => Object.assign(d.game_invites[0], { status: 'accepted', active_slot: 'first', current_round: 1, strategic_vp_from_user: 0, strategic_vp_to_user: 0 }));
      await page.waitForSelector('#gameStageSpells:not(.hide)', { timeout: 15000 }); await page.click('#spellsContinueBtn');
      await db(page, (d) => { d.game_invites[0].to_ready_at = 'now'; });
      await page.waitForSelector('#gameStagePick:not(.hide)', { timeout: 15000 });
      await page.click(rnd() < .5 ? '#pickSelfBtn' : '#pickOpponentBtn');
      await page.waitForSelector('#gameStagePlaying:not(.hide)'); await page.waitForTimeout(600);
      // a few rounds: Alice's turns on the page, Bob's in the database
      const rounds = 1 + int(4);
      for (let r = 0; r < rounds; r++) {
        if (await page.isEnabled('#gameNextTurnBtn')) {
          if (await page.isVisible('#gameStrategicLocationsWrap')) for (const id of ['gameStrategicLocationsInput', 'gameStrategicLocationsOppInput']) {
            for (let k = int(4); k > 0; k--) { const b = await page.$(`[data-strat-for="${id}"][data-strat-by="1"]:not(:disabled)`); if (b) await b.click(); }
          }
          await page.click('#gameNextTurnBtn'); await page.waitForTimeout(400);
        }
        // Bob's turn: he records both sides' markers too
        await db(page, (d) => { const i = d.game_invites[0]; i.strategic_vp_from_user += 30 * Math.floor(Math.random() * 2); i.strategic_vp_to_user += 30 * Math.floor(Math.random() * 3); i.active_slot = i.active_slot === 'first' ? 'second' : 'first'; if (i.active_slot === 'first') i.current_round++; });
        // wounds: one of Alice's units down on her tracker, one of Bob's on his
        await page.evaluate(() => { const bs = [...document.querySelectorAll('#rostersGame .wound-btn[data-action="dec"]')]; const b = bs[Math.floor(Math.random() * bs.length)]; for (let i = 0; i < 40 && b; i++) b.click(); });
        await db(page, (d) => { const us = d.units.filter(u => u.roster_id === 'rb'); us[Math.floor(Math.random() * us.length)].current_wounds = 0; });
        await page.waitForTimeout(3300);
      }
      const running = await page.textContent('#gameRunningTotals');
      if (!/VP/.test(running)) bad(n, 'no running total');
      await page.click('#endGameBtn'); await page.waitForSelector('#gameStageEnd:not(.hide)'); await page.waitForSelector('#vp-player-units-n');
      // end of battle: random marks on both armies
      for (const list of ['#opponentUnitsList', '#ownUnitsList']) {
        if (list === '#ownUnitsList') { await page.click('#endCardTheirs [data-end-go="1"]'); await page.waitForTimeout(500); }
        const ids = await page.$$eval(`${list} .seg-btn`, bs => [...new Set(bs.map(b => b.dataset.unitId))]);
        for (const id of ids) if (rnd() < .6) await page.click(`${list} .seg-btn[data-unit-id="${id}"][data-v="${pick(['dead', 'fled', 'fleeing', 'below25'])}"]`);
      }
      await page.click('#endCardOwn [data-end-go="2"]'); await page.waitForTimeout(600);
      await page.click('#vpTable details:nth-of-type(2) summary'); await page.waitForTimeout(400);
      // random entries on the card: switches, − and +, figures
      for (let k = 0; k < 6 + int(14); k++) {
        const ctl = await page.$$('#vpTable label.toggle-switch, #vpTable button[data-by]:not(:disabled)');
        const c = pick(ctl); if (c) { await c.scrollIntoViewIfNeeded(); await c.click(); }
      }
      if (rnd() < .5) { await page.fill('#vp-player-otherVp', String(int(200))); await page.press('#vp-player-otherVp', 'Tab'); }
      await page.waitForTimeout(300);
      // the card adds up: each side's total is its column
      for (const side of ['player', 'opponent']) {
        const total = num(await page.textContent(`#vpTotal-${side}`));
        const parts = await page.$$eval(`#vpTable .vp-cell[data-vp-key] `, (cs, s) => cs.filter(c => c.querySelector(`[id^="vp-${s}-"]`)).map(c => {
          const out = c.querySelector('.vp-cell-n'), inp = c.querySelector('input[type=number]');
          return out ? Number(out.textContent.replace(/[^\d]/g, '')) || 0 : inp ? Number(inp.value) || 0 : 0; }), side);
        const custom = 0;
        const sum = parts.reduce((x, y) => x + y, 0) + custom;
        if (sum !== total) bad(n, `${side}: card total ${total}, its rows add to ${sum}`);
      }
      const cardTotals = [num(await page.textContent('#vpTotal-player')), num(await page.textContent('#vpTotal-opponent'))];
      await page.click('#endCardVp [data-end-go="3"]'); await page.waitForTimeout(600);
      const final = await page.$$eval('#vpTally .vp-head-n', es => es.map(e => Number(e.textContent.replace(/[^\d]/g, ''))));
      const headline = await page.textContent('#vpTally .vp-headline');
      if ([...final].sort().join() !== [...cardTotals].sort().join()) bad(n, `Finalise ${final} v the card ${cardTotals}`);
      const [pv, ov] = cardTotals;
      if (pv > ov && /for Bob/.test(headline) || ov > pv && /for Alice/.test(headline)) bad(n, `headline "${headline}" for ${pv}–${ov}`);
      await page.click('#lgBtn'); await page.waitForTimeout(5500);
      const logged = await page.evaluate(() => window.__lastLogged);
      if (!logged) { bad(n, 'nothing logged'); continue; }
      if (logged.player_vp !== pv || logged.opponent_vp !== ov) bad(n, `logged ${logged.player_vp}–${logged.opponent_vp}, card ${pv}–${ov}`);
      for (const [k, b] of [['player', logged.player_breakdown], ['opponent', logged.opponent_breakdown]]) {
        const s = (b || []).reduce((x, y) => x + y.vp, 0), want = k === 'player' ? logged.player_vp : logged.opponent_vp;
        if (s !== want) bad(n, `${k} breakdown adds to ${s}, total ${want}`);
        if ((b || []).some(l => !l.entries)) bad(n, `${k} breakdown line without its entries`);
      }
      const exp = { player: logged.result, sorted: (logged.player_vp > logged.opponent_vp ? 'win' : logged.player_vp < logged.opponent_vp ? 'loss' : 'draw') };
      if (exp.player !== 'draw' && exp.player !== exp.sorted) bad(n, `result ${logged.result} for ${logged.player_vp}–${logged.opponent_vp}`);
      // the organiser opens it to put right: the same score
      await db(page, (d) => { const g = d.games.find(x => x.id === 99); g.opponent_id = 'b'; g.campaign_id = 'c1'; g.confirmation_status = 'confirmed'; });
      await page.evaluate(() => document.getElementById('adminModeToggle').click()); await page.waitForTimeout(1800);
      await page.evaluate(() => document.querySelector('#adminGameLog [data-action="game-edit"][data-id="99"]')?.click()); await page.waitForTimeout(600);
      if (await page.$('#flowTab1')) {
        await page.click('#flowTab1'); await page.waitForTimeout(400);
        const ed = [num(await page.textContent('#geditTotal-player')), num(await page.textContent('#geditTotal-opponent'))];
        if (ed[0] !== logged.player_vp || ed[1] !== logged.opponent_vp) bad(n, `Edit a battle opens at ${ed}, logged ${logged.player_vp}–${logged.opponent_vp}`);
      } else bad(n, 'Edit a battle didn\'t open');
      console.log(`  ${pv}–${ov}, "${headline.trim()}"`);
    } catch (e) { bad(n, `stopped: ${e.message.split('\n')[0]}`); }
    if (page.errors.length) bad(n, 'script errors: ' + page.errors.join(' | '));
    await page.close();
  }
  await browser.close();
  console.log(problems.length ? `\n${problems.length} problem(s)` : `\n${N} battles: no problems`);
  process.exit(problems.length ? 1 : 0);
})();
