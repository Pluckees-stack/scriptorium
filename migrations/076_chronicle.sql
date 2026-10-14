-- ============================================================================
-- 076_chronicle.sql
--
-- The chronicle: a feed in the Story tab of battle reports (campaign and
-- free play battles) and painting updates, with photos, each player's own
-- account of a battle, and a thumbs up. No comments.
--
-- 1. chronicle_posts: one per battle report or painting update.
--    - game_id links a campaign battle (one post per battle; the second
--      player adds their account to the same post).
--    - other_player_id is the player on the other side (set from the
--      battle, or picked by hand for free play). They can add their account.
--    - shared: the author chose "Share beyond this campaign". Shown to
--      everyone signed in to Scriptorium, as long as the campaign allows it
--      (campaigns.chronicle_sharing).
--    - hidden: set by an organiser (set_chronicle_post_hidden); hidden posts
--      are only visible to their author and the organisers.
--    - headline / campaign_name: written when posting, so a shared post
--      reads correctly in other campaigns without exposing anything else.
-- 2. chronicle_accounts: each player's story and photos for a post.
--    author_name / author_faction are a snapshot taken when writing.
-- 3. chronicle_likes: one thumbs up per player per post.
-- 4. campaigns.chronicle_sharing: organiser switch (on by default) allowing
--    this campaign's players to share posts beyond it.
-- 5. Storage: public chronicle-photos bucket; players write only inside
--    their own folder ({user id}/...), as with unit photos (073).
-- 6. Notifications (075): "write up your battle" once a battle is
--    confirmed, "X wrote up your battle: add your side", and (fun) thumbs up.
--
-- Run before merging the chronicle index.html.
--
-- To undo:
--   drop trigger if exists notify_chronicle_prompt on games;
--   drop trigger if exists notify_chronicle_post on chronicle_posts;
--   drop trigger if exists notify_chronicle_like on chronicle_likes;
--   drop function if exists notify_chronicle_prompt_trg(), notify_chronicle_post_trg(),
--     notify_chronicle_like_trg(), set_chronicle_post_hidden(bigint, boolean),
--     chronicle_post_visible(bigint);
--   drop table if exists chronicle_likes, chronicle_accounts, chronicle_posts;
--   alter table campaigns drop column if exists chronicle_sharing;
--   (and empty then delete the chronicle-photos bucket in Storage)
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table campaigns add column if not exists chronicle_sharing boolean not null default true;

create table if not exists chronicle_posts (
  id               bigint generated always as identity primary key,
  campaign_id      uuid not null references campaigns(id) on delete cascade,
  author_id        uuid not null references players(id) on delete cascade,
  kind             text not null check (kind in ('battle', 'painting')),
  game_id          bigint references games(id) on delete set null,
  free_play        boolean not null default false,
  other_player_id  uuid references players(id) on delete set null,
  unit_id          bigint references units(id) on delete set null,
  title            text check (char_length(title) <= 120),
  headline         text check (char_length(headline) <= 300),
  campaign_name    text,
  shared           boolean not null default false,
  hidden           boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index if not exists chronicle_posts_one_per_game on chronicle_posts (game_id) where game_id is not null;
create index if not exists chronicle_posts_campaign_idx on chronicle_posts (campaign_id, created_at desc);
create index if not exists chronicle_posts_shared_idx on chronicle_posts (created_at desc) where shared;

create table if not exists chronicle_accounts (
  post_id         bigint not null references chronicle_posts(id) on delete cascade,
  author_id       uuid not null references players(id) on delete cascade,
  author_name     text,
  author_faction  text,
  body            text check (char_length(body) <= 8000),
  photos          text[] not null default '{}' check (cardinality(photos) <= 4),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  primary key (post_id, author_id)
);

create table if not exists chronicle_likes (
  post_id     bigint not null references chronicle_posts(id) on delete cascade,
  user_id     uuid not null references players(id) on delete cascade,
  user_name   text,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table chronicle_posts enable row level security;
alter table chronicle_accounts enable row level security;
alter table chronicle_likes enable row level security;

-- Visibility, shared by all three tables. SECURITY DEFINER so it can read
-- campaigns/members regardless of the caller's own access.
create or replace function chronicle_post_visible(p_post bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from chronicle_posts p join campaigns c on c.id = p.campaign_id
     where p.id = p_post
       and (is_campaign_member(p.campaign_id) or is_platform_admin() or (p.shared and c.chronicle_sharing))
       and (not p.hidden or p.author_id = auth.uid() or is_campaign_organiser(p.campaign_id) or is_platform_admin())
  );
$$;
revoke all on function chronicle_post_visible(bigint) from public, anon;
grant execute on function chronicle_post_visible(bigint) to authenticated;

-- posts
drop policy if exists "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts;
create policy "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts
  for select to authenticated using (chronicle_post_visible(id));

drop policy if exists "players post to their own campaign" on chronicle_posts;
create policy "players post to their own campaign" on chronicle_posts
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and is_campaign_member(campaign_id)
    and not hidden
    and (game_id is null or exists (
          select 1 from games g where g.id = game_id and g.campaign_id = chronicle_posts.campaign_id
             and (select auth.uid()) in (g.player_id, g.opponent_id)))
    and (other_player_id is null or exists (
          select 1 from campaign_members m where m.user_id = other_player_id and m.campaign_id = chronicle_posts.campaign_id))
  );

drop policy if exists "authors edit their own posts" on chronicle_posts;
create policy "authors edit their own posts" on chronicle_posts
  for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));

