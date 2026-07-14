// Regression test for the unit points formula (index.html's unitTotalPoints
// and its shared pricing helpers: entryCost/subOptionsCost/selectedItemCost/
// detachmentCost). Run manually after touching any of that code:
//
//   node tests/points/run.mjs
//
// index.html has no build step or module system by design (see CLAUDE.md --
// it stays a single file), so there's nothing to `import` from. Instead this
// extracts the actual function bodies straight out of index.html by name and
// evals them, so the test exercises the real shipped code rather than a
// hand-maintained copy that could itself drift out of sync.
//
// To add a fixture: drop a new tests/points/fixtures/*.json with the shape
// `{ "description": "...", "owbUnit": {...raw unit object from an
// .owb.json export...}, "expectedTotal": <the correct points total> }`.
// Work out expectedTotal by hand from the unit's rules/wargear costs -- it's
// the thing this test is checking the code against, so it can't be sourced
// from the code itself.

import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');

const html = readFileSync(path.join(repoRoot, 'index.html'), 'utf8');
const scriptMatch = html.match(/<script type="module">([\s\S]*?)<\/script>/);
if (!scriptMatch) throw new Error('Could not find <script type="module"> in index.html');
const scriptSrc = scriptMatch[1];

function extractFn(name) {
  const marker = 'function ' + name + '(';
  const start = scriptSrc.indexOf(marker);
  if (start === -1) throw new Error(`Could not find function ${name}() in index.html`);
  let depth = 0, i = scriptSrc.indexOf('{', start);
  for (; i < scriptSrc.length; i++) {
    if (scriptSrc[i] === '{') depth++;
    else if (scriptSrc[i] === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  return scriptSrc.slice(start, i);
}

const FN_NAMES = ['stackableQtyOf', 'entryCost', 'subOptionsCost', 'selectedItemCost', 'detachmentCost', 'unitTotalPoints'];
const harnessSrc = FN_NAMES.map(extractFn).join('\n\n') + '\nmodule.exports = { unitTotalPoints };';

import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-points-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const { unitTotalPoints } = await import(harnessPath);

const fixturesDir = path.join(here, 'fixtures');
const fixtureFiles = readdirSync(fixturesDir).filter(f => f.endsWith('.json'));

let failed = 0;
for (const file of fixtureFiles) {
  const fixture = JSON.parse(readFileSync(path.join(fixturesDir, file), 'utf8'));
  const owb = fixture.owbUnit;
  const u = {
    points: owb.points,
    size: owb.strength,
    wargear: {
      equipment: owb.equipment, armor: owb.armor, options: owb.options,
      command: owb.command, mounts: owb.mounts, items: owb.items,
      detachments: owb.detachments,
    },
  };
  const actual = unitTotalPoints(u);
  const ok = actual === fixture.expectedTotal;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${file}  expected ${fixture.expectedTotal}, got ${actual}`);
}

console.log(`\n${fixtureFiles.length - failed}/${fixtureFiles.length} fixtures passed.`);
process.exit(failed ? 1 : 0);
