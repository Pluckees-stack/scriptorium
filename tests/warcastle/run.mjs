// Regression test for WarCastle's Fortenhaf map (index.html's WARCASTLE and
// the warcastle* helpers). Run manually after touching any of that code:
//
//   node tests/warcastle/run.mjs
//
// Same extraction approach as tests/tournaments/run.mjs: pulls the real
// constants and function bodies out of index.html and evals them.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const html = readFileSync(path.resolve(here, '..', '..', 'index.html'), 'utf8');
const scriptSrc = html.match(/<script type="module">([\s\S]*?)<\/script>/)[1];

function extractFn(name) {
  const start = scriptSrc.indexOf('function ' + name + '(');
  if (start === -1) throw new Error(`Could not find function ${name}() in index.html`);
  let depth = 0, i = scriptSrc.indexOf('{', start);
  for (; i < scriptSrc.length; i++) {
    if (scriptSrc[i] === '{') depth++;
    else if (scriptSrc[i] === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  return scriptSrc.slice(start, i);
}
function extractConst(name) {
  const start = scriptSrc.indexOf('const ' + name + ' = ');
  if (start === -1) throw new Error(`Could not find const ${name} in index.html`);
  let depth = 0, i = start;
  for (; i < scriptSrc.length; i++) {
    const c = scriptSrc[i];
    if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') depth--;
    else if (c === ';' && depth === 0) { i++; break; }
  }
  return scriptSrc.slice(start, i);
}

const src = ['WARCASTLE_REGIONS', 'WARCASTLE_DIRECTIONS', 'WARCASTLE'].map(extractConst).join('\n') + '\n'
  + ['warcastleArea', 'warcastleCrossing', 'warcastleCameFrom', 'warcastleNeighbours', 'warcastleGridCells', 'warcastleAreaAt',
    'warcastleViewFrom', 'tournamentPairingMissionId'].map(extractFn).join('\n')
  + '\nreturn { WARCASTLE, WARCASTLE_REGIONS, WARCASTLE_DIRECTIONS, warcastleArea, warcastleCrossing, warcastleCameFrom, warcastleNeighbours, warcastleGridCells, warcastleAreaAt, warcastleViewFrom };';
const W = new Function(src)();

let failures = 0;
function check(label, cond, detail = '') {
  if (cond) console.log(`  ok   ${label}`);
  else { failures++; console.log(`  FAIL ${label}${detail ? ` -- ${detail}` : ''}`); }
}

console.log('Areas and regions');
const areas = W.WARCASTLE.areas;
check('13 areas, numbered 1 to 13', areas.length === 13 && areas.every((a, i) => a.n === i + 1));
const byRegion = r => areas.filter(a => a.region === r).map(a => a.n).join(',');
check('regions as in warcastle-brief.md',
  byRegion('river') === '1,2' && byRegion('woodlands') === '3,4' && byRegion('town') === '7,8'
  && byRegion('mountains') === '5,6' && byRegion('plains') === '9,10,11,12,13');

console.log('Crossings');
const cs = W.WARCASTLE.crossings;
check('25 crossings, A to Y', cs.length === 25 && cs.map(c => c.id).join('') === 'ABCDEFGHIJKLMNOPQRSTUVWXY');
const pairs = new Set(cs.map(c => [Math.min(c.a, c.b), Math.max(c.a, c.b)].join('-')));
check('never two crossings between the same areas', pairs.size === 25);
check('every crossing joins two real areas', cs.every(c => c.a !== c.b && W.warcastleArea(c.a) && W.warcastleArea(c.b)));
const opposite = { n: 's', s: 'n', e: 'w', w: 'e', ne: 'sw', sw: 'ne', nw: 'se', se: 'nw' };
const bad = cs.filter(c => opposite[c.ab] !== c.ba);
check('each crossing\'s two directions are opposite', !bad.length, bad.map(c => c.id).join(' '));
check('directions are known', cs.every(c => W.WARCASTLE_DIRECTIONS[c.ab] && W.WARCASTLE_DIRECTIONS[c.ba]));
// every area can be reached from every other
const seen = new Set([1]), queue = [1];
while (queue.length) W.warcastleNeighbours(queue.shift()).forEach(x => { if (!seen.has(x.n)) { seen.add(x.n); queue.push(x.n); } });
check('the map is all connected', seen.size === 13);

console.log('Moves');
check('2 into 7 comes from the north-east', W.warcastleCameFrom(2, 7) === 'ne');
check('7 into 2 comes from the south-west', W.warcastleCameFrom(7, 2) === 'sw');
check('10 into 9 comes from the south', W.warcastleCameFrom(10, 9) === 's');
check('no crossing between 1 and 13', W.warcastleCrossing(1, 13) === null && W.warcastleCameFrom(1, 13) === null);
check('area 9 has seven neighbours', W.warcastleNeighbours(9).map(x => x.n).join(',') === '1,3,7,8,10,11,13');

console.log('Tap grid');
const cells = W.warcastleGridCells();
check('200 by 133 squares, every one in an area', cells.length === 26600 && cells.every(n => n >= 1 && n <= 13));
const off = areas.filter(a => W.warcastleAreaAt(a.x, a.y) !== a.n);
check('each area\'s painted number is inside it', !off.length, off.map(a => a.n).join(' '));
// each crossing sits on the border between its two areas: both are within 50px
const near = (x, y, n) => { for (let dx = -50; dx <= 50; dx += 10) for (let dy = -50; dy <= 50; dy += 10) if (W.warcastleAreaAt(x + dx, y + dy) === n) return true; return false; };
const stray = cs.filter(c => !near(c.x, c.y, c.a) || !near(c.x, c.y, c.b));
check('each crossing is on the border between its two areas', !stray.length, stray.map(c => c.id).join(' '));

console.log('Who\'s where');
const round = { id: 'r1', round_number: 2, per_table_scenarios: true };
const view = W.warcastleViewFrom(round, [
  { round_id: 'r1', table_number: 7, player_a_id: 'p1', player_b_id: 'p2', mission_id: 'm7' },
  { round_id: 'r1', table_number: 13, player_a_id: 'p3', player_b_id: null, mission_id: null },
  { round_id: 'r0', table_number: 1, player_a_id: 'p4', player_b_id: 'p5' },
  { round_id: 'r1', table_number: 99, player_a_id: 'p6', player_b_id: 'p7' },
], id => id.toUpperCase(), id => ({ m7: 'The manor' })[id]);
check('armies by area', JSON.stringify(view.occupants) === JSON.stringify({ 7: [{ id: 'p1', name: 'P1' }, { id: 'p2', name: 'P2' }], 13: [{ id: 'p3', name: 'P3' }] }));
check('table scenarios by area', JSON.stringify(view.tables) === JSON.stringify({ 7: 'The manor' }));
check('no round: an empty map', JSON.stringify(W.warcastleViewFrom(null, [], x => x, x => x)) === JSON.stringify({ round: null, occupants: {}, tables: {} }));

console.log(failures ? `\n${failures} failed` : '\nAll passed');
process.exit(failures ? 1 : 0);
