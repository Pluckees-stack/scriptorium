// Regression test for the tournament pairing engines (index.html's
// generateSwissPairings, generateRoundRobinSchedule, generateEliminationBracket
// + generateNextEliminationRound, standardBracketOrder). Run manually after
// touching any of that code:
//
//   node tests/tournaments/run.mjs
//
// Same extraction approach as tests/vp/run.mjs (see that file for why): pulls
// the real function bodies out of index.html by name and evals them, so this
// exercises the actual shipped code rather than a hand-copy that could drift
// out of sync. These are pure functions (entrant/pairing plain objects in,
// plain objects out) so assertions are inline here rather than fixture JSON.

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

const FN_NAMES = [
  'shuffledCopy', 'tournamentEntrantScore', 'tournamentHavePlayed', 'tournamentByeCount',
  'generateSwissPairings', 'generateRoundRobinSchedule', 'nextPowerOfTwo', 'standardBracketOrder',
  'generateEliminationBracket', 'generateNextEliminationRound', 'computeTournamentStandings',
];

const harnessSrc = [
  ...FN_NAMES.map(extractFn),
  `module.exports = { ${FN_NAMES.join(', ')} };`,
].join('\n\n');

const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-tournaments-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const fns = await import(harnessPath);
const {
  generateSwissPairings, generateRoundRobinSchedule, standardBracketOrder,
  generateEliminationBracket, generateNextEliminationRound, computeTournamentStandings,
} = fns;

function entrants(n) {
  return Array.from({ length: n }, (_, i) => ({ id: `p${i + 1}`, seed: i + 1 }));
}

function allPlayerIds(pairings) {
  const ids = [];
  pairings.forEach(p => { ids.push(p.player_a_id); if (p.player_b_id) ids.push(p.player_b_id); });
  return ids;
}

function pairKey(a, b) { return [a, b].sort().join('|'); }

let failed = 0;
function check(label, cond, detail) {
  const ok = !!cond;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}` + (ok ? '' : `\n       ${detail || ''}`));
}

// --- Swiss: every entrant appears exactly once per round, odd count gets exactly one bye ---
for (const n of [3, 4, 5, 8]) {
  const round1 = generateSwissPairings(entrants(n), []);
  const ids = allPlayerIds(round1);
  const uniqueIds = new Set(ids);
  check(`swiss round 1 (n=${n}): every entrant appears exactly once`, ids.length === n && uniqueIds.size === n,
    `got ${ids.length} slots, ${uniqueIds.size} unique`);
  const byes = round1.filter(p => p.player_b_id === null).length;
  check(`swiss round 1 (n=${n}): bye count matches parity`, byes === (n % 2));

  // round 2 shouldn't rematch anyone when an alternative existed (n>=4, even)
  if (n >= 4) {
    const priorPairings = round1.map(p => ({ ...p, result: p.player_b_id ? 'a_win' : null }));
    const round2 = generateSwissPairings(entrants(n), priorPairings);
    const rematches = round2.filter(p => p.player_b_id &&
      priorPairings.some(pp => pairKey(pp.player_a_id, pp.player_b_id) === pairKey(p.player_a_id, p.player_b_id)));
    check(`swiss round 2 (n=${n}): avoids rematches where possible`, rematches.length === 0,
      `${rematches.length} rematch(es) found`);
  }
}

// --- Round robin: every pair meets exactly once, every round is a full matching ---
for (const n of [4, 5, 6]) {
  const rounds = generateRoundRobinSchedule(entrants(n));
  const expectedRounds = n % 2 === 0 ? n - 1 : n;
  check(`round robin (n=${n}): correct round count`, rounds.length === expectedRounds,
    `expected ${expectedRounds}, got ${rounds.length}`);

  const seenPairs = new Set();
  let duplicates = 0;
  rounds.forEach(round => {
    const idsThisRound = allPlayerIds(round);
    if (new Set(idsThisRound).size !== idsThisRound.length) duplicates++; // someone playing twice in one round
    round.forEach(p => {
      if (!p.player_b_id) return;
      const key = pairKey(p.player_a_id, p.player_b_id);
      if (seenPairs.has(key)) duplicates++;
      seenPairs.add(key);
    });
  });
  const expectedPairs = n * (n - 1) / 2;
  check(`round robin (n=${n}): every pair meets exactly once, nobody double-booked in a round`,
    duplicates === 0 && seenPairs.size === expectedPairs,
    `${duplicates} problem(s), ${seenPairs.size}/${expectedPairs} unique pairs`);
}

// --- Single elimination: standard seeding order, correct bracket size/byes, round advancement ---
check('standardBracketOrder(4) matches conventional 1v4/2v3 seeding', JSON.stringify(standardBracketOrder(4)) === JSON.stringify([1, 4, 2, 3]));
check('standardBracketOrder(8) matches conventional 1v8/4v5/2v7/3v6 seeding', JSON.stringify(standardBracketOrder(8)) === JSON.stringify([1, 8, 4, 5, 2, 7, 3, 6]));

for (const n of [5, 6, 8]) {
  const round1 = generateEliminationBracket(entrants(n));
  const bracketSize = Math.pow(2, Math.ceil(Math.log2(n)));
  check(`single elim (n=${n}): round 1 has bracketSize/2 pairings`, round1.length === bracketSize / 2,
    `expected ${bracketSize / 2}, got ${round1.length}`);
  const byes = round1.filter(p => p.player_b_id === null).length;
  check(`single elim (n=${n}): byes fill the gap to bracket size`, byes === bracketSize - n,
    `expected ${bracketSize - n} byes, got ${byes}`);
  const ids = allPlayerIds(round1);
  check(`single elim (n=${n}): every entrant appears exactly once`, ids.length === n && new Set(ids).size === n);
}

// generateNextEliminationRound: byes auto-advance, winners paired in bracket order, throws if unreported
{
  const round1 = generateEliminationBracket(entrants(5)); // bracketSize 8, 3 byes
  const reported = round1.map(p => ({ ...p, result: p.player_b_id ? 'a_win' : null }));
  const round2 = generateNextEliminationRound(reported);
  check('elimination round 2: half the entrants advance', round2.length === reported.length / 2,
    `expected ${reported.length / 2}, got ${round2.length}`);

  const unreported = round1.map(p => ({ ...p, result: null }));
  let threw = false;
  try { generateNextEliminationRound(unreported); } catch { threw = true; }
  check('elimination round 2: throws when a pairing is unreported', threw);
}

// --- standings: wins/draws/byes score correctly and sort descending ---
{
  const ents = entrants(4);
  const pairings = [
    { player_a_id: 'p1', player_b_id: 'p2', result: 'a_win' },
    { player_a_id: 'p3', player_b_id: 'p4', result: 'draw' },
    { player_a_id: 'p1', player_b_id: null, result: null }, // bye
  ];
  const standings = computeTournamentStandings(ents, pairings);
  const byId = Object.fromEntries(standings.map(r => [r.player_id, r]));
  check('standings: p1 has 1 win + 1 bye = score 2', byId.p1.score === 2, JSON.stringify(byId.p1));
  check('standings: p2 has 1 loss = score 0', byId.p2.score === 0, JSON.stringify(byId.p2));
  check('standings: p3/p4 have 1 draw each = score 0.5', byId.p3.score === 0.5 && byId.p4.score === 0.5);
  check('standings: sorted descending by score', standings[0].player_id === 'p1');
}

console.log(`\n${failed === 0 ? 'All checks passed.' : failed + ' check(s) failed.'}`);
process.exit(failed ? 1 : 0);
