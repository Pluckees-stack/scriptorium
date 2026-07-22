// Regression test for VP scoring (index.html's computeVpTally and its
// dependencies: unitTotalPoints's pricing chain, unitCommandNames,
// objectiveVpFor, DEFAULT_OBJECTIVE_VP, VP_MULTIPLIER). Run manually after
// touching any of that code:
//
//   node tests/vp/run.mjs
//
// Same extraction approach as tests/points/run.mjs (see that file for why):
// pulls the real function/const bodies out of index.html by name and evals
// them, so this exercises the actual shipped code rather than a hand-copy
// that could drift out of sync. computeVpTally() itself doesn't take
// parameters though — it reads opponentUnitsCache/opponentUnitState/
// selectedMission/manualObjectiveState/strategicLocationVpTotal as free
// variables from the enclosing closure. The harness declares those as
// `let` bindings and exposes a setState() to populate them per fixture
// before calling computeVpTally(), standing in for what loading a real
// game state into the page would otherwise do.
//
// To add a fixture: drop a new tests/vp/fixtures/*.json — see the existing
// fixtures for the shape. Work out `expected` by hand from the VP rules in
// computeVpTally (index.html, ~line 3292), not by running the code, since
// that's the thing being checked.

import { readFileSync, readdirSync, writeFileSync, mkdtempSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
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

function extractConst(name) {
  const marker = 'const ' + name + ' = ';
  const start = scriptSrc.indexOf(marker);
  if (start === -1) throw new Error(`Could not find const ${name} in index.html`);
  let depth = 0, seenBrace = false, i = start;
  for (; i < scriptSrc.length; i++) {
    const c = scriptSrc[i];
    if (c === '{') { depth++; seenBrace = true; }
    else if (c === '}') depth--;
    else if (c === ';' && seenBrace && depth === 0) { i++; break; }
  }
  return scriptSrc.slice(start, i);
}

const CONST_NAMES = ['DEFAULT_OBJECTIVE_VP', 'VP_MULTIPLIER'];
const FN_NAMES = [
  'stackableQtyOf', 'entryCost', 'subOptionsCost', 'selectedItemCost', 'detachmentCost', 'unitTotalPoints',
  'unitCommandNames', 'objectiveVpFor', 'computeVpTally',
];

const harnessSrc = [
  'let opponentUnitsCache, opponentUnitState, selectedMission, manualObjectiveState, strategicLocationVpTotal;',
  ...CONST_NAMES.map(extractConst),
  ...FN_NAMES.map(extractFn),
  `function setState(s) {
     opponentUnitsCache = s.opponentUnitsCache;
     opponentUnitState = s.opponentUnitState;
     selectedMission = s.selectedMission;
     manualObjectiveState = s.manualObjectiveState;
     strategicLocationVpTotal = s.strategicLocationVpTotal;
   }`,
  'module.exports = { computeVpTally, setState };',
].join('\n\n');

const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-vp-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const { computeVpTally, setState } = await import(harnessPath);

const fixturesDir = path.join(here, 'fixtures');
const fixtureFiles = readdirSync(fixturesDir).filter(f => f.endsWith('.json'));

let failed = 0;
for (const file of fixtureFiles) {
  const fixture = JSON.parse(readFileSync(path.join(fixturesDir, file), 'utf8'));

  const opponentUnitsCache = fixture.opponentUnits.map(u => ({
    id: u.id, points: u.points, size: u.size ?? 1, wargear: u.wargear || {},
  }));
  const opponentUnitState = {};
  fixture.opponentUnits.forEach(u => { opponentUnitState[u.id] = { status: u.status }; });

  setState({
    opponentUnitsCache,
    opponentUnitState,
    selectedMission: fixture.selectedMission ?? null,
    manualObjectiveState: fixture.manualObjectiveState || {},
    strategicLocationVpTotal: fixture.strategicLocationVpTotal || 0,
  });

  const actual = computeVpTally();
  const checkedKeys = Object.keys(fixture.expected);
  const mismatches = checkedKeys.filter(k => actual[k] !== fixture.expected[k]);
  const ok = mismatches.length === 0;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${file}` +
    (ok ? '' : `\n       ${mismatches.map(k => `${k}: expected ${JSON.stringify(fixture.expected[k])}, got ${JSON.stringify(actual[k])}`).join('\n       ')}`));
}

console.log(`\n${fixtureFiles.length - failed}/${fixtureFiles.length} fixtures passed.`);
process.exit(failed ? 1 : 0);
