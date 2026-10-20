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
  // the body's brace (after the parameters, which can hold { destructuring })
  let depth = 0, i = scriptSrc.indexOf(') {', start) + 2;
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

const CONSTS = ['WARCASTLE_REGIONS', 'WARCASTLE_DIRECTIONS', 'WARCASTLE', 'WARCASTLE_MOVE_GROUPS', 'WARCASTLE_TIERS', 'rectPts', 'arcPts', 'DEPLOYMENT_MAPS'];
const FNS = ['warcastleArea', 'warcastleCrossing', 'warcastleCameFrom', 'warcastleNeighbours', 'warcastleGridCells', 'warcastleAreaAt',
  'warcastleViewFrom', 'tournamentPairingMissionId', 'warcastleMoveGroupOf', 'warcastlePositions', 'warcastleResults',
  'warcastleManoeuvre', 'warcastleTablesFromMap', 'warcastleDeployment'];
const src = CONSTS.map(extractConst).join('\n') + '\n' + FNS.map(extractFn).join('\n')
  + `\nreturn { ${[...CONSTS, ...FNS].join(', ')} };`;
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

console.log('Moving');
// 6 armies, round 2: in round 1 p1 beat p2 in area 9, p3 drew p4 in area 7, p5 beat p6 in area 13
const armies = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
const faction = { p1: 'dwarfen-mountain-holds', p2: 'high-elf-realms', p3: 'skaven', p4: 'empire-of-man', p5: 'vampire-counts', p6: 'lizardmen' };
let seq = 0;
const mv = (round, player, from, to) => ({ round_number: round, player_id: player, from_area: from, to_area: to, seq: ++seq });
const placed = [mv(1, 'p1', null, 9), mv(1, 'p2', null, 9), mv(1, 'p3', null, 7), mv(1, 'p4', null, 7), mv(1, 'p5', null, 13), mv(1, 'p6', null, 13)];
const r1 = [
  { player_a_id: 'p1', player_b_id: 'p2', result: 'a_win' },
  { player_a_id: 'p3', player_b_id: 'p4', result: 'draw' },
  { player_a_id: 'p5', player_b_id: 'p6', result: 'b_win' },
];
check('positions after placing', JSON.stringify(W.warcastlePositions(placed, 1)) === JSON.stringify({ p1: 9, p2: 9, p3: 7, p4: 7, p5: 13, p6: 13 }));
check('results', JSON.stringify(W.warcastleResults(r1)) === JSON.stringify({ p1: 'win', p2: 'loss', p3: 'draw', p4: 'draw', p5: 'loss', p6: 'win' }));
check('faction groups', W.warcastleMoveGroupOf('skaven') === 1 && W.warcastleMoveGroupOf('chaos-dwarfs') === 6 && W.warcastleMoveGroupOf(null) === 7);
let man = W.warcastleManoeuvre({ roundNumber: 2, armies, moves: placed, prevPairings: r1, factionOf: id => faction[id] });
check('checklist: winners, draws, losers', man.tiers.map(t => t.tier).join() === 'win,draw,loss');
check('winners by faction group: Orcs, Lizardmen and Ogres before Dwarfs',
  man.tiers[0].groups.map(g => g.label).join('|') === 'Orcs, Lizardmen and Ogres|Dwarfs');
check('draws by faction: Skaven before Humans', man.tiers[1].groups.map(g => g.ids.join()).join('|') === 'p3|p4');
check('waiting: the draws and losers', man.waiting.sort().join() === 'p2,p3,p4,p5');
// the moves: p6 (won) stays, p1 (won) moves 9 -> 13, p3 (drew) stays (flag), p4 (drew) 7 -> 8,
// p2 (lost) stays in 9 (allowed: p1 left), p5 (lost) 13 -> 1 (no crossing: flag)
const r2 = [mv(2, 'p6', 13, 13), mv(2, 'p1', 9, 13), mv(2, 'p3', 7, 7), mv(2, 'p4', 7, 8), mv(2, 'p2', 9, 9), mv(2, 'p5', 13, 1)];
man = W.warcastleManoeuvre({ roundNumber: 2, armies, moves: [...placed, ...r2], prevPairings: r1, factionOf: id => faction[id] });
check('where they are now', JSON.stringify(man.now) === JSON.stringify({ p1: 13, p2: 9, p3: 7, p4: 8, p5: 1, p6: 13 }));
check('flag: a draw staying put', man.flags.some(f => f === 'p3 drew, so has to move.'));
check('no flag: a loser staying when their opponent left', !man.flags.some(f => f.startsWith('p2 lost')));
check('flag: no crossing', man.flags.some(f => f === "p5: there's no crossing from area 13 to area 1."));
check('flag: alone once everyone has moved', man.flags.some(f => f === 'p2 is alone in area 9.') && man.flags.some(f => f === 'p4 is alone in area 8.'));
const lossStays = W.warcastleManoeuvre({ roundNumber: 2, armies, moves: [...placed, mv(2, 'p2', 9, 9)], prevPairings: r1, factionOf: id => faction[id] });
check('flag: a loser staying while their opponent is still there', lossStays.flags.some(f => f.startsWith('p2 lost')));
const crowd = W.warcastleManoeuvre({ roundNumber: 2, armies, moves: [...placed, mv(2, 'p2', 9, 13)], prevPairings: r1 });
check('flag: three in an area', crowd.flags.some(f => f === 'Area 13 has 3 armies.'));

