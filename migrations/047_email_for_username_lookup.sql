-- ============================================================================
-- 047_email_for_username_lookup.sql
--
-- Supports the move from synthetic (`username@seasonofskulls.app`, see
-- index.html's toEmail()) to real player emails. Login is by username, but
-- once an account's real auth.users.email differs from the client-computable
-- synthetic address, the login form can no longer just guess it -- it needs
-- to ask the database for the account's actual current email first.
--
-- SECURITY DEFINER is required and safe here: auth.users isn't exposed to
-- PostgREST directly, but a function owned by the table-creating role can
-- read it regardless of who calls the function, which is exactly what lets
-- an anonymous (pre-login) client resolve a username to its login email
-- without ever being granted direct access to the auth schema. This is the
-- same mechanism behind Supabase's own "sync auth.users to a public profile
-- table" trigger pattern.
--
-- grant ... to anon is deliberate and required (login happens before any
-- session exists) -- a narrow, intentional exception to 046's anon lockdown.
-- Worth this comment so a future security-advisor cleanup pass doesn't
-- silently revoke it.
--
-- Also adds a case-insensitive unique index on players.display_name.
-- Harmless before now (uniqueness was enforced indirectly, via the synthetic
-- email's own uniqueness constraint), but this function turns a display-name
-- collision into a real cross-account risk: two players differing only in
-- case would make `email_for_username` resolve non-deterministically to
-- either account. Run the pre-flight check below first --
-- this statement fails loudly (not silently) if a duplicate already exists.
--
--   select lower(display_name), count(*) from players group by 1 having count(*) > 1;
--
-- Idempotent: safe to re-run (the unique index only fails if a genuine
-- duplicate exists, which needs a human decision, not a re-run).
-- ============================================================================

create unique index if not exists players_display_name_lower_idx on players (lower(display_name));

create or replace function email_for_username(p_display_name text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select u.email
  from auth.users u
  join players p on p.id = u.id
  where lower(p.display_name) = lower(trim(p_display_name))
  limit 1;
$$;

grant execute on function email_for_username(text) to anon, authenticated;
