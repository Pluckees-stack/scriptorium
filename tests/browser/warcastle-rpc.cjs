// Stand-ins for migration 101's (and 104's and 111's) functions in the fake database, as source
// for a world's rpcSource. They keep the same rules as the SQL: the price,
// enough tokens, another player in the event.
const WARCASTLE_RPC = `{
  warcastle_grant_tokens(a, db) {
    db.warcastle_tokens ||= [];
    const at = new Date().toISOString();
    [['supply', a.p_supply], ['warpstone', a.p_warpstone]].forEach(([kind, n]) => { if (n) db.warcastle_tokens.push({ id: 'tk' + Math.random().toString(36).slice(2), campaign_id: a.p_campaign, player_id: a.p_player, kind, amount: n, reason: a.p_reason, note: a.p_note, created_at: at }); });
    return { data: null, error: null };
  },
  warcastle_buy_item(a, db) {
    const me = window.__FAKE_SESSION.user.id, bal = (k) => (db.warcastle_tokens || []).filter(t => t.player_id === me && t.kind === k).reduce((n, t) => n + t.amount, 0);
    const p = a.p_points, price = a.p_source === 'faction' ? [0, 1] : p <= 15 ? [1, 0] : p <= 35 ? [2, 0] : p <= 50 ? [3, 0] : p <= 100 ? [3, 1] : null;
    if (!price) return { data: null, error: { message: 'No price for that item: Common items go up to 100 points.' } };
    if (bal('supply') < price[0]) return { data: null, error: { message: 'Not enough Supply: ' + price[0] + ' needed.' } };
    if (bal('warpstone') < price[1]) return { data: null, error: { message: 'Not enough Warpstone: ' + price[1] + ' needed.' } };
    const id = 'it' + Math.random().toString(36).slice(2), at = new Date().toISOString();
    (db.warcastle_items ||= []).push({ id, campaign_id: a.p_campaign, player_id: me, name: a.p_name, points: a.p_points, source: a.p_source, type: a.p_type, unit_id: null, created_at: at });
    [['supply', price[0]], ['warpstone', price[1]]].forEach(([kind, n]) => { if (n) (db.warcastle_tokens ||= []).push({ id: 'tk' + Math.random().toString(36).slice(2), campaign_id: a.p_campaign, player_id: me, kind, amount: -n, reason: 'spent', note: a.p_name, item_id: id, created_at: at }); });
    return { data: id, error: null };
  },
  warcastle_send_tokens(a, db) {
    const me = window.__FAKE_SESSION.user.id, bal = (k) => (db.warcastle_tokens || []).filter(t => t.player_id === me && t.kind === k).reduce((n, t) => n + t.amount, 0);
    if (a.p_to === me) return { data: null, error: { message: 'Pick another player.' } };
    if (bal('supply') < a.p_supply || bal('warpstone') < a.p_warpstone) return { data: null, error: { message: "You don't have that much." } };
    const at = new Date().toISOString();
    [['supply', a.p_supply], ['warpstone', a.p_warpstone]].forEach(([kind, n]) => { if (n) db.warcastle_tokens.push(
      { id: 'tk' + Math.random().toString(36).slice(2), campaign_id: a.p_campaign, player_id: me, kind, amount: -n, reason: 'sent', other_player_id: a.p_to, created_at: at },
      { id: 'tk' + Math.random().toString(36).slice(2), campaign_id: a.p_campaign, player_id: a.p_to, kind, amount: n, reason: 'received', other_player_id: me, created_at: at }); });
    (db.notifications ||= []).push({ id: Date.now(), user_id: a.p_to, campaign_id: a.p_campaign, kind: 'warcastle_tokens', title: 'sent you tokens' });
    return { data: null, error: null };
  },
  // 104: the objectives held; a battle with a result gets its tokens (again)
  warcastle_report_objectives(a, db) {
    const p = (db.tournament_pairings || []).find(x => x.id === a.p_pairing);
    if (!p) return { data: null, error: { message: 'No such battle.' } };
    const rows = (db.warcastle_battle_objectives ||= []), row = { pairing_id: p.id, campaign_id: p.campaign_id, a_held: a.p_a_held, b_held: a.p_b_held, warpstone_by: a.p_warpstone_by || null };
    const i = rows.findIndex(o => o.pairing_id === p.id); if (i >= 0) rows[i] = row; else rows.push(row);
    db.warcastle_tokens = (db.warcastle_tokens || []).filter(t => !(t.pairing_id === p.id && t.reason === 'battle'));
    if (p.result) {
      const at = new Date().toISOString(), add = (player, kind, amount) => amount && db.warcastle_tokens.push({ id: 'tk' + Math.random().toString(36).slice(2), campaign_id: p.campaign_id, player_id: player, kind, amount, reason: 'battle', note: 'Round 1, table ' + p.table_number, pairing_id: p.id, created_at: at });
      add(p.player_a_id, 'supply', row.a_held); add(p.player_b_id, 'supply', row.b_held);
      if ([p.player_a_id, p.player_b_id].includes(row.warpstone_by)) add(row.warpstone_by, 'warpstone', 1);
    }
    return { data: null, error: null };
  },
  // 111: a Chaos or Orc player's tracker, the points worked out as the SQL does
  warcastle_submit_tracker(a, db) {
    const me = window.__FAKE_SESSION.user.id, p = (db.tournament_pairings || []).find(x => x.id === a.p_pairing);
    if (!p) return { data: null, error: { message: 'No such battle.' } };
    if (![p.player_a_id, p.player_b_id].includes(me)) return { data: null, error: { message: "That isn't your battle." } };
    if (!p.result) return { data: null, error: { message: 'The battle needs its result first.' } };
    const side = (db.tournament_entrants || []).find(e => e.player_id === me)?.warcastle_allegiance;
    const track = db.campaigns.find(c => c.id === p.campaign_id)?.settings?.warcastle?.trackers?.kinds?.[side];
    if (!['corruption', 'waaagh'].includes(track)) return { data: null, error: { message: 'Your allegiance has no tracker.' } };
    const it = a.p_items || {}, value = { advisor: 1, lieutenant: 2, bsb: 3, castellan: 4, warlord: 5 };
    const kills = it.kills || [], features = [...new Set(it.features || [])];
    const points = (it.burned || 0) + 2 * (it.monuments || 0) + 2 * (it.big_units || 0)
      + kills.reduce((n, k) => n + (k.by_warlord ? value[k.rank] : Math.ceil(value[k.rank] / 2)), 0)
      + features.reduce((n, f) => n + ({ shard: 100, roots: 75, manor: 50 })[f], 0);
    const favour = track === 'corruption' ? kills.length + features.length + (it.ritual ? 1 : 0) : 0;
    const rows = (db.warcastle_tracker_submissions ||= []), i = rows.findIndex(x => x.pairing_id === p.id && x.player_id === me);
    const row = { id: i >= 0 ? rows[i].id : 'ts' + Math.random().toString(36).slice(2), tournament_id: p.tournament_id, campaign_id: p.campaign_id, round_id: p.round_id, pairing_id: p.id,
      player_id: me, track, items: { burned: it.burned || 0, monuments: it.monuments || 0, big_units: it.big_units || 0, kills, features, ritual: !!it.ritual }, points, favour, updated_at: new Date().toISOString() };
    if (i >= 0) rows[i] = row; else rows.push(row);
    return { data: null, error: null };
  },
  warcastle_tracker_totals(a, db) {
    const out = [];
    (db.warcastle_tracker_submissions || []).filter(x => x.tournament_id === a.p_tournament).forEach(x => {
      const n = db.tournament_rounds.find(r => r.id === x.round_id)?.round_number, t = out.find(y => y.round_number === n && y.track === x.track);
      if (t) t.points += x.points; else out.push({ round_number: n, track: x.track, points: x.points });
    });
    return { data: out, error: null };
  },
}`;
module.exports = { WARCASTLE_RPC };
