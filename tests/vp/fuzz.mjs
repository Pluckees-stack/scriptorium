// Randomised checks of the Victory points card's scoring (index.html):
// thousands of random scenarios, armies, end-of-battle marks and entries,
// run through the real computeVpTally / setVpEntry / stateFromScore, each
// checked against what must always hold. Run after touching scoring:
//
//   node tests/vp/fuzz.mjs [runs] [seed]
//
// Same extraction as run.mjs: the shipped function bodies, evaluated here.
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const html = readFileSync(path.join(here, '..', '..', 'index.html'), 'utf8');
const src = html.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
function block(start, open) {
  const i = src.indexOf(start);
  if (i < 0) throw new Error('missing ' + start);
  let d = 0, k = src.indexOf(open, i);
  const close = open === '{' ? '}' : ']';
  for (; k < src.length; k++) { if (src[k] === open) d++; else if (src[k] === close && !--d) break; }
  return src.slice(i, k + 1) + ';';
}
const line = (start) => { const i = src.indexOf(start); return src.slice(i, src.indexOf('\n', i)); };
const FNS = ['stackableQtyOf', 'entryCost', 'subOptionsCost', 'selectedItemCost', 'detachmentCost', 'unitTotalPoints', 'unitCommandNames',
  'objectiveVpFor', 'isSyncedGame', 'missionModeOf', 'bmScenarioKeys', 'bankedStrategicVp', 'endOfBattleCtx', 'blankObjectiveState',
  'vpEntriesOf', 'computeVpTally', 'countMax', 'fitBaggage', 'fitDomination', 'setVpEntry', 'scorePartsOf', 'stateFromScore', 'legacyUnitLines', 'withUnitsFollowing', 'stateFromScoreOnly', 'cpRules', 'tournamentBands', 'deriveCampaignResult', 'vpStepFor'];
const code = [
  'let opponentUnitsCache = [], opponentUnitState = {}, ownUnitState = {}, selectedMission = null, manualObjectiveState = {}, opponentManualObjectiveState = {};',
  'let strategicLocationVpTotal = 0, strategicLocationOppVpTotal = 0, activeInviteId = null, isAccepterSession = false, syncedStratFromUser = 0, syncedStratToUser = 0;',
  'let currentFactionId = null, opponentFactionId = null, customObjectivesCache = [], currentCampaignPointTiers = null;',
  'function ownActiveUnits() { return []; }',
  'let wcOn = false, currentTournamentDetail = null;',
  'function isWarcastle() { return wcOn; }',
  'function currentTournamentRules() { return { pointsLimit: 2000 }; }',
  line('const OFFICIAL_TP_BANDS = '),
  'const VP_BOARD = null;',
  block('const DEFAULT_OBJECTIVE_VP = {', '{'), block('const VP_MULTIPLIER = {', '{'), block('const VP_ELEMENTS = [', '['),
  block('const VP_COUNTS = {', '{'), block('const VP_ENTRIES = {', '{'), block('const DEFAULT_CP_TIERS = ', '{'),
  line('const VP_AUTO = {'), line('const otherSide = '), line('const boardTally = '), line('const SCORE_PARTS = '),
  ...FNS.map(n => block(`function ${n}(`, '{')),
  'module.exports = { unitTotalPoints, computeVpTally, setVpEntry, countMax, stateFromScore, deriveCampaignResult, blankObjectiveState, VP_ELEMENTS, objectiveVpFor, scorePartsOf, set: (o) => { if ("customObjectivesCache" in o) customObjectivesCache = o.customObjectivesCache; if ("wc" in o) wcOn = o.wc; } };',
].join('\n\n');
const file = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-fuzz-')), 'h.cjs');
writeFileSync(file, code);
const H = (await import(file)).default;

// a small seeded random, so a failure can be run again
let seed = Number(process.argv[3]) || 1;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const pick = (xs) => xs[Math.floor(rnd() * xs.length)];
const int = (n) => Math.floor(rnd() * n);
const RUNS = Number(process.argv[2]) || 2000;

