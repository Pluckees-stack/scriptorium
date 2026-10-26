-- ============================================================================
-- 108_one_request_per_pair.sql
--
-- Two players can only ever have one open battle between them (a request
-- or a battle under way), whichever of them sent it. When both tapped
-- Play this battle at the same moment, each sent the other a request:
-- one was declined, the other looked to have failed, and it wasn't clear
-- whose battle counted (WarCastle (test), 26 Oct 2026).
--
-- 086's trigger stops a player sending a second request of their own, but
-- not a request crossing one the other player has just sent. A unique
-- index on the pair closes that, including two requests sent in the same
-- instant (the second waits for the first, then fails with 23505).
-- index.html, given that error, joins the request already there.
--
-- One-off: any pair with more than one open battle keeps the one under way
-- (or, if none, the earliest request); the others are withdrawn quietly.
--
-- Idempotent: safe to re-run. Run after 086.
--
-- To undo:
--   drop index if exists game_invites_one_open_per_pair;
-- ============================================================================

do $$
begin
  perform set_config('scriptorium.quiet', 'on', true);
  update game_invites g
     set status = 'cancelled', closed_reason = 'withdrawn', responded_at = coalesce(g.responded_at, now())
    from (
      select id, row_number() over (
               partition by least(from_user_id, to_user_id), greatest(from_user_id, to_user_id)
               order by (status = 'accepted') desc, created_at, id) as n
        from game_invites
       where status in ('pending', 'accepted')
    ) d
   where g.id = d.id and d.n > 1;
end;
$$;

create unique index if not exists game_invites_one_open_per_pair
  on game_invites (least(from_user_id, to_user_id), greatest(from_user_id, to_user_id))
  where status in ('pending', 'accepted');
