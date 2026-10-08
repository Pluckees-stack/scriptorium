-- ============================================================================
-- 070_lock_games_and_private_helpers.sql
--
-- Two security fixes found in the October 2026 review. Neither needs any
-- change to index.html -- the app already goes through these functions.
--
-- 1. Players could rewrite their own battles. "players manage their own
--    games" (010, 016, 045) was FOR ALL, so the logging player could
--    UPDATE/INSERT their own games rows straight through the API -- e.g. set
--    confirmation_status = 'confirmed' and any campaign_points they liked,
--    skipping the opponent's confirmation entirely, or change a result after
--    it was confirmed. log_game_with_xp forcing 'pending' (049) didn't help,
--    because it was SECURITY INVOKER and relied on that same policy to
--    insert. Fix: make log_game_with_xp SECURITY DEFINER (like every other
--    game RPC since 049) and drop the policy. Reading is unaffected --
--    "campaign members can read games" (031) still covers it. Checked
--    index.html: it never writes to games directly (log, delete, confirm,
--    dispute, link all go through RPCs; the only direct UPDATE is the
--    organiser edit, which has its own policy from 028).
--
-- 2. Private helpers were callable by anyone. apply_game_kill_credits (049),
--    reverse_game_kill_credits (051) and sync_tournament_pairing_for_game
--    (057) do no authorization of their own and were only revoked from
--    PUBLIC. Supabase also grants EXECUTE directly to anon and authenticated
--    by default, so they stayed callable -- confirmed live with
--    has_function_privilege() (all true). Anyone could re-apply a confirmed
--    game's XP repeatedly, or strip XP from other players' units. Fix:
--    revoke from anon and authenticated too. Their callers are SECURITY
--    DEFINER, so they keep working.
--
-- Independent of 069 (WarCastle, on its own branch) -- safe to run either
-- way round.
--
-- Check afterwards (expect all false):
--   select p.proname, has_function_privilege('anon', p.oid, 'execute') anon,
--          has_function_privilege('authenticated', p.oid, 'execute') authed
--   from pg_proc p where p.proname in
--   ('apply_game_kill_credits','reverse_game_kill_credits','sync_tournament_pairing_for_game');
--
-- To undo (only if logging a battle breaks):
--   alter function log_game_with_xp(jsonb) security invoker;
--   create policy "players manage their own games" on games
--     for all to authenticated
--     using (((select auth.uid()) = player_id) and is_campaign_member(campaign_id))
--     with check (((select auth.uid()) = player_id) and is_campaign_member(campaign_id));
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- 1. games: write only through the RPCs
alter function log_game_with_xp(jsonb) security definer;
drop policy if exists "players manage their own games" on games;

-- 2. private helpers: no direct callers at all
revoke all on function apply_game_kill_credits(bigint) from public, anon, authenticated;
revoke all on function reverse_game_kill_credits(bigint) from public, anon, authenticated;
revoke all on function sync_tournament_pairing_for_game(bigint) from public, anon, authenticated;