const allies = W.warcastleManoeuvre({ roundNumber: 2, armies, moves: [...placed, ...r2], prevPairings: r1, allegianceOf: id => ({ p1: 'jade', p6: 'jade' })[id] || null });
check('flag: allies in the same area', allies.flags.some(f => f === 'p1 and p6 are allies, both in area 13.' || f === 'p6 and p1 are allies, both in area 13.'));

console.log('Tables from the map');
let tb = W.warcastleTablesFromMap({ roundNumber: 2, armies, moves: [...placed, ...r2], prevPairings: r1 });
const t13 = tb.tables.find(t => t.area === 13);
check('area 13: p1 moved in, so attacks p6', t13.attacker === 'p1' && t13.defender === 'p6' && !t13.rolled);
check('area 13: p1 came from area 9, the west', t13.cameFrom === 'w');
check('area 13: p6 won and stayed, so can ambush', t13.ambushable === true);
check('area 9: p2 alone', tb.tables.find(t => t.area === 9).attacker === null);
// the last one in attacks: both move into 11
const both = [...placed, mv(2, 'p3', 7, 9), mv(2, 'p1', 9, 11), mv(2, 'p4', 7, 2), mv(2, 'p2', 9, 11)];
tb = W.warcastleTablesFromMap({ roundNumber: 2, armies: ['p1', 'p2', 'p3', 'p4'], moves: both, prevPairings: r1 });
const t11 = tb.tables.find(t => t.area === 11);
check('both moved in: the last to arrive attacks', t11.attacker === 'p2' && t11.defender === 'p1' && t11.cameFrom === 'nw');
check('a defender who moved in can\'t ambush', t11.ambushable === false);
tb = W.warcastleTablesFromMap({ roundNumber: 1, armies, moves: placed });
check('round 1: they roll off', tb.tables.every(t => t.rolled && !t.cameFrom));
tb = W.warcastleTablesFromMap({ roundNumber: 2, armies, moves: [...placed, mv(2, 'p2', 9, 13)], prevPairings: r1 });
check('three in an area: left for the organiser', tb.crowded.join() === '13' && !tb.tables.some(t => t.area === 13));

console.log('Deployment');
const same = (p, q) => JSON.stringify(p) === JSON.stringify(q);
const ob = W.DEPLOYMENT_MAPS.find(m => m.key === 'open-battle'), mp = W.DEPLOYMENT_MAPS.find(m => m.key === 'mountain-pass'), db = W.DEPLOYMENT_MAPS.find(m => m.key === 'drawn-battlelines');
check('from the north: Open Battle, attacker on the north edge', same(W.warcastleDeployment('n').attacker, ob.a) && same(W.warcastleDeployment('n').defender, ob.b));
check('from the south: the other way round', same(W.warcastleDeployment('s').attacker, ob.b));
check('from the west: Mountain Pass, attacker on the west edge', same(W.warcastleDeployment('w').attacker, mp.a) && same(W.warcastleDeployment('e').attacker, mp.b));
const top = poly => poly[0].reduce((s, p) => s + p[1], 0) / poly[0].length < 24, east = poly => poly[0].reduce((s, p) => s + p[0], 0) / poly[0].length > 36;
check('from the north-east: Drawn Battlelines, attacker in the north-east', same(W.warcastleDeployment('ne').attacker, db.a) && top(W.warcastleDeployment('ne').attacker) && east(W.warcastleDeployment('ne').attacker));
check('from the north-west: mirrored, attacker in the north-west', top(W.warcastleDeployment('nw').attacker) && !east(W.warcastleDeployment('nw').attacker));
check('from the south-east and south-west: attacker in the south', !top(W.warcastleDeployment('se').attacker) && east(W.warcastleDeployment('se').attacker) && !top(W.warcastleDeployment('sw').attacker) && !east(W.warcastleDeployment('sw').attacker));
const amb = W.warcastleDeployment('e', true);
check('ambush: defender on both long edges, attacker from the east edge', amb.defender.length === 2 && east(amb.attacker) && amb.baggage[0][0] === 67);

console.log(failures ? `\n${failures} failed` : '\nAll passed');
process.exit(failures ? 1 : 0);
