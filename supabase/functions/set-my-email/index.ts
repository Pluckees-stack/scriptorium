// set-my-email
//
// Lets an already-logged-in player set a real email on their OWN account,
// replacing the synthetic, non-deliverable one (username@seasonofskulls.app,
// see index.html's toEmail()) that Supabase Auth was originally given at
// signup. This is what makes Supabase's native "forgot password" email flow
// possible for that account going forward.
//
// Deliberately routes through the admin API rather than the client-side
// self-service supabase.auth.updateUser({ email }) call: this project has
// "Secure email change" enabled, which requires confirming the change via
// links sent to BOTH the old and new address -- and the old address here is
// the undeliverable synthetic one, which would make self-service email
// changes impossible to ever complete. The admin API's email_confirm: true
// is exactly the escape hatch for "the server already trusts this address,
// skip confirmation" -- same pattern this project's admin-reset-password
// function already uses for passwords.
//
// No superadmin check needed: the target is always the caller's own id
// (never taken from the request body), so "you have a valid session" is the
// only authorization this needs.
//
// Deploy with: supabase functions deploy set-my-email
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected
// automatically for every Edge Function -- nothing to configure by hand.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const AUTH_DOMAIN = 'seasonofskulls.app';
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
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

    // Identifies the caller from their own session -- an anon-key client so
    // this respects the same auth the rest of the app uses, purely to
    // resolve "who is calling", not to read/write anything privileged.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller }, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !caller) return json({ error: 'Could not verify your session.' }, 401);

    const body = await req.json().catch(() => ({}));
    const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
    if (!email || !EMAIL_RE.test(email)) {
      return json({ error: 'Enter a valid email address.' }, 400);
    }
    if (email.endsWith('@' + AUTH_DOMAIN)) {
      return json({ error: 'Please use your real email address.' }, 400);
    }

    // Service-role client for everything privileged from here on -- never
    // constructed from anything the browser sent, only from this function's
    // own server-side environment.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { error: updateErr } = await adminClient.auth.admin.updateUserById(caller.id, {
      email,
      email_confirm: true,
    });
    if (updateErr) return json({ error: updateErr.message }, 400);

    // Best-effort audit trail -- not fatal if it fails, and not currently
    // surfaced anywhere in the app's UI. Just gives a DB-side record of who
    // did this and when, queryable directly if ever needed.
    await adminClient.from('admin_audit_log').insert({
      campaign_id: null,
      table_name: 'auth.users',
      action: 'UPDATE',
      row_id: caller.id,
      actor_id: caller.id,
      new_data: { note: 'Real email added via set-my-email Edge Function' },
    }).then(() => {}, () => {});

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
