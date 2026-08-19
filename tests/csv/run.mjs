// Regression test for the Scenario Admin CSV bulk-import (index.html's
// parseCsv/csvRowsToObjects/buildMissionPayloadFromCsvRow). Run manually
// after touching any of that code:
//
//   node tests/csv/run.mjs
//
// Same extraction approach as tests/points/run.mjs (see that file for
// why): pulls the real function/const bodies out of index.html by name
// and evals them, so this exercises the actual shipped code. No fixture
// files here — the inputs are short synthetic CSV/row strings authored
// directly in this file, since there's no external data format to source
// them from (unlike an .owb.json export).

import { readFileSync, mkdtempSync, writeFileSync } from 'node:fs';
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
    else if (c === ';' && !seenBrace) { i++; break; } // one-line const with no braces at all (e.g. VP_OVERRIDE_KEY_ALIASES's Object.fromEntries(...) call)
  }
  return scriptSrc.slice(start, i);
}

const CONST_NAMES = ['COMMON_OBJECTIVES', 'SECONDARY_OBJECTIVES', 'DEFAULT_OBJECTIVE_VP', 'OBJECTIVE_VP_FIELDS', 'VP_OVERRIDE_KEY_ALIASES'];
const FN_NAMES = ['parseCsv', 'csvRowsToObjects', 'buildMissionPayloadFromCsvRow'];

const harnessSrc = [
  'let customObjectivesCache = [];', // buildMissionPayloadFromCsvRow's custom_objectives lookup — set per test
  ...CONST_NAMES.map(extractConst),
  ...FN_NAMES.map(extractFn),
  // A named function reference (not an inline arrow value) in the exports
  // object below — cjs-module-lexer's static named-export detection (used
  // for a .cjs file loaded via dynamic import()) doesn't reliably pick up
  // arrow functions written directly as object property values.
  'function setCustomObjectives(v) { customObjectivesCache = v; }',
  'module.exports = { parseCsv, csvRowsToObjects, buildMissionPayloadFromCsvRow, setCustomObjectives };',
].join('\n\n');

const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-csv-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const { parseCsv, csvRowsToObjects, buildMissionPayloadFromCsvRow, setCustomObjectives } = await import(harnessPath);

let failed = 0;
function check(label, cond, detail) {
  const ok = !!cond;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}` + (ok ? '' : `\n       ${detail || ''}`));
}
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

// --- parseCsv ---
check('plain row', eq(parseCsv('a,b,c\n1,2,3\n'), [['a', 'b', 'c'], ['1', '2', '3']]));
check('quoted field with embedded comma', eq(parseCsv('name,note\nBridge,"Control the bridge, then hold it"\n'),
  [['name', 'note'], ['Bridge', 'Control the bridge, then hold it']]));
check('escaped quote inside a quoted field', eq(parseCsv('name\n"the ""Broken"" Bridge"\n'), [['name'], ['the "Broken" Bridge']]));
check('embedded newline inside a quoted field', eq(parseCsv('name,note\nBridge,"line one\nline two"\n'),
  [['name', 'note'], ['Bridge', 'line one\nline two']]));
check('no trailing newline still captures the last row', eq(parseCsv('a,b\n1,2'), [['a', 'b'], ['1', '2']]));

// --- csvRowsToObjects ---
{
  const rows = [['name', 'turn_limit'], ['Scenario 1', '6'], ['', ''], ['Scenario 2', '5']];
  const objs = csvRowsToObjects(rows);
  check('blank rows are skipped, others keyed by header', eq(objs, [
    { name: 'Scenario 1', turn_limit: '6' },
    { name: 'Scenario 2', turn_limit: '5' },
  ]), JSON.stringify(objs));
}

// --- buildMissionPayloadFromCsvRow ---
{
  const r = buildMissionPayloadFromCsvRow({ name: '' });
  check('missing name is rejected', r.ok === false && /name/i.test(r.reason));
}
{
  const r = buildMissionPayloadFromCsvRow({
    name: 'Scenario 4: The Broken Bridge',
    turn_limit: '6', random_length: 'false',
    common_objectives: 'king-is-dead;trophies-of-war',
    secondary_objectives: 'domination;strategic-locations:4',
    objective_vp_overrides: 'domination-quarter=150',
  });
  check('a well-formed row builds a full payload', r.ok === true, JSON.stringify(r));
  check('turn_limit parsed as a number', r.ok && r.payload.turn_limit === 6);
  check('common_objectives parsed as an array', r.ok && eq(r.payload.common_objectives, ['king-is-dead', 'trophies-of-war']));
  check('secondary_objectives keeps the count on strategic-locations', r.ok && eq(r.payload.secondary_objectives, [{ key: 'domination' }, { key: 'strategic-locations', count: 4 }]));
  check('objective_vp override applied', r.ok && r.payload.objective_vp['domination-quarter'] === 150);
}
{
  const r = buildMissionPayloadFromCsvRow({ name: 'Bad row', common_objectives: 'not-a-real-key' });
  check('unknown common_objectives key is rejected', r.ok === false && /not-a-real-key/.test(r.reason));
}
{
  // strategic-locations-per-marker/trophies-of-war-standard are the real
  // DEFAULT_OBJECTIVE_VP keys, but a reasonable guess is the objective's
  // own key instead — accepted as shorthand wherever it's unambiguous.
  const r = buildMissionPayloadFromCsvRow({ name: 'Alias row', objective_vp_overrides: 'strategic-locations=50;trophies-of-war=75' });
  check('single-field objective keys are accepted as VP override aliases', r.ok === true, JSON.stringify(r));
  check('alias resolves to the real strategic-locations-per-marker key', r.ok && r.payload.objective_vp['strategic-locations-per-marker'] === 50);
  check('alias resolves to the real trophies-of-war-standard key', r.ok && r.payload.objective_vp['trophies-of-war-standard'] === 75);
}
{
  // domination has three VP fields, so its bare objective key stays
  // ambiguous/rejected — the exact field key is still required there.
  const r = buildMissionPayloadFromCsvRow({ name: 'Bad row', objective_vp_overrides: 'domination=100' });
  check('a multi-field objective key alone is still rejected', r.ok === false && /domination/.test(r.reason));
}
{
  const r = buildMissionPayloadFromCsvRow({ name: 'Bad row', secondary_objectives: 'strategic-locations:not-a-number' });
  check('non-numeric strategic-locations count is rejected', r.ok === false);
}
{
  setCustomObjectives([{ id: 'abc123', name: 'Hold the Shrine' }]);
  const okRow = buildMissionPayloadFromCsvRow({ name: 'Shrine scenario', custom_objectives: 'Hold the Shrine' });
  check('custom objective resolved by name to its id', okRow.ok && eq(okRow.payload.custom_objective_ids, ['abc123']));
  const badRow = buildMissionPayloadFromCsvRow({ name: 'Shrine scenario', custom_objectives: 'Nonexistent Objective' });
  check('unknown custom objective name is rejected', badRow.ok === false && /Nonexistent Objective/.test(badRow.reason));
  setCustomObjectives([]);
}
{
  const r = buildMissionPayloadFromCsvRow({ name: 'Random length', random_length: 'true', turn_limit: '6' });
  check('random_length true drops the turn limit', r.ok && r.payload.turn_limit === null && r.payload.random_length === true);
}

console.log(`\n${failed === 0 ? 'All checks passed.' : failed + ' check(s) failed.'}`);
process.exit(failed ? 1 : 0);
