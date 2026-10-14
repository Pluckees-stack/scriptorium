-- ============================================================================
-- 077_chronicle_post_rls_fix.sql
--
-- Fixes "new row violates row-level security policy for table
-- chronicle_posts" when posting to the chronicle.
--
-- The client inserts a post and reads its id back (insert ... returning).
-- Postgres checks the returned row against the select policy, which was
-- chronicle_post_visible(id): a lookup by id that cannot yet see the row
-- being inserted, so it failed and the insert was refused.
--
-- The select policy now checks the row's own columns, through
-- chronicle_row_visible(). chronicle_post_visible(id) is kept (accounts and
-- likes still use it, for posts that already exist) and now shares the
-- same rule.
--
-- Database only, no index.html change: run it any time.
--
-- To undo (puts back the broken policy):
--   drop policy if exists "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts;
--   create policy "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts
--     for select to authenticated using (chronicle_post_visible(id));
--   (then re-run chronicle_post_visible from 076 and drop chronicle_row_visible)
-- ============================================================================

-- SECURITY DEFINER so it can read campaigns.chronicle_sharing for players
-- outside the campaign (shared posts).
create or replace function chronicle_row_visible(p_campaign uuid, p_author uuid, p_shared boolean, p_hidden boolean)
returns boolean language sql stable security definer set search_path = public as $$
  select (is_campaign_member(p_campaign) or is_platform_admin()
          or (p_shared and exists (select 1 from campaigns c where c.id = p_campaign and c.chronicle_sharing)))
     and (not p_hidden or p_author = auth.uid() or is_campaign_organiser(p_campaign) or is_platform_admin());
$$;
revoke all on function chronicle_row_visible(uuid, uuid, boolean, boolean) from public, anon;
grant execute on function chronicle_row_visible(uuid, uuid, boolean, boolean) to authenticated;

create or replace function chronicle_post_visible(p_post bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from chronicle_posts p
     where p.id = p_post
       and chronicle_row_visible(p.campaign_id, p.author_id, p.shared, p.hidden)
  );
$$;

drop policy if exists "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts;
create policy "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts
  for select to authenticated using (chronicle_row_visible(campaign_id, author_id, shared, hidden));