const COMMON = ['king-is-dead', 'trophies-of-war', 'breaking-the-enemy'];
const SECONDARY = ['special-feature', 'baggage-trains', 'domination', 'strategic-locations'];
const BM = ['treasure-troves', 'strategic-landmark', 'raid-and-burn', 'baggage-carts'];
function randomMission() {
  if (rnd() < .1) return null;
  const bm = rnd() < .2;
  const vp = rnd() < .3 ? { 'domination-quarter': pick([25, 100, 150]), 'baggage-trains-destroyed': pick([150, 250]), 'strategic-locations-per-marker': pick([10, 30, 50]) } : {};
  return {
    mode: bm ? 'battle-march' : 'normal',
    common_objectives: COMMON.filter(() => rnd() < .6),
    secondary_objectives: bm ? [] : SECONDARY.filter(() => rnd() < .5).map(k => k === 'strategic-locations' ? { key: k, count: 1 + int(5) } : { key: k }),
    battle_march: bm ? { objectives: BM.filter(() => rnd() < .5).map(k => ({ key: k })), secondary: [], secret_objectives: rnd() < .5 } : {},
    objective_vp: vp, custom_objective_ids: rnd() < .3 ? ['c1', 'c2'] : [],
  };
}
const customs = [{ id: 'c1', name: 'Hold the bridge', reward_vp: 75, reward_campaign_points: 1 }, { id: 'c2', name: 'Burn the mill', reward_vp: 0, reward_campaign_points: 2, faction_id: 'x' }];
H.set({ customObjectivesCache: customs });
function randomArmy(prefix) {
  return Array.from({ length: 1 + int(10) }, (_, i) => ({ id: `${prefix}${i}`, name: `U${i}`, points: 20 + int(400), size: 1 + int(20),
    wargear: { command: [i === 0 ? { active: true, name_en: 'General' } : i === 1 ? { active: true, name_en: 'Battle Standard Bearer' } : { active: false, name_en: 'x' }] } }));
}
const STATUSES = [null, null, 'dead', 'fled', 'fleeing', 'below25'];
const marks = (army) => Object.fromEntries(army.map(u => [u.id, { status: pick(STATUSES) }]));

const fails = [];
const fail = (run, what, detail) => { if (fails.length < 25) fails.push(`run ${run}: ${what}${detail ? ' — ' + detail : ''}`); };
const FIELDS = [['kingIsDead', 'b'], ['bsb', 'b'], ['breaking', 'b'], ['specialFeature', 'b'], ['baggageDestroyed', 'b'], ['standards', 'n'], ['baggageHeld', 'n'],
  ['domQuarters', 'n'], ['domDouble', 'n'], ['domUncontested', 'n'], ['strategicHeld', 'n'], ['otherVp', 'v'], ['unitsVp', 'v'], ['bm:treasure-troves', 'v']];

