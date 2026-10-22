// Opens the real index.html in Chromium with a fake Supabase (fake-supabase.mjs:
// an in-memory database behind the same query API) seeded with a world:
// { session: { user }, db: { table: [rows] } }. Serve the repo root first:
//   python3 -m http.server 8765
const { devices } = require('playwright');
const fs = require('fs');
const fake = fs.readFileSync(__dirname + '/fake-supabase.mjs', 'utf8');
// phone: a Pixel 5; else a screen of viewport's size (touch: a tablet's touchscreen)
async function openApp(browser, w, { phone = false, campaign = 'c1', viewport = { width: 1280, height: 900 }, touch = false } = {}) {
  const ctx = await browser.newContext(phone ? { ...devices['Pixel 5'] } : { viewport, hasTouch: touch });
  await ctx.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm', r => r.fulfill({ contentType: 'text/javascript', body: fake }));
  await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => r.fulfill({ body: '' }));
  await ctx.addInitScript(([w, campaign]) => {
    window.__FAKE_DB = w.db; window.__FAKE_SESSION = w.session;
    try {
      localStorage.setItem('scriptorium.campaign.' + w.session.user.id, campaign);
      localStorage.setItem('scriptorium-splash-seen', '1');
    } catch {}
  }, [w, campaign]);
  // stand-ins for database functions, as source (a world can't carry functions): w.rpcSource
  if (w.rpcSource) await ctx.addInitScript(`window.__FAKE_RPC = (${w.rpcSource});`);
  const page = await ctx.newPage();
  page.errors = [];
  page.on('pageerror', e => page.errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) page.errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());
  await page.goto(process.env.APP_URL || 'http://localhost:8765/index.html');
  await page.waitForTimeout(2500);
  return page;
}
module.exports = { openApp };
