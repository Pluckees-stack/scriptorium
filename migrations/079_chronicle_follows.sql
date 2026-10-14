-- ============================================================================
-- 079_chronicle_follows.sql
--
-- Follow a player in the Story tab: you're notified whenever they post to
-- the chronicle.
--
-- 1. chronicle_follows: one row per (follower, followed). You see, add and
--    remove only your own follows.
-- 2. When a post goes into the chronicle (posted from Story, or a battle
--    card draft being posted), each follower who can see it is notified:
--    campaign members, or anyone when the post is shared beyond the
--    campaign (and the campaign allows it). The other player in a battle
--    is skipped; they already hear about it.
--
-- Run after 078, before merging the matching index.html change.
--
-- To undo:
--   drop trigger if exists notify_chronicle_followers on chronicle_posts;
--   drop function if exists notify_chronicle_followers_trg();
--   drop table if exists chronicle_follows;
-- ============================================================================

-- needs chronicle_posts.published from 078
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'chronicle_posts' and column_name = 'published') then
    raise exception 'Run 078_battle_cards.sql first, then this one.';
  end if;
end $$;

create table if not exists chronicle_follows (
  follower_id  uuid not null references players(id) on delete cascade,
  followed_id  uuid not null references players(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index if not exists chronicle_follows_followed_idx on chronicle_follows (followed_id);

alter table chronicle_follows enable row level security;

drop policy if exists "players see their own follows" on chronicle_follows;
create policy "players see their own follows" on chronicle_follows
  for select to authenticated using (follower_id = (select auth.uid()));
drop policy if exists "players follow for themselves" on chronicle_follows;
create policy "players follow for themselves" on chronicle_follows
  for insert to authenticated with check (follower_id = (select auth.uid()));
drop policy if exists "players unfollow for themselves" on chronicle_follows;
create policy "players unfollow for themselves" on chronicle_follows
  for delete to authenticated using (follower_id = (select auth.uid()));

grant select, insert, delete on chronicle_follows to authenticated;

create or replace function notify_chronicle_followers_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_what text;
  v_sharing boolean;
begin
  if not new.published or new.hidden then return new; end if;
  if tg_op = 'UPDATE' and old.published then return new; end if;
  v_name := coalesce((select display_name from players where id = new.author_id), 'Someone');
  v_what := case when new.kind = 'painting' then 'a painting update' else 'a battle report' end;
  v_sharing := new.shared and coalesce((select chronicle_sharing from campaigns where id = new.campaign_id), false);
  insert into notifications (user_id, campaign_id, kind, title, body, fun)
  select f.follower_id,
         case when m.user_id is not null then new.campaign_id end,
         'chronicle_follow', v_name || ' posted ' || v_what, 'See it in the Story tab.', false
    from chronicle_follows f
    left join campaign_members m on m.campaign_id = new.campaign_id and m.user_id = f.follower_id
   where f.followed_id = new.author_id
     and (m.user_id is not null or v_sharing)
     and f.follower_id is distinct from new.other_player_id
     and not exists (select 1 from games g where g.id = new.game_id and f.follower_id in (g.player_id, g.opponent_id));
  return new;
end;
$$;
drop trigger if exists notify_chronicle_followers on chronicle_posts;
create trigger notify_chronicle_followers after insert or update of published on chronicle_posts
  for each row execute function notify_chronicle_followers_trg();
