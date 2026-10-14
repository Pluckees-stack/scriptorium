-- ============================================================================
-- 078_battle_cards.sql
--
-- Battle cards in Standings > Your battles: each battle (campaign or free
-- play) gets a card where the two players add photos and their side of the
-- story. It stays on the card, as a draft only they can see, until one of
-- them taps "Post to the chronicle".
--
-- 1. chronicle_posts.published: false while a post is a draft on a battle
--    card. Existing posts, and anything posted from the Story tab, are
--    published (the default).
-- 2. chronicle_posts.free_play_log_id: links a write-up to the free play
--    game (free_play_log) it came from, one post per game, like game_id.
-- 3. Visibility: a draft is visible only to the players in it (author, the
--    other player, or the two players of the linked battle), never shared.
--    chronicle_row_visible() gains those columns; the 4-argument version
--    from 077 is replaced.
-- 4. publish_chronicle_post(): either player posts the draft to the
--    chronicle (a campaign battle must be confirmed first). It moves to the
--    top of the feed and the other player is told.
-- 5. Notifications: "Write up your battle" and (while the post is a draft)
--    "X wrote up your battle" now point at the battle card.
--
-- Run before merging the battle cards index.html.
--
-- To undo:
--   drop function if exists publish_chronicle_post(bigint);
--   then re-run 077 (puts back the 4-argument chronicle_row_visible and the
--   policy), drop function chronicle_row_visible(uuid, uuid, boolean, boolean, boolean, uuid, bigint),
--   re-run the insert policy, notify_chronicle_post_trg and notify_chronicle_prompt_trg from 076, and
--   alter table chronicle_posts drop column if exists published, drop column if exists free_play_log_id;
-- ============================================================================

alter table chronicle_posts add column if not exists published boolean not null default true;
alter table chronicle_posts add column if not exists free_play_log_id uuid references free_play_log(id) on delete set null;
create unique index if not exists chronicle_posts_one_per_free_play on chronicle_posts (free_play_log_id) where free_play_log_id is not null;

-- SECURITY DEFINER so it can read campaigns and games regardless of the
-- caller's own access.
create or replace function chronicle_row_visible(p_campaign uuid, p_author uuid, p_shared boolean, p_hidden boolean,
                                                 p_published boolean, p_other uuid, p_game bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when not p_published then
      auth.uid() in (p_author, p_other)
      or exists (select 1 from games g where g.id = p_game and auth.uid() in (g.player_id, g.opponent_id))
    else
      (is_campaign_member(p_campaign) or is_platform_admin()
        or (p_shared and exists (select 1 from campaigns c where c.id = p_campaign and c.chronicle_sharing)))
      and (not p_hidden or p_author = auth.uid() or is_campaign_organiser(p_campaign) or is_platform_admin())
  end;
$$;
revoke all on function chronicle_row_visible(uuid, uuid, boolean, boolean, boolean, uuid, bigint) from public, anon;
grant execute on function chronicle_row_visible(uuid, uuid, boolean, boolean, boolean, uuid, bigint) to authenticated;

drop policy if exists "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts;
create policy "chronicle posts are visible to the campaign, or everyone when shared" on chronicle_posts
  for select to authenticated
  using (chronicle_row_visible(campaign_id, author_id, shared, hidden, published, other_player_id, game_id));

create or replace function chronicle_post_visible(p_post bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from chronicle_posts p
     where p.id = p_post
       and chronicle_row_visible(p.campaign_id, p.author_id, p.shared, p.hidden, p.published, p.other_player_id, p.game_id)
  );
$$;

drop function if exists chronicle_row_visible(uuid, uuid, boolean, boolean);

-- a free play link must be the author's own free play game
drop policy if exists "players post to their own campaign" on chronicle_posts;
create policy "players post to their own campaign" on chronicle_posts
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and is_campaign_member(campaign_id)
    and not hidden
    and (game_id is null or exists (
          select 1 from games g where g.id = game_id and g.campaign_id = chronicle_posts.campaign_id
             and (select auth.uid()) in (g.player_id, g.opponent_id)))
    and (free_play_log_id is null or exists (
          select 1 from free_play_log f where f.id = free_play_log_id and f.campaign_id = chronicle_posts.campaign_id
             and f.user_id = (select auth.uid())))
    and (other_player_id is null or exists (
          select 1 from campaign_members m where m.user_id = other_player_id and m.campaign_id = chronicle_posts.campaign_id))
  );

-- either player posts a draft to the chronicle
create or replace function publish_chronicle_post(p_post bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  p chronicle_posts%rowtype;
  g games%rowtype;
  v_other uuid;
begin
  select * into p from chronicle_posts where id = p_post;
  if not found then raise exception 'That write-up no longer exists.'; end if;
  if p.game_id is not null then select * into g from games where id = p.game_id; end if;
  if not coalesce(auth.uid() in (p.author_id, p.other_player_id, g.player_id, g.opponent_id), false) then
    raise exception 'Only the players in this battle can post it.';
  end if;
  if p.published then return; end if;
  if p.game_id is not null and g.confirmation_status is distinct from 'confirmed' then
    raise exception 'Confirm the result first, then post it to the chronicle.';
  end if;
  update chronicle_posts set published = true, created_at = now(), updated_at = now() where id = p_post;
  v_other := case when p.game_id is not null then (case when g.player_id = auth.uid() then g.opponent_id else g.player_id end)
                  when auth.uid() = p.author_id then p.other_player_id else p.author_id end;
  if v_other is not null and v_other <> auth.uid() then
    perform notify_user(v_other, p.campaign_id, 'chronicle_published',
      coalesce((select display_name from players where id = auth.uid()), 'Your opponent') || ' posted your battle to the chronicle',
      'It’s in the Story tab now.');
  end if;
end;
$$;
revoke all on function publish_chronicle_post(bigint) from public, anon;
grant execute on function publish_chronicle_post(bigint) to authenticated;

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
      case when new.published then 'Read it in the Story tab, and add your side of the story.'
           else 'Add your photos and your side on the battle card, under Your battles in Standings.' end);
  end if;
  return new;
end;
$$;

-- "Write up your battle" now points at the battle card
create or replace function notify_chronicle_prompt_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.confirmation_status = 'confirmed' and (tg_op = 'INSERT' or old.confirmation_status is distinct from 'confirmed')
     and new.opponent_id is not null then
    perform notify_user(new.player_id, new.campaign_id, 'chronicle_prompt', 'Write up your battle',
      'Add photos and your side of the battle against ' || coalesce((select display_name from players where id = new.opponent_id), 'your opponent') || ' on its card, under Your battles in Standings.');
    perform notify_user(new.opponent_id, new.campaign_id, 'chronicle_prompt', 'Write up your battle',
      'Add photos and your side of the battle against ' || coalesce((select display_name from players where id = new.player_id), 'your opponent') || ' on its card, under Your battles in Standings.');
  end if;
  return new;
end;
$$;
