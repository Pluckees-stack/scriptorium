// Quick taps on controls don't zoom the page on phones (touch-action: manipulation):
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/tap-zoom.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

function world() {
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }],
      campaign_members: [{ user_id: 'a', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }],
      rosters: [], units: [], missions: [],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
    },
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await openApp(browser, world());
  const probe = await page.evaluate(() => {
    const out = {};
    for (const html of ['<button class="wound-btn is-plus">+</button>', '<button class="act">Go</button>', '<a href="#">x</a>', '<input>', '<select></select>', '<label>x</label>']) {
      const host = document.createElement('div'); host.innerHTML = html; document.body.appendChild(host);
      out[html] = getComputedStyle(host.firstChild).touchAction; host.remove();
    }
    out.tabs = [...document.querySelectorAll('.tab-btn')].every(b => getComputedStyle(b).touchAction === 'manipulation');
    return out;
  });
  for (const [k, v] of Object.entries(probe)) if (k !== 'tabs') check(v === 'manipulation', `${k} doesn't double-tap zoom`);
  check(probe.tabs, 'tab bar buttons don\'t double-tap zoom');
  const vp = await page.$eval('meta[name="viewport"]', m => m.content);
  check(!/user-scalable\s*=\s*no|maximum-scale\s*=\s*1(\D|$)/.test(vp), 'pinch zoom left on (viewport doesn\'t block it)');
  check(!page.errors.length, 'no page errors' + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
