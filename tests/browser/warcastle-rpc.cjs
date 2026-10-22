// Stand-ins for migration 101's functions in the fake database, as source
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
}`;
module.exports = { WARCASTLE_RPC };
