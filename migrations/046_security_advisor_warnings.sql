-- ============================================================================
-- 046_security_advisor_warnings.sql
--
-- Clears the batch of WARN-level items Supabase's security advisor surfaced
-- once the earlier CRITICAL view/RLS issues (044, 045) were fixed. Three
-- independent groups:
--
-- 1. function_search_path_mutable -- set_updated_at(), log_game_with_xp(),
--    delete_game_with_xp() and increment_unit_xp() don't pin search_path,
--    so it's inherited from whatever the calling session/role has set --
--    exploitable by prepending a malicious schema ahead of `public` on a
--    compromised role. Pinning it to the same schema these functions
--    already implicitly rely on (public) doesn't change behaviour, it just
--    stops that being overridable. Matches the pattern
--    013_set_platform_role_function.sql already used for set_platform_role.
--    (increment_unit_xp/delete_game_with_xp predate this repo's migration
--    tracking -- signatures confirmed live via pg_proc, not guessed.)
--
-- 2. anon/authenticated_security_definer_function_executable -- ten
--    SECURITY DEFINER functions are callable via /rest/v1/rpc/<name> by
--    *anyone*, including signed-out (anon) clients, because Postgres grants
--    EXECUTE to PUBLIC by default and nothing ever revoked it -- the
--    `grant ... to authenticated` lines in 009/011/013/028 were additive,
--    not exclusive. Every real call site in index.html
--    (grep '\.rpc(' index.html) only ever fires from an already-authenticated
--    session, so revoking PUBLIC/anon access costs the app nothing. (Trigger
--    functions log_admin_audit() and set_updated_at()/log_game_with_xp()/
--    delete_game_with_xp()/increment_unit_xp() are SECURITY INVOKER or
--    trigger-only and weren't flagged under this category -- only touched
--    under group 1 above.)
--
-- 3. public_bucket_allows_listing -- map-images' "map images public read"
--    policy has no restriction beyond bucket_id, letting anyone .list() and
--    enumerate every campaign folder/filename in the bucket. The bucket is
--    already public (037_mission_maps.sql), so individual object fetches
--    work via the public URL endpoint regardless of this policy -- checked
--    index.html's only two storage call sites (upload + getPublicUrl(), both
--    pure client-side URL building) and neither needs it. Dropping it only
--    removes the listing capability.
--
-- (auth_leaked_password_protection is a Dashboard toggle, not a migration --
-- Authentication > Policies > "Leaked password protection".)
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- 1. search_path
alter function set_updated_at() set search_path = public;
alter function log_game_with_xp(jsonb) set search_path = public;
alter function delete_game_with_xp(bigint) set search_path = public;
alter function increment_unit_xp(bigint, integer) set search_path = public;

-- 2. lock SECURITY DEFINER functions to authenticated only
revoke execute on function is_campaign_member(uuid) from public;
revoke execute on function is_campaign_organiser(uuid) from public;
revoke execute on function is_superadmin() from public;
revoke execute on function is_platform_admin() from public;
revoke execute on function log_admin_audit() from public;
revoke execute on function remove_campaign_member(uuid, uuid) from public;
revoke execute on function set_campaign_member_alliance(uuid, uuid, text) from public;
revoke execute on function set_campaign_member_role(uuid, uuid, text) from public;
revoke execute on function set_platform_role(uuid, text) from public;
revoke execute on function admin_delete_game(bigint) from public;

grant execute on function is_campaign_member(uuid) to authenticated;
grant execute on function is_campaign_organiser(uuid) to authenticated;
grant execute on function is_superadmin() to authenticated;
grant execute on function is_platform_admin() to authenticated;
grant execute on function remove_campaign_member(uuid, uuid) to authenticated;
grant execute on function set_campaign_member_alliance(uuid, uuid, text) to authenticated;
grant execute on function set_campaign_member_role(uuid, uuid, text) to authenticated;
grant execute on function set_platform_role(uuid, text) to authenticated;
grant execute on function admin_delete_game(bigint) to authenticated;
-- log_admin_audit() is trigger-only, never called directly by the app -- no grant needed.

-- 3. stop the public bucket's read policy from also allowing listing
drop policy if exists "map images public read" on storage.objects;
