// admin-reset-password
//
// Lets a superadmin set a new password for a player who's forgotten theirs,
// without Scriptorium ever collecting real email addresses. Players sign up
// with just a username, which index.html's toEmail() turns into a synthetic
// address (username@seasonofskulls.app) purely so Supabase Auth has
// something in its email column -- those aren't real inboxes, so Supabase's
// built-in "send a password reset email" flow can never reach anyone here.
// This is the admin-driven replacement for that.
//
// Uses the SERVICE ROLE key -- deliberately server-side only, via
// supabase.auth.admin.updateUserById(), the officially supported way to set
// a user's password from a trusted backend. Never expose that key to the
// client; the browser only ever calls this function with its own normal
// (anon-key, RLS-scoped) session, and this function is what checks whether
// that caller is actually allowed to reset someone else's password.
//
// Deploy with: supabase functions deploy admin-reset-password
// (after `supabase login` and `supabase link --project-ref <your-project-ref>`)
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected
// automatically for every Edge Function -- nothing to configure by hand.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// Avoids visually-ambiguous characters (0/O, 1/l/I) since this gets read
// aloud or typed over chat to a player, not copy-pasted from a password manager.
function randomPassword(length = 12) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Missing authorization.' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Identifies the caller from their own session — an anon-key client so
    // this respects the same auth the rest of the app uses, purely to
    // resolve "who is calling this", not to read/write anything privileged.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller }, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !caller) return json({ error: 'Could not verify your session.' }, 401);

    // Service-role client for everything privileged from here on — never
    // constructed from anything the browser sent, only from this function's
    // own server-side environment.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: callerProfile, error: profileErr } = await adminClient
      .from('players').select('platform_role').eq('id', caller.id).maybeSingle();
    if (profileErr || callerProfile?.platform_role !== 'superadmin') {
      return json({ error: 'Only a superadmin can reset another player’s password.' }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const targetUserId = body?.targetUserId;
    if (!targetUserId || typeof targetUserId !== 'string') {
      return json({ error: 'targetUserId is required.' }, 400);
    }

    const requested = typeof body?.newPassword === 'string' ? body.newPassword.trim() : '';
    if (requested && requested.length < 8) {
      return json({ error: 'Password must be at least 8 characters — leave it blank to generate one instead.' }, 400);
    }
    const password = requested || randomPassword();

    const { error: updateErr } = await adminClient.auth.admin.updateUserById(targetUserId, { password });
    if (updateErr) return json({ error: updateErr.message }, 400);

    // Best-effort audit trail — not fatal if it fails, and not currently
    // surfaced anywhere in the app's UI (admin_audit_log's existing views
    // are all filtered to one campaign; this is a platform-level action
    // with no campaign_id). Just gives a DB-side record of who did this
    // and when, queryable directly if ever needed.
    await adminClient.from('admin_audit_log').insert({
      campaign_id: null,
      table_name: 'auth.users',
      action: 'UPDATE',
      row_id: targetUserId,
      actor_id: caller.id,
      new_data: { note: 'Password reset via admin-reset-password Edge Function' },
    }).then(() => {}, () => {});

    return json({ password }, 200);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
