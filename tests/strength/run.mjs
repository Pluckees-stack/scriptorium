// Unit Strength and wound pools (index.html's unitStrength, unitMaxWounds,
// unitModelGroups, mountWoundsOf). Run after touching any of them:
//
//   node tests/strength/run.mjs
//
// Same extraction approach as tests/points/run.mjs: pulls the real function
// and const bodies out of index.html by name and evals them. lookupUnitProfile
// is stood in for by a plain lookup over profiles.json, a few real statlines
// (name, W, troop type) copied from the Old World Builder rules index.
// Expected figures are worked out by hand from the Troop Type Table
// (Rulebook p. 105): models in the unit × Unit Strength per model.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const html = readFileSync(path.join(here, '..', '..', 'index.html'), 'utf8');
const scriptSrc = html.match(/<script type="module">([\s\S]*?)<\/script>/)[1];

function extractBlock(marker, endAtSemicolon) {
  const start = scriptSrc.indexOf(marker);
  if (start === -1) throw new Error(`Could not find ${marker} in index.html`);
  let depth = 0, seen = false, i = start;
  for (; i < scriptSrc.length; i++) {
    const c = scriptSrc[i];
    if (c === '{') { depth++; seen = true; }
    else if (c === '}') { depth--; if (seen && depth === 0 && !endAtSemicolon) { i++; break; } }
    else if (c === ';' && seen && depth === 0 && endAtSemicolon) { i++; break; }
  }
  return scriptSrc.slice(start, i);
}
const fn = name => extractBlock('function ' + name + '(', false);

const profiles = JSON.parse(readFileSync(path.join(here, 'profiles.json'), 'utf8'));
const src = [
  'const rulesIndexCache = profiles;',
  'function lookupUnitProfile(name) { return profiles[String(name || "").toLowerCase()] || null; }',
  fn('mountProfileFor'), fn('woundsOf'), fn('mountWoundsOf'),
  extractBlock('const US_PER_MODEL = ', true),
  fn('unitModelGroups'), fn('unitMaxWounds'), fn('unitStrength'),
  'return { unitMaxWounds, unitStrength };',
].join('\n');
const { unitMaxWounds, unitStrength } = new Function('profiles', src)(profiles);

const mounted = (name, mount) => ({ name, size: 1, wargear: { mounts: [{ name_en: mount, active: true }] } });
const cases = [
  // [label, unit, wounds left (undefined = untouched), max wounds, Unit Strength]
  ['20 State Troops', { name: 'State Troops', size: 20 }, undefined, 20, 20],
  ['20 State Troops, 3 lost', { name: 'State Troops', size: 20 }, 17, 20, 17],
  ['5 Empire Knights', { name: 'Empire Knights', size: 5 }, undefined, 5, 10],
  ['5 Empire Knights, 1 lost', { name: 'Empire Knights', size: 5 }, 4, 5, 8],
  ['3 Pegasus Knights', { name: 'Pegasus Knights', size: 3 }, undefined, 6, 9],
  ['3 Pegasus Knights, 1 wound lost', { name: 'Pegasus Knights', size: 3 }, 5, 6, 9],
  ['3 Pegasus Knights, 2 wounds lost', { name: 'Pegasus Knights', size: 3 }, 4, 6, 6],
  ['3 Ogre Bulls', { name: 'Ogre Bulls', size: 3 }, undefined, 9, 9],
  ['3 Ogre Bulls on 8 wounds', { name: 'Ogre Bulls', size: 3 }, 8, 9, 9],
  ['3 Ogre Bulls on 6 wounds', { name: 'Ogre Bulls', size: 3 }, 6, 9, 6],
  ['3 Ogre Bulls on 1 wound', { name: 'Ogre Bulls', size: 3 }, 1, 9, 3],
  ['2 Rat Swarms', { name: 'Rat Swarms', size: 2 }, undefined, 10, 6],
  ['Chaos Chariot', { name: 'Chaos Chariot', size: 1 }, undefined, 4, 5],
  ['Chaos Chariot on 1 wound', { name: 'Chaos Chariot', size: 1 }, 1, 4, 5],
  ['3 Skeleton Chariots, 4 lost', { name: 'Skeleton Chariots', size: 3 }, 5, 9, 6],
  ['Giant', { name: 'Giant', size: 1 }, undefined, 6, 6],
  ['Giant on 2 wounds', { name: 'Giant', size: 1 }, 2, 6, 6],
  ['Giant slain', { name: 'Giant', size: 1 }, 0, 6, 0],
  ['Helblaster', { name: 'Helblaster Volley Gun', size: 1 }, undefined, 3, 3],
  ['General on foot', { name: 'General of the Empire', size: 1 }, undefined, 3, 1],
  ['General on a Barded Warhorse', mounted('General of the Empire', 'Barded Warhorse'), undefined, 3, 2],
  ['General on an Imperial Griffon', mounted('General of the Empire', 'Imperial Griffon'), undefined, 7, 7],
  ['General on an Imperial Griffon, 3 lost', mounted('General of the Empire', 'Imperial Griffon'), 4, 7, 7],
  ['Ishaya Vess', { name: 'Ishaya Vess', size: 1 }, undefined, 3, 1],
  ['20 Clanrats + 1 weapon team', { name: 'Clanrats', size: 20, wargear: { detachments: [{ name: 'Weapon Team', strength: 1 }] } }, undefined, 22, 21],
  ['20 Clanrats + 1 weapon team, 20 lost', { name: 'Clanrats', size: 20, wargear: { detachments: [{ name: 'Weapon Team', strength: 1 }] } }, 2, 22, 1],
  ['Unknown unit', { name: 'Nothing Like It', size: 4 }, undefined, 4, 4],
];

let failed = 0;
for (const [label, u, left, wantMax, wantUs] of cases) {
  const max = unitMaxWounds(u), us = unitStrength(u, left);
  const ok = max === wantMax && us === wantUs;
  if (!ok) failed++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}: wounds ${max} (want ${wantMax}), Unit Strength ${us} (want ${wantUs})`);
}
console.log(failed ? `\n${failed} of ${cases.length} failed` : `\nAll ${cases.length} passed`);
process.exit(failed ? 1 : 0);