drop policy if exists "authors and organisers delete posts" on chronicle_posts;
create policy "authors and organisers delete posts" on chronicle_posts
  for delete to authenticated using (author_id = (select auth.uid()) or is_campaign_organiser(campaign_id) or is_platform_admin());

-- authors may change only these; hiding goes through set_chronicle_post_hidden
grant select, insert, delete on chronicle_posts to authenticated;
revoke update on chronicle_posts from authenticated;
grant update (title, shared, other_player_id, unit_id, updated_at) on chronicle_posts to authenticated;

-- accounts
drop policy if exists "accounts are visible with their post" on chronicle_accounts;
create policy "accounts are visible with their post" on chronicle_accounts
  for select to authenticated using (chronicle_post_visible(post_id));

drop policy if exists "the players in a post write their own account" on chronicle_accounts;
create policy "the players in a post write their own account" on chronicle_accounts
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from chronicle_posts p
        left join games g on g.id = p.game_id
       where p.id = post_id
         and (select auth.uid()) in (p.author_id, p.other_player_id, g.player_id, g.opponent_id))
  );

drop policy if exists "players edit their own account" on chronicle_accounts;
create policy "players edit their own account" on chronicle_accounts
  for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));

drop policy if exists "players and organisers delete accounts" on chronicle_accounts;
create policy "players and organisers delete accounts" on chronicle_accounts
  for delete to authenticated using (
    author_id = (select auth.uid())
    or exists (select 1 from chronicle_posts p where p.id = post_id and (is_campaign_organiser(p.campaign_id) or is_platform_admin()))
  );

grant select, insert, delete on chronicle_accounts to authenticated;
revoke update on chronicle_accounts from authenticated;
grant update (body, photos, author_name, author_faction, updated_at) on chronicle_accounts to authenticated;

-- likes
drop policy if exists "likes are visible with their post" on chronicle_likes;
create policy "likes are visible with their post" on chronicle_likes
  for select to authenticated using (chronicle_post_visible(post_id));

drop policy if exists "players give their own thumbs up" on chronicle_likes;
create policy "players give their own thumbs up" on chronicle_likes
  for insert to authenticated with check (user_id = (select auth.uid()) and chronicle_post_visible(post_id));

drop policy if exists "players take back their own thumbs up" on chronicle_likes;
create policy "players take back their own thumbs up" on chronicle_likes
  for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, delete on chronicle_likes to authenticated;
revoke update on chronicle_likes from authenticated;

-- organisers hide or show a post
create or replace function set_chronicle_post_hidden(p_post bigint, p_hidden boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from chronicle_posts p where p.id = p_post
                  and (is_campaign_organiser(p.campaign_id) or is_platform_admin())) then
    raise exception 'Only an organiser of this campaign can hide posts.';
  end if;
  update chronicle_posts set hidden = p_hidden where id = p_post;
end;
$$;
revoke all on function set_chronicle_post_hidden(bigint, boolean) from public, anon;
grant execute on function set_chronicle_post_hidden(bigint, boolean) to authenticated;

-- storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chronicle-photos', 'chronicle-photos', true, 2097152, array['image/webp', 'image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "players read their own chronicle photos" on storage.objects;
create policy "players read their own chronicle photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'chronicle-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "players upload their own chronicle photos" on storage.objects;
create policy "players upload their own chronicle photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chronicle-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "players delete their own chronicle photos" on storage.objects;
create policy "players delete their own chronicle photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'chronicle-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- notifications (075)
create or replace function notify_chronicle_prompt_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.confirmation_status = 'confirmed' and (tg_op = 'INSERT' or old.confirmation_status is distinct from 'confirmed')
     and new.opponent_id is not null then
    perform notify_user(new.player_id, new.campaign_id, 'chronicle_prompt', 'Write up your battle',
      'Add photos and your account of the battle against ' || coalesce((select display_name from players where id = new.opponent_id), 'your opponent') || ' in the Story tab.');
    perform notify_user(new.opponent_id, new.campaign_id, 'chronicle_prompt', 'Write up your battle',
      'Add photos and your account of the battle against ' || coalesce((select display_name from players where id = new.player_id), 'your opponent') || ' in the Story tab.');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_chronicle_prompt on games;
create trigger notify_chronicle_prompt after insert or update of confirmation_status on games
  for each row execute function notify_chronicle_prompt_trg();

create or replace function notify_chronicle_post_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_other uuid;
begin
  v_other := coalesce(new.other_player_id,
    (select case when g.player_id = new.author_id then g.opponent_id else g.player_id end from games g where g.id = new.game_id));
  if new.kind = 'battle' and v_other is not null and v_other <> new.author_id then
    perform notify_user(v_other, new.campaign_id, 'chronicle_other_side',
      coalesce((select display_name from players where id = new.author_id), 'Your opponent') || ' wrote up your battle',
      'Read it in the Story tab, and add your side of the story.');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_chronicle_post on chronicle_posts;
create trigger notify_chronicle_post after insert on chronicle_posts
  for each row execute function notify_chronicle_post_trg();

create or replace function notify_chronicle_like_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  p chronicle_posts%rowtype;
begin
  select * into p from chronicle_posts where id = new.post_id;
  if p.author_id <> new.user_id then
    perform notify_user(p.author_id, p.campaign_id, 'chronicle_like',
      coalesce(new.user_name, (select display_name from players where id = new.user_id), 'Someone') || ' gave your post a thumbs up',
      coalesce(nullif(p.title, ''), p.headline), true);
  end if;
  return new;
end;
$$;
drop trigger if exists notify_chronicle_like on chronicle_likes;
create trigger notify_chronicle_like after insert on chronicle_likes
  for each row execute function notify_chronicle_like_trg();