for (let run = 1; run <= RUNS; run++) {
  const mission = randomMission();
  const theirs = randomArmy('t'), ours = randomArmy('o');
  const states = { player: H.blankObjectiveState(), opponent: H.blankObjectiveState() };
  const ctx = () => ({ opponentUnits: theirs, opponentState: tMarks, ownUnits: ours, ownState: oMarks, mine: states.player, theirs: states.opponent, mission, banked: false, factions: { player: null, opponent: pick([null, 'x']) } });
  const board = { state: (s) => states[s], ctx, mission: () => mission };
  const tMarks = marks(theirs), oMarks = marks(ours);
  // a random run of entries, as − / +, switches and figures would make them
  for (let k = 0; k < 4 + int(20); k++) {
    const side = pick(['player', 'opponent']), [f, kind] = pick(FIELDS);
    const v = kind === 'b' ? rnd() < .5 : kind === 'n' ? int(8) - 1 : int(600) - 50;
    H.setVpEntry(side, f, v, board);
    if (rnd() < .2) states[side].customAchieved = ['c1', 'c2'].filter(() => rnd() < .5);
  }
  const r = { player: H.computeVpTally('player', ctx()), opponent: H.computeVpTally('opponent', ctx()) };
  const vals = H.objectiveVpFor(mission);
  for (const side of ['player', 'opponent']) {
    const x = r[side], st = states[side], other = states[side === 'player' ? 'opponent' : 'player'];
    const sum = x.breakdown.reduce((n, b) => n + b.vp, 0);
    if (x.vp !== sum) fail(run, `${side}: total isn't its breakdown`, `${x.vp} v ${sum}`);
    if (!Number.isInteger(x.vp) || x.vp < 0) fail(run, `${side}: total not a whole number ≥ 0`, x.vp);
    Object.entries(x.values).forEach(([k, v]) => { if (!Number.isInteger(v) || v < 0) fail(run, `${side}: ${k} is ${v}`); });
    // the rules' limits
    const n = (o, k) => Number(o[k]) || 0;
    if (n(st, 'domDouble') + n(st, 'domUncontested') > n(st, 'domQuarters')) fail(run, `${side}: more Domination bonuses than quarters`, JSON.stringify([st.domQuarters, st.domDouble, st.domUncontested]));
    if (n(st, 'domQuarters') + n(other, 'domQuarters') > 4) fail(run, 'more than four quarters held');
    if (n(st, 'baggageHeld') + n(other, 'baggageHeld') > 2 - (st.baggageDestroyed ? 1 : 0) - (other.baggageDestroyed ? 1 : 0)) fail(run, 'more baggage trains held than are left', JSON.stringify([st.baggageHeld, other.baggageHeld, st.baggageDestroyed, other.baggageDestroyed]));
    const markers = (mission?.secondary_objectives || []).find(o => o.key === 'strategic-locations')?.count || 4;
    if (r.player.stratHeld + r.opponent.stratHeld > markers * 12) fail(run, 'more Strategic Locations held than markers × 12', `${r.player.stratHeld}+${r.opponent.stratHeld} > ${markers * 12}`);
    // nothing outside the scenario worked out on its own
    const set = (f) => st[f] != null && st[f] !== false && st[f] !== 0;
    if (!x.inScenario('king-is-dead') && x.values['king-is-dead'] && !set('kingIsDead')) fail(run, `${side}: King is Dead scored outside the scenario`);
    if (!x.inScenario('breaking-the-enemy') && x.values['breaking-the-enemy'] && !set('breaking')) fail(run, `${side}: Breaking the Enemy scored outside the scenario`);
    // each element by the rule's own amounts
    const dom = n(st, 'domQuarters') * vals['domination-quarter'] + n(st, 'domDouble') * vals['domination-double-strength'] + n(st, 'domUncontested') * vals['domination-uncontested'];
    if (x.values.domination !== dom) fail(run, `${side}: Domination ${x.values.domination}, want ${dom}`);
    const bag = n(st, 'baggageHeld') * vals['baggage-trains-controlled'] + (st.baggageDestroyed ? vals['baggage-trains-destroyed'] : 0);
    if (x.values['baggage-trains'] !== bag) fail(run, `${side}: Baggage Trains ${x.values['baggage-trains']}, want ${bag}`);
    // units: full, or half rounded up, as each unit ended
    if (st.unitsVp == null) {
      const army = side === 'player' ? theirs : ours, m = side === 'player' ? tMarks : oMarks;
      const want = army.reduce((t, u) => t + Math.ceil(u.points * u.size * ({ dead: 1, fled: 1, fleeing: .5, below25: .5 }[m[u.id].status] || 0)), 0);
      if (x.values.units !== want) fail(run, `${side}: units ${x.values.units}, want ${want}`);
    }
  }
  // a battle saved with its breakdown opens as it was entered: same total, same elements
  const saved = { battle_a_parts: r.player.breakdown, battle_b_parts: r.opponent.breakdown, vp_a: r.player.vp, vp_b: r.opponent.vp };
  const factions = ctx().factions;
  const back = { player: H.stateFromScore(saved, 'a', mission, factions), opponent: H.stateFromScore(saved, 'b', mission, factions) };
  const plain = { opponentUnits: [], opponentState: {}, ownUnits: [], ownState: {}, mine: back.player, theirs: back.opponent, mission, banked: false, factions };
  for (const side of ['player', 'opponent']) {
    const again = H.computeVpTally(side, plain), was = r[side];
    if (again.vp !== was.vp) fail(run, `${side}: reopened at ${again.vp}, saved at ${was.vp}`, JSON.stringify(was.breakdown.map(b => [b.key, b.vp])));
    const diff = Object.keys(was.values).filter(k => was.values[k] !== again.values[k]);
    if (diff.length) fail(run, `${side}: reopened with different ${diff.join(', ')}`, diff.map(k => `${was.values[k]}→${again.values[k]}`).join(' '));
    // every unit of the army it scored against, as it ended
    const army = side === 'player' ? theirs : ours, m = side === 'player' ? tMarks : oMarks, list = back[side].units;
    if (!Array.isArray(list) || list.length !== army.length) fail(run, `${side}: reopened without its army`, `${list?.length} of ${army.length}`);
    else army.forEach(u => {
      const kept = list.find(x => x.id === u.id);
      if (!kept || kept.status !== (m[u.id].status || null)) fail(run, `${side}: ${u.id} reopened ${kept ? kept.status : 'missing'}, ended ${m[u.id].status}`);
      else if (kept.points !== H.unitTotalPoints(u)) fail(run, `${side}: ${u.id} kept at ${kept.points} points, is ${H.unitTotalPoints(u)}`);
    });
  }
  // the organiser re-marks a unit on the reopened battle: the units' VP
  // follows (unless set by hand), and it saves and reopens as re-marked
  for (const side of ['player', 'opponent']) {
    const st = back[side];
    if (!st.units?.length || st.unitsVp != null) continue;
    const u = pick(st.units), to = pick(STATUSES);
    u.status = to;
    const r2 = H.computeVpTally(side, plain);
    const want = st.units.reduce((t, x) => t + Math.ceil(x.points * ({ dead: 1, fled: 1, fleeing: .5, below25: .5 }[x.status] || 0)), 0);
    if (r2.values.units !== want) fail(run, `${side}: re-marked units ${r2.values.units}, want ${want}`);
    const resaved = { [`battle_${side === 'player' ? 'a' : 'b'}_parts`]: r2.breakdown, [`vp_${side === 'player' ? 'a' : 'b'}`]: r2.vp };
    const again = H.stateFromScore(resaved, side === 'player' ? 'a' : 'b', mission, factions);
    if (again.units?.find(x => x.id === u.id)?.status !== (to || null)) fail(run, `${side}: re-marked unit reopened ${again.units?.find(x => x.id === u.id)?.status}, set ${to}`);
    if (H.computeVpTally(side, { ...plain, mine: again, theirs: again }).vp !== r2.vp) fail(run, `${side}: re-marked battle reopened at a different total`);
  }
  // a battle from before entries were kept (just each element's VP) still opens at its total
  const old = (b) => b.map(({ key, label, vp }) => ({ key, label, vp }));
  const legacy = { battle_a_parts: old(r.player.breakdown), battle_b_parts: old(r.opponent.breakdown), vp_a: r.player.vp, vp_b: r.opponent.vp };
  const lp = H.stateFromScore(legacy, 'a', mission, factions), lo = H.stateFromScore(legacy, 'b', mission, factions);
  const lctx = { ...plain, mine: lp, theirs: lo };
  if (H.computeVpTally('player', lctx).vp !== r.player.vp) fail(run, 'an older battle reopened at a different total', `${H.computeVpTally('player', lctx).vp} v ${r.player.vp}`);
  if (H.computeVpTally('opponent', lctx).vp !== r.opponent.vp) fail(run, 'an older battle (opponent) reopened at a different total');
  // the result: one side's win is the other's loss (a campaign's rules, and WarCastle's matched play table)
  [false, true].forEach(wc => {
    H.set({ wc });
    const d = H.deriveCampaignResult(r.player.vp, r.opponent.vp), e = H.deriveCampaignResult(r.opponent.vp, r.player.vp), how = wc ? ' (WarCastle)' : '';
    if ({ win: 'loss', loss: 'win', draw: 'draw' }[d.result] !== e.result || d.campaignPoints !== e.opponentCampaignPoints) fail(run, 'result not the same from both sides' + how, `${r.player.vp}–${r.opponent.vp}`);
    if ((d.result === 'win') !== (r.player.vp > r.opponent.vp && d.result !== 'draw')) { if (d.result === 'win' && r.player.vp <= r.opponent.vp) fail(run, 'a win on fewer VP' + how); }
  });
  H.set({ wc: false });
}
console.log(fails.length ? `FAIL\n  ${fails.join('\n  ')}` : `${RUNS} random battles: every check held.`);
process.exit(fails.length ? 1 : 0);
