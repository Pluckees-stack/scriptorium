// Checks for the campaign builder's helpers (migration 088): join code
// suggestions, phase dates as players read them, spreading phases across a
// campaign, templates, the campaign points example and the Overview's setup
// checklist. Run after touching any of that code:
//
//   node tests/builder/run.mjs
//
// Same extraction approach as tests/vp/run.mjs: the real function and const
// bodies are pulled out of index.html by name and evaluated, so this tests
// the shipped code.

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
  let depth = 0, i = scriptSrc.indexOf('{', scriptSrc.indexOf(')', start));
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
  let depth = 0, i = start;
  for (; i < scriptSrc.length; i++) {
    const c = scriptSrc[i];
    if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') depth--;
    else if (c === ';' && depth === 0) { i++; break; }
  }
  return scriptSrc.slice(start, i);
}

const CONST_NAMES = ['DEFAULT_CP_TIERS', 'FACTION_ACCENTS', 'DAY_NAMES', 'MONTH_SHORT', 'JOIN_CODE_ALPHABET', 'CAMPAIGN_TEMPLATES'];
const FN_NAMES = ['isoDay', 'addDaysIso', 'formatDayDate', 'phaseDatesLine', 'phaseDateRange', 'spreadPhaseDates',
  'suggestJoinCode', 'applyCampaignTemplate', 'cpExampleLine', 'setupChecklistItems'];

const harnessSrc = [
  ...CONST_NAMES.map(extractConst),
  ...FN_NAMES.map(extractFn),
  `module.exports = { ${FN_NAMES.join(', ')}, CAMPAIGN_TEMPLATES };`,
].join('\n\n');

const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-builder-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const h = await import(harnessPath);

