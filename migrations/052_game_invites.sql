-- ============================================================================
-- 052_game_invites.sql
--
-- Today, picking an opponent in Game View starts tracking their roster
-- immediately -- they have no say and may not even know a "game" has
-- started against them. This adds a lightweight request/accept handshake:
-- the initiating player sends an invite, the other side accepts or
-- declines, and only then does the existing Game View flow (unchanged)
-- proceed. A "start anyway" bypass on the initiating side means this never
-- blocks play outright if the other player isn't around/using the app.
--
-- This is the app's first player-to-player request needing a response
-- (everything else -- joining a campaign, tournament pairings -- is either
-- self-service or organiser-assigned) and its first bounded polling loop
-- (this app has zero Realtime subscriptions anywhere) -- both narrow to
-- this one feature, not a new general-purpose pattern.
--
-- RLS is a plain narrow grant, not a SECURITY DEFINER function: neither
-- side's action (create, cancel, accept, decline) needs to touch any other
-- table, unlike e.g. confirming a game (which also has to grant XP).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists game_invites (
  id            bigint generated always as identity primary key,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  from_user_id  uuid not null references players(id) on delete cascade,
  to_user_id    uuid not null references players(id) on delete cascade,
  status        text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  mission_id    uuid references missions(id) on delete set null,
  phase_id      uuid references campaign_phases(id) on delete set null,
  scenario      text,
  created_at    timestamptz not null default now(),
  responded_at  timestamptz
);

comment on table game_invites is 'A request from one player to another to start a scored game together -- accepted/declined before the existing Game View flow proceeds. Not itself a game record; games.* rows are only ever created once play actually happens, same as before this table existed.';

create index if not exists game_invites_to_user_pending_idx on game_invites (to_user_id, status) where status = 'pending';
create index if not exists game_invites_from_user_pending_idx on game_invites (from_user_id, status) where status = 'pending';

alter table game_invites enable row level security;

drop policy if exists "campaign members can read invites involving them" on game_invites;
create policy "campaign members can read invites involving them" on game_invites
  for select to authenticated
  using (from_user_id = (select auth.uid()) or to_user_id = (select auth.uid()) or is_platform_admin());

drop policy if exists "players create invites they send" on game_invites;
create policy "players create invites they send" on game_invites
  for insert to authenticated
  with check (from_user_id = (select auth.uid()) and is_campaign_member(campaign_id));

drop policy if exists "sender can update their own invite" on game_invites;
create policy "sender can update their own invite" on game_invites
  for update to authenticated
  using (from_user_id = (select auth.uid()))
  with check (from_user_id = (select auth.uid()));

drop policy if exists "recipient can respond to their invite" on game_invites;
create policy "recipient can respond to their invite" on game_invites
  for update to authenticated
  using (to_user_id = (select auth.uid()))
  with check (to_user_id = (select auth.uid()));
