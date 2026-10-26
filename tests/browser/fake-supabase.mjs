// A stand-in for @supabase/supabase-js: an in-memory database (window.__FAKE_DB)
// behind the same query API, for browser checks without a real project.
const db = window.__FAKE_DB || {};
const log = window.__FAKE_LOG = [];
const rpcs = window.__FAKE_RPC || {};
const uuid = () => crypto.randomUUID();
const singular = (t) => t.replace(/ies$/, 'y').replace(/s$/, '');
const FK_GUESS = { players: ['user_id', 'player_id', 'created_by'], campaigns: ['campaign_id'] };

function splitTop(s) {
  const out = []; let depth = 0, cur = '';
  for (const c of s) {
    if (c === '(') depth++; if (c === ')') depth--;
    if (c === ',' && !depth) { out.push(cur.trim()); cur = ''; } else cur += c;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}
function project(table, row, sel) {
  if (!sel || sel.trim() === '*') return { ...row };
  const out = {};
  for (const part of splitTop(sel)) {
    const m = part.match(/^(?:([\w]+):)?([\w]+)(?:!\w+)?\((.*)\)$/s);
    if (!m) { if (part === '*') Object.assign(out, row); else { const [col, as] = part.split(':').reverse(); out[as || col] = row[col]; } continue; }
    const [, alias, t, inner] = m, key = alias || t, rows = db[t] || [];
    const fks = [`${alias}_id`, `${singular(t)}_id`, ...(FK_GUESS[t] || [])].filter(k => k in row);
    if (fks.length) { const r = rows.find(x => x.id === row[fks[0]]); out[key] = r ? project(t, r, inner) : null; }
    else { const back = `${singular(table)}_id`; out[key] = rows.filter(x => x[back] === row.id).map(x => project(t, x, inner)); }
  }
  return out;
}
const val = (v) => v === 'null' ? null : v === 'true' ? true : v === 'false' ? false : v;
function orMatch(row, expr) {
  return splitTop(expr).some(cond => {
    const [col, op, ...rest] = cond.split('.'); const v = rest.join('.');
    if (op === 'eq') return String(row[col]) === v;
    if (op === 'is') return row[col] == null && v === 'null';
    if (op === 'in') return v.replace(/[()]/g, '').split(',').includes(String(row[col]));
    return false;
  });
}
class Query {
  constructor(table) { this.table = table; this.filters = []; this.op = 'select'; this.sel = '*'; this.opts = {}; }
  select(sel = '*', opts = {}) { if (this.op === 'select') { this.sel = sel; this.opts = opts; } else this.returning = sel; return this; }
  insert(rows) { this.op = 'insert'; this.payload = rows; return this; }
  upsert(rows, o = {}) { this.op = 'upsert'; this.payload = rows; this.conflict = o.onConflict; return this; }
  update(p) { this.op = 'update'; this.payload = p; return this; }
  delete() { this.op = 'delete'; return this; }
  eq(c, v) { this.filters.push(r => String(r[c]) === String(v)); return this; }
  neq(c, v) { this.filters.push(r => String(r[c]) !== String(v)); return this; }
  in(c, vs) { const s = new Set((vs || []).map(String)); this.filters.push(r => s.has(String(r[c]))); return this; }
  is(c, v) { this.filters.push(r => v === null ? r[c] == null : r[c] === v); return this; }
  gt(c, v) { this.filters.push(r => r[c] > v); return this; }
  gte(c, v) { this.filters.push(r => r[c] >= v); return this; }
  lt(c, v) { this.filters.push(r => r[c] < v); return this; }
  lte(c, v) { this.filters.push(r => r[c] <= v); return this; }
  or(expr) { this.filters.push(r => orMatch(r, expr)); return this; }
  match(o) { Object.entries(o).forEach(([c, v]) => this.eq(c, v)); return this; }
  not() { return this; } filter() { return this; } contains() { return this; } overlaps() { return this; } textSearch() { return this; } ilike() { return this; } like() { return this; }
  order(c, o = {}) { this.sorts = [...(this.sorts || []), [c, o.ascending !== false]]; return this; }
  limit(n) { this.lim = n; return this; }
  range(a, b) { this.rng = [a, b]; return this; }
  single() { this.one = 'single'; return this; }
  maybeSingle() { this.one = 'maybe'; return this; }
  abortSignal() { return this; }
  throwOnError() { return this; }
  then(res, rej) { return Promise.resolve().then(() => this.run()).then(res, rej); }
  run() {
    const t = (db[this.table] ||= []), match = r => this.filters.every(f => f(r));
    let rows;
    if (this.op === 'insert' || this.op === 'upsert') {
      const list = (Array.isArray(this.payload) ? this.payload : [this.payload]).map(r => ({ id: uuid(), created_at: new Date().toISOString(), ...r }));
      // a world can refuse an insert the way a constraint would (window.__FAKE_REFUSE[table](row, db) → error)
      const refused = list.map(r => window.__FAKE_REFUSE?.[this.table]?.(r, db)).find(Boolean);
      if (refused) { log.push([this.op, this.table, 0]); return { data: null, error: refused }; }
      rows = list.map(r => {
        if (this.op === 'upsert' && this.conflict) {
          const keys = this.conflict.split(','), old = t.find(x => keys.every(k => String(x[k]) === String(r[k])));
          if (old) { Object.assign(old, r, { id: old.id }); return old; }
        }
        t.push(r); return r;
      });
      if (this.table === 'warcastle_moves') rows.forEach(r => { r.seq = (window.__seq = (window.__seq || 0) + 1); });
    } else if (this.op === 'update') { rows = t.filter(match); rows.forEach(r => Object.assign(r, this.payload)); }
    else if (this.op === 'delete') { rows = t.filter(match); db[this.table] = t.filter(r => !match(r)); }
    else rows = t.filter(match);
    log.push([this.op, this.table, rows.length]);
    if (this.op !== 'select' && !this.returning) return { data: null, error: null };
    let out = rows.slice();
    (this.sorts || []).slice().reverse().forEach(([c, asc]) => out.sort((a, b) => (a[c] > b[c] ? 1 : a[c] < b[c] ? -1 : 0) * (asc ? 1 : -1)));
    if (this.rng) out = out.slice(this.rng[0], this.rng[1] + 1);
    if (this.lim != null) out = out.slice(0, this.lim);
    const count = out.length;
    out = out.map(r => project(this.table, r, this.op === 'select' ? this.sel : this.returning));
    if (this.opts.head) return { data: null, count, error: null };
    if (this.one) {
      if (!out.length) return this.one === 'single' ? { data: null, error: { message: 'No rows', code: 'PGRST116' } } : { data: null, error: null };
      return { data: out[0], error: null, count };
    }
    return { data: out, error: null, count };
  }
}
export function createClient() {
  const session = window.__FAKE_SESSION;
  const ok = (data = null) => Promise.resolve({ data, error: null });
  return {
    from: (t) => new Query(t),
    rpc: (name, args) => { log.push(['rpc', name]); return Promise.resolve(rpcs[name] ? rpcs[name](args, db) : { data: null, error: null }); },
    channel: () => ({ on() { return this; }, subscribe() { return this; }, unsubscribe() {} }),
    removeChannel: () => {},
    storage: { from: () => ({ getPublicUrl: (p) => ({ data: { publicUrl: '/' + p } }), upload: () => ok({}), remove: () => ok([]), list: () => ok([]), createSignedUrl: () => ok({ signedUrl: '' }) }) },
    functions: { invoke: () => ok({}) },
    auth: {
      getSession: () => ok({ session }),
      getUser: () => ok({ user: session?.user }),
      onAuthStateChange: (cb) => { setTimeout(() => cb(session ? 'SIGNED_IN' : 'SIGNED_OUT', session), 0); return { data: { subscription: { unsubscribe() {} } } }; },
      refreshSession: () => ok({ session }),
      signOut: () => ok(), signInWithPassword: () => ok({ session }), signUp: () => ok({}), updateUser: () => ok({ user: session?.user }),
      resetPasswordForEmail: () => ok(), signInWithOAuth: () => ok(),
      mfa: {
        getAuthenticatorAssuranceLevel: () => ok({ currentLevel: 'aal2', nextLevel: 'aal2' }),
        listFactors: () => ok({ totp: [{ id: 'f1', status: 'verified', factor_type: 'totp' }], all: [] }),
        enroll: () => ok({}), unenroll: () => ok({}), challengeAndVerify: () => ok({}),
      },
    },
  };
}
