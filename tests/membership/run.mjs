// Regression test for the Membership roster browser's rendering logic
// (index.html's membershipRosterSummaryHtml and the wargearSectionHtml chain
// it reuses). Run manually after touching any of that code:
//
//   node tests/membership/run.mjs
//
// Same extraction approach as tests/vp/run.mjs (see that file for why): pulls
// the real function/const bodies out of index.html by name and evals them,
// so this exercises the actual shipped code. The wizard-lore branch of
// wargearSectionHtml depends on network-loaded spell data
// (loadLoresWithSpells()), which this harness doesn't fetch — so fixtures
// here deliberately use non-wizard units and the lore/spell helpers are
// stubbed as no-ops rather than extracted for real.

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
    else if (c === ';' && !seenBrace) { i++; break; } // one-line const (e.g. esc)
  }
  return scriptSrc.slice(start, i);
}

const CONST_NAMES = ['esc', 'CATEGORY_ORDER', 'FACTION_ACCENTS', 'FACTION_EXCLUSIVE_LORES'];
const FN_NAMES = [
  'unitDisplayName', 'stackableQtyOf', 'entryCost', 'subOptionsCost', 'selectedItemCost', 'detachmentCost',
  'collectWargearEntries', 'wargearPartHtml', 'veteranAbilitiesHtml', 'spellSectionHtml', 'wargearSectionHtml',
  'membershipRosterSummaryHtml',
];

const harnessSrc = [
  'let rulesIndexCache = null;', // wargearPartHtml's rule-link lookup is skipped when falsy — no network needed
  // Only the wizard-lore branch of wargearSectionHtml touches these — stubbed
  // rather than extracted since the real ones need loadLoresWithSpells() data.
  'function knownSpellsForUnit() { return []; }',
  'function spellsForLore() { return []; }',
  'function getSelectedSpellSlugs() { return new Set(); }',
  'function spellRowHtml() { return ""; }',
  ...CONST_NAMES.map(extractConst),
  ...FN_NAMES.map(extractFn),
  'module.exports = { membershipRosterSummaryHtml };',
].join('\n\n');

const harnessPath = path.join(mkdtempSync(path.join(tmpdir(), 'scriptorium-membership-')), 'harness.cjs');
writeFileSync(harnessPath, harnessSrc);
const { membershipRosterSummaryHtml } = await import(harnessPath);

let failed = 0;
function check(label, cond, detail) {
  const ok = !!cond;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}` + (ok ? '' : `\n       ${detail || ''}`));
}

// --- no roster at all ---
{
  const html = membershipRosterSummaryHtml([]);
  check('empty roster list shows a fallback message', /hasn't imported/.test(html), html);
}

// --- a small roster: one character with equipment + a magic item, one core unit ---
{
  const rosters = [{
    id: 'r1', name: 'Grudgebearers', faction_id: 'dwarfen-mountain-holds',
    units: [
      {
        id: 'u1', name: 'Dwarf Lord', nickname: null, category: 'characters', size: 1,
        wargear: {
          equipment: [{ name: 'Great weapon', active: true, points: 6 }],
          armor: [{ name: 'Rune armour', active: true, points: 30 }],
          items: [{ selected: [{ name: 'Master Rune of Grudges', points: 50 }] }],
        },
      },
      {
        id: 'u2', name: 'Dwarf Warriors', nickname: 'The Ninth', category: 'core', size: 20,
        wargear: { equipment: [{ name: 'Shields', active: true, perModel: true, points: 1 }] },
      },
    ],
  }];

  const html = membershipRosterSummaryHtml(rosters);
  check('roster name heading present', html.includes('Grudgebearers'), html.slice(0, 300));
  check('faction label resolved from FACTION_ACCENTS or falls back to id', html.includes('Dwarfen') || html.includes('dwarfen-mountain-holds'));
  check('characters category section present', /characters/.test(html));
  check('core category section present', /core/.test(html));
  check('unit display name with nickname shown', html.includes('The Ninth (Dwarf Warriors)'), html.slice(0, 600));
  check('equipped weapon listed', html.includes('Great weapon'));
  check('equipped armour listed', html.includes('Rune armour'));
  check('magic item listed under its own block', html.includes('Master Rune of Grudges') && html.includes('Magic items'));
  check('per-model equipment (shields) listed for the core unit', html.includes('Shields'));
  check('categories rendered in CATEGORY_ORDER (characters before core)', html.indexOf('Dwarf Lord') < html.indexOf('Dwarf Warriors'));
}

// --- two rosters (e.g. a player who's re-imported into a new list) render both, separated ---
{
  const rosters = [
    { id: 'r1', name: 'List A', faction_id: 'empire-of-man', units: [{ id: 'u1', name: 'Knight', category: 'core', size: 5, wargear: {} }] },
    { id: 'r2', name: 'List B', faction_id: 'empire-of-man', units: [{ id: 'u2', name: 'Handgunners', category: 'core', size: 10, wargear: {} }] },
  ];
  const html = membershipRosterSummaryHtml(rosters);
  check('both roster names present', html.includes('List A') && html.includes('List B'));
  check('rosters separated by a divider', html.includes('<hr'));
}

console.log(`\n${failed === 0 ? 'All checks passed.' : failed + ' check(s) failed.'}`);
process.exit(failed ? 1 : 0);
