// Story: a post with no photos shows three lines; More opens all of it in a
// scrolling overlay. Short posts and photo posts are left as they are.
//   python3 -m http.server 8765   (repo root)
//   NODE_PATH=$(npm root -g) node tests/browser/story-text.cjs
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

const long = Array.from({ length: 40 }, (_, i) => `Turn ${i + 1}: the line held and the cannon spoke again.`).join('\n\n');
function world() {
  const at = (m) => new Date(Date.now() - m * 60000).toISOString();
  const post = (id, minsAgo, body, photos = []) => ({
    post: { id, campaign_id: 'c1', author_id: 'b', kind: 'battle', game_id: null, free_play: true, other_player_id: null, unit_id: null, title: null, headline: null, campaign_name: 'Test campaign', shared: false, hidden: false, published: true, created_at: at(minsAgo) },
    account: { id: 'acc' + id, chronicle_post_id: id, post_id: id, author_id: 'b', author_name: 'Bertha', author_faction: 'empire-of-man', body, photos, created_at: at(minsAgo) },
  });
  const ps = [post('p1', 1, long), post('p2', 2, 'Short and sweet.'), post('p3', 3, long, ['b/x.webp'])];
  return {
    session: { access_token: 'x', user: { id: 'a', email: 'a@example.com', user_metadata: {} } },
    db: {
      players: [{ id: 'a', display_name: 'Alice' }, { id: 'b', display_name: 'Bertha' }],
      campaign_members: [{ user_id: 'a', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true }, { user_id: 'b', campaign_id: 'c1', role: 'player', faction_id: 'empire-of-man', onboarded: true }],
      campaigns: [{ id: 'c1', name: 'Test campaign', status: 'active', join_code: 'T-1', settings: {}, created_by: 'a', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: null }],
      factions: [{ id: 'empire-of-man', name: 'Empire' }],
      rosters: [], units: [], missions: [],
      game_invites: [], games: [], announcements: [], notifications: [], free_play_log: [],
      chronicle_posts: ps.map(p => p.post), chronicle_accounts: ps.map(p => p.account), chronicle_likes: [], chronicle_follows: [],
    },
  };
}
const fails = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) fails.push(what); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  for (const phone of [true, false]) {
    const tag = phone ? 'phone' : 'desktop';
    const page = await openApp(browser, world(), { phone });
    await page.evaluate(() => document.querySelector('.tab-btn[data-tab="narrative"]').click());
    await page.waitForSelector('#chronicleFeed .chron-post[data-post-id="p1"]', { timeout: 5000 });
    await page.waitForTimeout(300);
    const s = await page.evaluate(() => {
      const art = (id) => document.querySelector(`.chron-post[data-post-id="${id}"]`);
      const lh = parseFloat(getComputedStyle(art('p1').querySelector('.chron-cap')).lineHeight);
      const more = (id) => { const b = art(id).querySelector('.chron-more'); return b ? !b.classList.contains('hide') : null; };
      return {
        longH: art('p1').querySelector('.chron-text').clientHeight, lh,
        longMore: more('p1'), shortMore: more('p2'), photoText: !!art('p3').querySelector('.chron-text'),
        photoCapH: art('p3').querySelector('.chron-cap').clientHeight,
      };
    });
    check(s.longH > 0 && s.longH <= s.lh * 3 + 8, `${tag}: long text-only post held to three lines (${s.longH}px, line ${s.lh}px)`);
    check(s.longMore === true, `${tag}: long post shows More`);
    check(s.shortMore === false, `${tag}: short post has no More`);
    check(!s.photoText && s.photoCapH > s.lh * 10, `${tag}: photo post's caption is not cut`);
    await page.click('.chron-post[data-post-id="p1"] .chron-more');
    const o = await page.evaluate(() => {
      const ov = document.getElementById('chronTextOverlay'), body = document.getElementById('chronTextBody');
      const r = { open: !ov.classList.contains('hide'), title: document.getElementById('chronTextTitle').textContent,
        scrollable: body.scrollHeight > body.clientHeight, fits: body.getBoundingClientRect().bottom <= innerHeight + 1,
        full: body.textContent.includes('Turn 40:'), focus: document.activeElement.id };
      body.scrollTop = 400; r.scrolled = body.scrollTop > 0;
      return r;
    });
    check(o.open && o.title === 'Bertha', `${tag}: More opens the overlay titled with the poster`);
    check(o.full, `${tag}: overlay has the whole text`);
    check(o.scrollable && o.scrolled && o.fits, `${tag}: overlay scrolls inside and fits the screen`);
    check(o.focus === 'chronTextClose', `${tag}: focus moves to close`);
    await page.keyboard.press('Escape');
    const c = await page.evaluate(() => ({ hidden: document.getElementById('chronTextOverlay').classList.contains('hide'), back: document.activeElement.classList.contains('chron-more') }));
    check(c.hidden && c.back, `${tag}: Escape closes it and focus returns to More`);
    // tapping the faded text opens it too; the backdrop closes it
    await page.click('.chron-post[data-post-id="p1"] .chron-text');
    const t = await page.evaluate(() => !document.getElementById('chronTextOverlay').classList.contains('hide'));
    await page.mouse.click(3, 3);
    const b = await page.evaluate(() => document.getElementById('chronTextOverlay').classList.contains('hide'));
    check(t && b, `${tag}: tapping the text opens it; tapping outside closes it`);
    check(!page.errors.length, `${tag}: no page errors` + (page.errors.length ? ': ' + page.errors.join('; ') : ''));
    await page.context().close();
  }
  await browser.close();
  if (fails.length) { console.log(`${fails.length} failed`); process.exit(1); }
  console.log('all passed');
})();
