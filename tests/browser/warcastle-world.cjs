// A WarCastle test world for fake-supabase.mjs: an organiser (g), 26 players
// (p01..p26) two to a table, round 1 active, completed or a draft.
const FACTIONS = ['high-elf-realms','wood-elf-realms','dark-elves','skaven','warriors-of-chaos','daemons-of-chaos','beastmen-brayherds','empire-of-man','kingdom-of-bretonnia','grand-cathay','renegade-crowns','orc-and-goblin-tribes','lizardmen','ogre-kingdoms','vampire-counts','tomb-kings-of-khemri','dwarfen-mountain-holds','chaos-dwarfs','high-elf-realms','skaven','warriors-of-chaos','empire-of-man','orc-and-goblin-tribes','vampire-counts','dwarfen-mountain-holds','wood-elf-realms'];
function world({ me = 'g', round = 'active', withMoves = false } = {}) {
  const now = new Date().toISOString();
  const pid = i => `p${String(i).padStart(2, '0')}`;
  const players = [{ id: 'g', display_name: 'Grant', platform_role: 'admin', theme: null }];
  for (let i = 1; i <= 26; i++) players.push({ id: pid(i), display_name: `wc-test-${String(i).padStart(2, '0')}`, platform_role: null });
  const members = [{ user_id: 'g', campaign_id: 'c1', role: 'organiser', faction_id: null, onboarded: true }];
  for (let i = 1; i <= 26; i++) members.push({ user_id: pid(i), campaign_id: 'c1', role: 'player', faction_id: FACTIONS[i - 1], onboarded: true });
  const missions = Array.from({ length: 13 }, (_, i) => ({ id: `m${i + 1}`, campaign_id: 'c1', name: `Table ${i + 1} set-up`, mode: 'normal', common_objectives: [], secondary_objectives: [], game_sizes: ['2000-2499'] }));
  const rounds = [1, 2, 3, 4, 5, 6].map(n => ({ id: `r${n}`, tournament_id: 't1', campaign_id: 'c1', round_number: n, status: n === 1 ? round : 'draft', per_table_scenarios: true, mission_id: null, activated_at: n === 1 && round !== 'draft' ? now : null }));
  const pairings = Array.from({ length: 13 }, (_, i) => ({ id: `pr${i + 1}`, round_id: 'r1', tournament_id: 't1', campaign_id: 'c1', player_a_id: pid(i * 2 + 1), player_b_id: pid(i * 2 + 2), table_number: i + 1, mission_id: `m${i + 1}`, result: round === 'completed' ? (i % 3 === 0 ? 'draw' : 'a_win') : null }));
  return {
    session: { access_token: 'x', user: { id: me, email: me === 'g' ? 'grant@example.com' : `${me}@example.com`, user_metadata: {} } },
    db: {
      players, campaign_members: members,
      campaigns: [{ id: 'c1', name: 'WarCastle', format: 'tournament', status: 'active', join_code: 'WAR-1', settings: { template: 'warcastle', warcastle: { tables: Object.fromEntries(missions.map((m, i) => [i + 1, m.id])) } }, created_by: 'g', narrative_enabled: false, path_to_glory_enabled: false, campaign_point_tiers: [], player_cap: 26 }],
      factions: FACTIONS.filter((f, i, a) => a.indexOf(f) === i).map(id => ({ id, name: id })),
      tournaments: [{ id: 't1', campaign_id: 'c1', name: 'WarCastle', format: 'swiss', status: round === 'draft' ? 'active' : 'active', rounds_planned: 6, current_round: 1, entrants_locked_at: now, round_scenarios: [], points_limit: 2000, round_minutes: 180, created_at: now }],
      tournament_entrants: players.filter(p => p.id !== 'g').map(p => ({ id: 'e' + p.id, tournament_id: 't1', campaign_id: 'c1', player_id: p.id, status: 'active', seed: null, score_adjust: 0, vp_adjust: 0 })),
      tournament_rounds: rounds, tournament_pairings: pairings, missions,
      warcastle_moves: withMoves ? Array.from({ length: 26 }, (_, i) => ({ id: 'mv' + i, tournament_id: 't1', campaign_id: 'c1', round_number: 1, player_id: pid(i + 1), from_area: null, to_area: Math.floor(i / 2) + 1, seq: i + 1 })) : [],
      rosters: [], units: [], games: [], announcements: [], notifications: [],
    },
  };
}
module.exports = { world };