let failed = 0;
function check(label, cond, detail) {
  const ok = !!cond;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}` + (ok ? '' : `\n       ${detail ?? ''}`));
}
const eq = (label, got, want) => check(label, JSON.stringify(got) === JSON.stringify(want), `got ${JSON.stringify(got)}, wanted ${JSON.stringify(want)}`);

// --- join codes ---
{
  const seq = (...xs) => { let i = 0; return () => xs[i++ % xs.length]; };
  eq('code takes the first real word of the name', h.suggestJoinCode('The Season of Skulls', seq(0)), 'SEASON-2222');
  eq('short and filler words are skipped', h.suggestJoinCode('A big day out', seq(0)), 'BIG-2222');
  eq('no usable word falls back to CAMP', h.suggestJoinCode('!!', seq(0.999)), 'CAMP-ZZZZ');
  let clean = true;
  for (let n = 0; n < 300; n++) {
    const code = h.suggestJoinCode('Middenheim');
    if (!/^MIDDEN-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{4}$/.test(code)) { clean = false; console.log('       bad code', code); break; }
  }
  check('random part never uses 0, O, 1, I or L', clean);
}

// --- dates ---
{
  const today = '2026-10-18';
  eq('a date reads as day, date and short month', h.formatDayDate('2026-11-09', today), 'Monday 9 Nov');
  eq('another year shows the year', h.formatDayDate('2027-01-24', today), 'Sunday 24 Jan 2027');
  eq('no date, no text', h.formatDayDate('', today), '');
  eq('active phase: when it ends', h.phaseDatesLine({ name: 'Phase 2', status: 'active', ends_on: '2026-11-08' }, today), 'Phase 2 ends Sunday 8 Nov');
  eq('active phase ending today', h.phaseDatesLine({ name: 'Phase 2', status: 'active', ends_on: today }, today), 'Phase 2 ends today');
  eq('active phase past its end', h.phaseDatesLine({ name: 'Phase 2', status: 'active', ends_on: '2026-10-11' }, today), 'Phase 2 was due to end Sunday 11 Oct');
  eq('phase to come: when it starts', h.phaseDatesLine({ name: 'Phase 3', status: 'draft', starts_on: '2026-11-09' }, today), 'Phase 3 starts Monday 9 Nov');
  eq('completed phase says nothing', h.phaseDatesLine({ name: 'Phase 1', status: 'completed', ends_on: '2026-10-01' }, today), '');
  eq('range with both dates', h.phaseDateRange({ starts_on: '2026-11-02', ends_on: '2026-11-29' }, today), 'Monday 2 Nov to Sunday 29 Nov');
  eq('range with a start only', h.phaseDateRange({ starts_on: '2026-11-02' }, today), 'From Monday 2 Nov');
  eq('spread: three phases over twelve weeks', h.spreadPhaseDates(3, '2026-11-02', '2027-01-24'), [
    { starts_on: '2026-11-02', ends_on: '2026-11-29' }, { starts_on: '2026-11-30', ends_on: '2026-12-27' }, { starts_on: '2026-12-28', ends_on: '2027-01-24' }]);
  eq('spread: more phases than days still gives each a day', h.spreadPhaseDates(3, '2026-11-02', '2026-11-03').map(x => x.starts_on <= x.ends_on), [true, true, true]);
  eq('spread: nothing without both dates', h.spreadPhaseDates(3, '2026-11-02', ''), []);
  eq('spread: across the clocks going back (25 October)', h.spreadPhaseDates(2, '2026-10-19', '2026-11-01'), [
    { starts_on: '2026-10-19', ends_on: '2026-10-25' }, { starts_on: '2026-10-26', ends_on: '2026-11-01' }]);
}

// --- templates ---
{
  const keys = h.CAMPAIGN_TEMPLATES.map(t => t.key);
  eq('the three types of event', keys, ['narrative', 'league', 'tournament']);
  check('each type says who it suits', h.CAMPAIGN_TEMPLATES.every(t => /^Great for /.test(t.greatFor || '')), JSON.stringify(h.CAMPAIGN_TEMPLATES.map(t => t.greatFor)));
  const n = h.applyCampaignTemplate('narrative', { startsOn: '2026-11-02', missionIds: ['a', 'b', 'c', 'd', 'e'] });
  eq('slow grow: twelve weeks from the start', n.ends_on, '2027-01-24');
  eq('slow grow: three phases with dates', n.phases.map(p => [p.starts_on, p.ends_on]), [['2026-11-02', '2026-11-29'], ['2026-11-30', '2026-12-27'], ['2026-12-28', '2027-01-24']]);
  eq('slow grow: scenarios taken in turn', n.phases.map(p => p.mission_ids), [['a', 'b', 'c'], ['d', 'e', 'a'], ['b', 'c', 'd']]);
  check('slow grow: alliances coloured from faction themes', n.alliances.length === 3 && n.alliances.every(a => /^#[0-9a-f]{6}$/i.test(a.colour)), JSON.stringify(n.alliances));
  check('slow grow: Path to Glory on', n.path_to_glory_enabled === true && n.format === 'narrative');
  const t = h.applyCampaignTemplate('tournament', { startsOn: '2026-12-05' });
  eq('one-day tournament: ends the day it starts', t.ends_on, '2026-12-05');
  eq('one-day tournament: Swiss, 3 rounds, 2000 points, 16 players', [t.format, t.tournament.format, t.tournament.rounds_planned, t.tournament.points_limit, t.player_cap], ['tournament', 'swiss', 3, 2000, 16]);
  eq('one-day tournament: no phases or alliances', [t.phases.length, t.alliances.length], [0, 0]);
  eq('alliances on for slow grow, off for a league and a tournament', [n.alliances_enabled, h.applyCampaignTemplate('league').alliances_enabled, t.alliances_enabled], [true, false, false]);
  const l = h.applyCampaignTemplate('league', { missionIds: [] });
  eq('league with an empty library: a phase with no scenarios', l.phases.map(p => p.mission_ids.length), [0]);
  const kept = h.applyCampaignTemplate('league', { startsOn: '2026-11-02', endsOn: '2026-12-31' });
  eq('an end date already chosen is kept', kept.ends_on, '2026-12-31');
}

// --- campaign points example ---
{
  const T = { crushing: { margin: 1000, cp: 5 }, major: { margin: 500, cp: 4 }, minor: { margin: 200, cp: 3 }, draw: { cp: 2 }, defeat: { cp: 1 } };
  eq('600 VP is a Major Victory by default', h.cpExampleLine(T), 'Win by 600 VP = 4 campaign points (Major Victory). Your opponent gets 1 campaign point.');
  eq('below the Minor margin it is a draw', h.cpExampleLine({ ...T, minor: { margin: 700, cp: 3 }, major: { margin: 800, cp: 4 }, crushing: { margin: 900, cp: 5 } }), 'Win by 600 VP and it counts as a draw: 2 campaign points each.');
}

// --- setup checklist ---
{
  const keysOf = (items) => items.map(i => i.key);
  const draft = h.setupChecklistItems({ format: 'narrative', status: 'draft', name: 'X', alliances: 0, datesSupported: true, phases: [], players: 0, inviteShared: false, nights: 0, tournaments: 0 });
  eq('narrative checklist items', keysOf(draft), ['basics', 'alliances', 'phases', 'scenarios', 'open', 'invite', 'night', 'started']);
  check('a new draft has everything to do', draft.every(i => !i.done), JSON.stringify(draft.map(i => [i.key, i.done])));
  check('each item says where to fix it', draft.every(i => i.fix && i.fix.label && (i.fix.tab || i.fix.builder)));
  const live = h.setupChecklistItems({
    format: 'narrative', status: 'active', name: 'Season of Skulls', startsOn: '2026-09-01', endsOn: '2026-11-30', alliances: 3, datesSupported: true,
    phases: [{ status: 'completed', starts_on: '2026-09-01', ends_on: '2026-09-30', scenarios: 3 }, { status: 'active', starts_on: '2026-10-01', ends_on: '2026-10-31', scenarios: 2 }],
    players: 40, inviteShared: false, nights: 4, tournaments: 0,
  });
  check('a campaign that is under way is complete', live.every(i => i.done), JSON.stringify(live.filter(i => !i.done)));
  const undated = h.setupChecklistItems({ format: 'narrative', status: 'active', name: 'X', alliances: 2, datesSupported: true, phases: [{ status: 'active', scenarios: 1 }, { status: 'draft', starts_on: '2026-11-01', ends_on: '2026-11-30', scenarios: 0 }], players: 1, nights: null });
  const by = Object.fromEntries(undated.map(i => [i.key, i]));
  check('a phase without dates needs attention', !by.phases.done && /1 of 2 phases without dates/.test(by.phases.hint), by.phases.hint);
  check('a phase without scenarios needs attention', !by.scenarios.done && /1 phase without scenarios/.test(by.scenarios.hint), by.scenarios.hint);
  check('game nights left out when they can\'t be read', !('night' in by));
  const before088 = h.setupChecklistItems({ format: 'narrative', status: 'active', name: 'X', alliances: 2, datesSupported: false, phases: [{ status: 'active', scenarios: 1 }], players: 3, nights: 1 });
  check('before 088, phases count as dated', before088.find(i => i.key === 'phases').done);
  const tourney = h.setupChecklistItems({ format: 'tournament', status: 'active', name: 'GT', alliances: 0, datesSupported: true, phases: [], players: 0, inviteShared: true, nights: 1, tournaments: 1 });
  eq('tournament checklist items', keysOf(tourney), ['basics', 'tournament', 'open', 'invite', 'night']);
  check('a copied link counts as shared', tourney.find(i => i.key === 'invite').done);
}

console.log(failed ? `\n${failed} check(s) failed.` : '\nAll checks passed.');
process.exit(failed ? 1 : 0);
