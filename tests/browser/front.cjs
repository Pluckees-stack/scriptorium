// Browser checks for the front page (signed out): the sign-in card switches
// between Sign in and Create account, a join link opens Create account.
//   python3 -m http.server 8765 &
//   NODE_PATH=$(npm root -g) node tests/browser/front.cjs [screenshot dir]
const { chromium } = require('playwright');
const { openApp } = require('./app.cjs');

let failures = 0;
const check = (label, cond, detail = '') => { if (cond) console.log(`  ok   ${label}`); else { failures++; console.log(`  FAIL ${label}${detail ? ` -- ${detail}` : ''}`); } };
const shown = (p, sel) => p.$eval(sel, e => !e.closest('.hide') && e.offsetParent !== null).catch(() => false);
const shots = process.argv[2];

(async () => {
  const b = await chromium.launch();
  for (const phone of [false, true]) {
    console.log(phone ? 'Signed out, on a phone' : 'Signed out, on a wide screen');
    const p = await openApp(b, { session: null, db: {} }, { phone });
    check('front page shows', await shown(p, '#login'));
    check('Sign in is picked', await p.$eval('#toLogin', e => e.getAttribute('aria-checked')) === 'true');
    check('sign-in fields show', await shown(p, '#username') && !(await shown(p, '#suUser')));
    check('Google button shows', await shown(p, '#googleSignin'));
    check('no hint placeholders', await p.$$eval('#login input[placeholder]', l => l.length) === 0);
    check('only the eyebrow, title and motto beside the card', await p.$$eval('.front-hero > *', l => l.map(e => e.textContent.trim()).join(' | ')) === 'Warhammer: The Old World | The Scriptorium | Every deed is weighed. Every death is recorded.');
    check('no sideways scroll', await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    if (shots) await p.screenshot({ path: `${shots}/front-${phone ? 'phone' : 'wide'}.png`, fullPage: true });
    await p.click('#toSignup');
    check('Create account switches the card', await shown(p, '#suUser') && !(await shown(p, '#username')));
    check('heading follows', await p.$eval('#authHeading', e => e.textContent) === 'Create account');
    await p.focus('#toSignup'); await p.keyboard.press('ArrowLeft');
    check('arrow keys switch back', await shown(p, '#username') && await p.evaluate(() => document.activeElement.id) === 'toLogin');
    if (shots && phone) { await p.click('#toSignup'); await p.screenshot({ path: `${shots}/front-signup-phone.png`, fullPage: true }); }
    check('no errors', p.errors.length === 0, p.errors.join(' | '));
    await p.context().close();
  }

  console.log('A join link, signed out');
  const p = await openApp(b, { session: null, db: {} });
  await p.goto((process.env.APP_URL || 'http://localhost:8765/index.html') + '?join=ABC123');
  await p.waitForTimeout(2500);
  check('opens Create account', await shown(p, '#suUser'));
  check('join note shows', await shown(p, '#authJoinNote'));
  await p.context().close();

  await b.close();
  console.log(failures ? `${failures} failed` : 'all passed');
  process.exit(failures ? 1 : 0);
})();
