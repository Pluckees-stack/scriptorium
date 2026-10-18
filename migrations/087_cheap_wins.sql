-- ============================================================================
-- 087_cheap_wins.sql
--
-- Three small features that make a campaign feel lived in, all run from the
-- Play tab, the Story tab and Admin:
--
-- 1. Awards. Best painted, best sportsman, best chronicler (and any the
--    organiser adds) for a phase, or for the whole campaign. The organiser
--    opens voting; each player casts one vote per award for someone else in
--    the campaign; the organiser sees the tallies, closes voting and
--    announces the winner (or awards it straight away, with no vote).
--    Votes are secret: a player can read only their own, and organisers see
--    totals (award_tallies) but never who voted for whom.
--
--    campaign_awards  one award, for a phase (phase_id) or the whole campaign
--    award_votes      one player's vote for one award
--
-- 2. Grudges. A player declares a grudge against another member with a
--    short reason ("He ate my general at Kemperbad"). The other player
--    accepts or declines. Once accepted, the grudge shows on both players'
--    records and in the Story feed, and the next confirmed battle between
--    the two settles it ("Grudge settled: vengeance for Dave"). A draw
--    leaves it open.
--
--    grudges  one grudge between two players in a campaign
--
-- 3. Calling the organiser. A player at the table picks a reason (rules
--    question, dispute, opponent hasn't turned up, other) and an optional
--    note; every organiser of the campaign gets a notification naming them,
--    their opponent and their table, when known. One call per player every
--    five minutes. Organisers see open calls in Admin and mark them handled.
--
--    organiser_calls  one call for an organiser
--
-- Everything players do goes through the security definer functions below
-- (no direct insert or update), so votes stay one per player per award,
-- grudges can't be settled by hand, and nobody can send someone else a
-- notification. Organisers add, edit and delete awards directly.
--
-- Run before merging the cheap wins index.html. The app hides all three
-- features until this has been run.
--
-- To undo:
--   drop trigger if exists settle_grudges on games;
--   drop function if exists settle_grudges_trg();
--   drop function if exists open_award_voting(uuid, uuid), close_award_voting(uuid, uuid),
--     cast_award_vote(uuid, uuid), award_tallies(uuid), announce_award(uuid, uuid),
--     declare_grudge(uuid, uuid, text), answer_grudge(uuid, boolean), withdraw_grudge(uuid),
--     call_organiser(uuid, text, text, bigint), handle_organiser_call(bigint);
--   drop table if exists award_votes, campaign_awards, grudges, organiser_calls;
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Awards
-- ---------------------------------------------------------------------------

create table if not exists campaign_awards (
  id            uuid primary key default gen_random_uuid(),
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  phase_id      uuid references campaign_phases(id) on delete cascade,
  kind          text not null default 'custom' check (kind in ('painted', 'sportsman', 'chronicler', 'custom')),
  name          text not null check (length(trim(name)) between 1 and 60),
  description   text check (description is null or length(description) <= 200),
  status        text not null default 'draft' check (status in ('draft', 'voting', 'closed', 'announced')),
  winner_id     uuid references players(id) on delete set null,
  sort_order    integer not null default 0,
  created_by    uuid references players(id) on delete set null,
  created_at    timestamptz not null default now(),
  voting_opened_at timestamptz,
  announced_at  timestamptz
);

comment on table campaign_awards is 'An award such as best painted, for one phase (phase_id) or the whole campaign (phase_id null). status: draft (set up, no voting yet), voting (players can vote), closed (voting over, winner not yet announced), announced (winner_id set and everyone told). winner_id is only set by announce_award().';

create index if not exists campaign_awards_campaign_idx on campaign_awards (campaign_id, phase_id);
-- one "Best painted" per phase (or per campaign, for campaign-wide awards)
create unique index if not exists campaign_awards_unique_name
  on campaign_awards (campaign_id, coalesce(phase_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(trim(name)));

create table if not exists award_votes (
  award_id     uuid not null references campaign_awards(id) on delete cascade,
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  voter_id     uuid not null references players(id) on delete cascade,
  nominee_id   uuid not null references players(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (award_id, voter_id),
  check (voter_id <> nominee_id)
);

comment on table award_votes is 'One vote per player per award (the primary key), cast and changed only through cast_award_vote(). A player can read only their own votes; organisers see totals through award_tallies(), never who voted for whom.';

create index if not exists award_votes_nominee_idx on award_votes (award_id, nominee_id);

alter table campaign_awards enable row level security;
alter table award_votes enable row level security;

drop policy if exists "campaign members read awards" on campaign_awards;
create policy "campaign members read awards" on campaign_awards
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "organisers manage awards" on campaign_awards;
create policy "organisers manage awards" on campaign_awards
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check ((is_campaign_organiser(campaign_id) or is_platform_admin())
    and (phase_id is null or exists (select 1 from campaign_phases ph where ph.id = phase_id and ph.campaign_id = campaign_awards.campaign_id)));

-- your own votes only: nobody else's, organisers included
drop policy if exists "players read their own votes" on award_votes;
create policy "players read their own votes" on award_votes
  for select to authenticated
  using (voter_id = (select auth.uid()));

-- ----------------------------------------------------------------------------
-- open_award_voting: open voting on every draft award for a phase (or the
-- campaign-wide awards, when p_phase is null) and tell the campaign once.
-- Returns how many awards were opened.
-- ----------------------------------------------------------------------------
create or replace function open_award_voting(p_campaign uuid, p_phase uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_count integer;
  v_names text;
  v_phase text;
begin
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser can open voting.';
  end if;
  update campaign_awards set status = 'voting', voting_opened_at = now()
   where campaign_id = p_campaign and phase_id is not distinct from p_phase and status = 'draft';
  get diagnostics v_count = row_count;
  if v_count = 0 then return 0; end if;

  select string_agg(name, ', ' order by sort_order, name) into v_names
    from campaign_awards where campaign_id = p_campaign and phase_id is not distinct from p_phase and status = 'voting';
  select name into v_phase from campaign_phases where id = p_phase;
  perform notify_campaign(p_campaign, 'award_vote',
    'Voting is open' || coalesce(' for ' || v_phase, ''),
    'Cast your votes for ' || v_names || ' in the Play tab. Votes are secret.');
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- close_award_voting: stop voting on a phase's awards. Winners are announced
-- separately, one award at a time, with announce_award().
-- ----------------------------------------------------------------------------
create or replace function close_award_voting(p_campaign uuid, p_phase uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_count integer;
begin
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser can close voting.';
  end if;
  update campaign_awards set status = 'closed'
   where campaign_id = p_campaign and phase_id is not distinct from p_phase and status = 'voting';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- cast_award_vote: vote (or change your vote) for someone else in the
-- campaign while the award's voting is open.
-- ----------------------------------------------------------------------------
create or replace function cast_award_vote(p_award uuid, p_nominee uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_award campaign_awards%rowtype;
begin
  select * into v_award from campaign_awards where id = p_award;
  if not found then raise exception 'That award doesn''t exist.'; end if;
  if not is_campaign_member(v_award.campaign_id) then raise exception 'You''re not in this campaign.'; end if;
  if v_award.status <> 'voting' then raise exception 'Voting for % has closed.', v_award.name; end if;
  if p_nominee is null or p_nominee = auth.uid() then raise exception 'Vote for someone other than yourself.'; end if;
  if not exists (select 1 from campaign_members where campaign_id = v_award.campaign_id and user_id = p_nominee) then
    raise exception 'Pick someone in this campaign.';
  end if;
  insert into award_votes (award_id, campaign_id, voter_id, nominee_id)
  values (p_award, v_award.campaign_id, auth.uid(), p_nominee)
  on conflict (award_id, voter_id) do update set nominee_id = excluded.nominee_id, created_at = now();
end;
$$;

-- ----------------------------------------------------------------------------
-- award_tallies: for organisers, the vote count for each nominee on one
-- award. Totals only, never who voted for whom.
-- ----------------------------------------------------------------------------
create or replace function award_tallies(p_award uuid)
returns table (nominee_id uuid, nominee_name text, votes bigint)
language plpgsql security definer stable set search_path = public as $$
declare
  v_campaign uuid;
begin
  select campaign_id into v_campaign from campaign_awards where id = p_award;
  if v_campaign is null or not (is_campaign_organiser(v_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser can see the votes.';
  end if;
  return query
    select v.nominee_id, p.display_name, count(*)
      from award_votes v join players p on p.id = v.nominee_id
     where v.award_id = p_award
     group by v.nominee_id, p.display_name
     order by count(*) desc, p.display_name;
end;
$$;

-- ----------------------------------------------------------------------------
-- announce_award: name the winner (after a vote, or straight away without
-- one), and tell them and the rest of the campaign.
-- ----------------------------------------------------------------------------
create or replace function announce_award(p_award uuid, p_winner uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_award campaign_awards%rowtype;
  v_name text;
  v_phase text;
begin
  select * into v_award from campaign_awards where id = p_award for update;
  if not found then raise exception 'That award doesn''t exist.'; end if;
  if not (is_campaign_organiser(v_award.campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser can announce a winner.';
  end if;
  if v_award.status = 'announced' then raise exception 'The winner of % has already been announced.', v_award.name; end if;
  if not exists (select 1 from campaign_members where campaign_id = v_award.campaign_id and user_id = p_winner) then
    raise exception 'Pick someone in this campaign.';
  end if;

  update campaign_awards set status = 'announced', winner_id = p_winner, announced_at = now() where id = p_award;

  select display_name into v_name from players where id = p_winner;
  select name into v_phase from campaign_phases where id = v_award.phase_id;
  perform notify_user(p_winner, v_award.campaign_id, 'award_won',
    'You won ' || v_award.name || '!',
    coalesce(v_phase || '. ', '') || 'It shows on your record for everyone to see.');
  perform notify_campaign(v_award.campaign_id, 'award',
    v_award.name || ': ' || coalesce(v_name, 'a player'),
    coalesce(v_name, 'A player') || ' wins ' || v_award.name || coalesce(' for ' || v_phase, '') || '.',
    false, array[p_winner]);
end;
$$;

revoke all on function open_award_voting(uuid, uuid) from public, anon;
revoke all on function close_award_voting(uuid, uuid) from public, anon;
revoke all on function cast_award_vote(uuid, uuid) from public, anon;
revoke all on function award_tallies(uuid) from public, anon;
revoke all on function announce_award(uuid, uuid) from public, anon;
grant execute on function open_award_voting(uuid, uuid) to authenticated;
grant execute on function close_award_voting(uuid, uuid) to authenticated;
grant execute on function cast_award_vote(uuid, uuid) to authenticated;
grant execute on function award_tallies(uuid) to authenticated;
grant execute on function announce_award(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Grudges
-- ---------------------------------------------------------------------------

create table if not exists grudges (
  id             uuid primary key default gen_random_uuid(),
  campaign_id    uuid not null references campaigns(id) on delete cascade,
  challenger_id  uuid not null references players(id) on delete cascade,
  target_id      uuid not null references players(id) on delete cascade,
  reason         text not null check (length(trim(reason)) between 1 and 140),
  status         text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'withdrawn', 'settled')),
  winner_id      uuid references players(id) on delete set null,
  game_id        bigint references games(id) on delete set null,
  created_at     timestamptz not null default now(),
  responded_at   timestamptz,
  settled_at     timestamptz,
  check (challenger_id <> target_id)
);

comment on table grudges is 'A grudge one player declares against another. pending: waiting for the target to answer. accepted: open, settled by the next confirmed battle between the two (settle_grudges trigger on games). declined / withdrawn: dropped. settled: winner_id won the battle game_id.';

create index if not exists grudges_campaign_idx on grudges (campaign_id, status, created_at desc);
create index if not exists grudges_target_idx on grudges (target_id, status);
-- one open grudge between any two players at a time, whichever way round
create unique index if not exists grudges_one_open_per_pair
  on grudges (campaign_id, least(challenger_id, target_id), greatest(challenger_id, target_id))
  where status in ('pending', 'accepted');

alter table grudges enable row level security;

-- accepted and settled grudges are public in the campaign; pending,
-- declined and withdrawn ones only to the two players (and organisers)
drop policy if exists "campaign members read grudges" on grudges;
create policy "campaign members read grudges" on grudges
  for select to authenticated
  using (
    (is_campaign_member(campaign_id) and (status in ('accepted', 'settled') or (select auth.uid()) in (challenger_id, target_id)))
    or is_campaign_organiser(campaign_id) or is_platform_admin()
  );

-- ----------------------------------------------------------------------------
-- declare_grudge: declare a grudge against someone else in the campaign.
-- ----------------------------------------------------------------------------
create or replace function declare_grudge(p_campaign uuid, p_target uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_reason text := trim(coalesce(p_reason, ''));
  v_name text;
begin
  if not is_campaign_member(p_campaign) then raise exception 'You''re not in this campaign.'; end if;
  if exists (select 1 from campaigns where id = p_campaign and format = 'open') then
    raise exception 'Grudges are for campaigns and tournaments, not Open play.';
  end if;
  if p_target is null or p_target = auth.uid() then raise exception 'Pick someone other than yourself.'; end if;
  if not exists (select 1 from campaign_members where campaign_id = p_campaign and user_id = p_target) then
    raise exception 'Pick someone in this campaign.';
  end if;
  if length(v_reason) = 0 then raise exception 'Say what they did.'; end if;
  if length(v_reason) > 140 then raise exception 'Keep the reason to 140 characters.'; end if;
  if exists (select 1 from grudges where campaign_id = p_campaign and status in ('pending', 'accepted')
               and least(challenger_id, target_id) = least(auth.uid(), p_target)
               and greatest(challenger_id, target_id) = greatest(auth.uid(), p_target)) then
    raise exception 'There''s already a grudge between you two. Settle that one first.';
  end if;
  if (select count(*) from grudges where challenger_id = auth.uid() and campaign_id = p_campaign and status = 'pending') >= 3 then
    raise exception 'You have three grudges waiting for an answer. Wait for those first.';
  end if;

  insert into grudges (campaign_id, challenger_id, target_id, reason)
  values (p_campaign, auth.uid(), p_target, v_reason)
  returning id into v_id;

  select display_name into v_name from players where id = auth.uid();
  perform notify_user(p_target, p_campaign, 'grudge',
    coalesce(v_name, 'Someone') || ' holds a grudge against you',
    '“' || v_reason || '”. Accept or decline it in the Play tab.');
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- answer_grudge: the target accepts or declines a pending grudge.
-- ----------------------------------------------------------------------------
create or replace function answer_grudge(p_grudge uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_g grudges%rowtype;
  v_name text;
begin
  select * into v_g from grudges where id = p_grudge for update;
  if not found or v_g.target_id <> auth.uid() then raise exception 'That grudge isn''t yours to answer.'; end if;
  if v_g.status <> 'pending' then raise exception 'That grudge has already been answered.'; end if;
  update grudges set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now() where id = p_grudge;
  select display_name into v_name from players where id = auth.uid();
  perform notify_user(v_g.challenger_id, v_g.campaign_id, 'grudge',
    case when p_accept then coalesce(v_name, 'Your rival') || ' accepted your grudge' else coalesce(v_name, 'Your rival') || ' declined your grudge' end,
    case when p_accept then 'Your next battle against them settles it.' else 'Perhaps another time.' end);
end;
$$;

-- ----------------------------------------------------------------------------
-- withdraw_grudge: the challenger drops their grudge (or an organiser
-- removes one, say if the reason oversteps).
-- ----------------------------------------------------------------------------
create or replace function withdraw_grudge(p_grudge uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_g grudges%rowtype;
begin
  select * into v_g from grudges where id = p_grudge for update;
  if not found or not (v_g.challenger_id = auth.uid() or is_campaign_organiser(v_g.campaign_id) or is_platform_admin()) then
    raise exception 'That grudge isn''t yours to withdraw.';
  end if;
  if v_g.status not in ('pending', 'accepted') then raise exception 'That grudge is already over.'; end if;
  update grudges set status = 'withdrawn', responded_at = coalesce(responded_at, now()) where id = p_grudge;
end;
$$;

revoke all on function declare_grudge(uuid, uuid, text) from public, anon;
revoke all on function answer_grudge(uuid, boolean) from public, anon;
revoke all on function withdraw_grudge(uuid) from public, anon;
grant execute on function declare_grudge(uuid, uuid, text) to authenticated;
grant execute on function answer_grudge(uuid, boolean) to authenticated;
grant execute on function withdraw_grudge(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- settle_grudges_trg: when a battle between two players with an accepted
-- grudge is confirmed, the winner settles it. A draw leaves it open.
-- games.result is from the logging player's side (player_id).
-- ----------------------------------------------------------------------------
create or replace function settle_grudges_trg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_g grudges%rowtype;
  v_winner uuid;
  v_name text;
  v_title text;
begin
  if new.confirmation_status <> 'confirmed' or new.opponent_id is null or new.campaign_id is null then return new; end if;
  if tg_op = 'UPDATE' and old.confirmation_status = 'confirmed' then return new; end if;

  select * into v_g from grudges
   where campaign_id = new.campaign_id and status = 'accepted'
     and ((challenger_id = new.player_id and target_id = new.opponent_id)
       or (challenger_id = new.opponent_id and target_id = new.player_id))
   order by created_at limit 1 for update;
  if not found then return new; end if;

  v_winner := case new.result::text when 'win' then new.player_id when 'loss' then new.opponent_id else null end;
  if v_winner is null then
    perform notify_user(v_g.challenger_id, v_g.campaign_id, 'grudge', 'A draw: the grudge burns on', 'Neither of you could finish it. Your next battle settles it.', true);
    perform notify_user(v_g.target_id, v_g.campaign_id, 'grudge', 'A draw: the grudge burns on', 'Neither of you could finish it. Your next battle settles it.', true);
    return new;
  end if;

  update grudges set status = 'settled', winner_id = v_winner, game_id = new.id, settled_at = now() where id = v_g.id;
  select display_name into v_name from players where id = v_winner;
  v_title := case when v_winner = v_g.challenger_id then 'Grudge settled: vengeance for ' || coalesce(v_name, 'the challenger')
                  else 'Grudge settled: ' || coalesce(v_name, 'the accused') || ' stood firm' end;
  perform notify_user(v_g.challenger_id, v_g.campaign_id, 'grudge_settled', v_title, '“' || v_g.reason || '”');
  perform notify_user(v_g.target_id, v_g.campaign_id, 'grudge_settled', v_title, '“' || v_g.reason || '”');
  return new;
end;
$$;
drop trigger if exists settle_grudges on games;
create trigger settle_grudges after insert or update of confirmation_status on games
  for each row execute function settle_grudges_trg();

-- ---------------------------------------------------------------------------
-- 3. Calling the organiser
-- ---------------------------------------------------------------------------

create table if not exists organiser_calls (
  id            bigint generated always as identity primary key,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  caller_id     uuid not null references players(id) on delete cascade,
  reason        text not null check (reason in ('rules', 'dispute', 'no_show', 'other')),
  note          text check (note is null or length(note) <= 300),
  invite_id     bigint references game_invites(id) on delete set null,
  opponent_id   uuid references players(id) on delete set null,
  table_number  integer,
  status        text not null default 'open' check (status in ('open', 'handled')),
  handled_by    uuid references players(id) on delete set null,
  handled_at    timestamptz,
  created_at    timestamptz not null default now()
);

comment on table organiser_calls is 'A player asking for an organiser at the table. opponent_id comes from the battle they were in (invite_id), table_number from their game night booking that day; both are worked out by call_organiser(), not sent by the player.';

create index if not exists organiser_calls_campaign_idx on organiser_calls (campaign_id, status, created_at desc);
create index if not exists organiser_calls_caller_idx on organiser_calls (caller_id, created_at desc);

alter table organiser_calls enable row level security;

drop policy if exists "organisers and callers read calls" on organiser_calls;
create policy "organisers and callers read calls" on organiser_calls
  for select to authenticated
  using (caller_id = (select auth.uid()) or is_campaign_organiser(campaign_id) or is_platform_admin());

-- ----------------------------------------------------------------------------
-- call_organiser: ask for an organiser. Every organiser of the campaign is
-- notified. One call per player every five minutes.
-- ----------------------------------------------------------------------------
create or replace function call_organiser(p_campaign uuid, p_reason text, p_note text default null, p_invite bigint default null)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_opponent uuid;
  v_invite bigint;
  v_table integer;
  v_name text;
  v_opp_name text;
  v_reason text;
  v_body text;
  v_org record;
begin
  if not is_campaign_member(p_campaign) then raise exception 'You''re not in this campaign.'; end if;
  if p_reason not in ('rules', 'dispute', 'no_show', 'other') then raise exception 'Pick a reason.'; end if;
  if v_note is not null and length(v_note) > 300 then raise exception 'Keep the note to 300 characters.'; end if;

  -- one at a time per player, so two taps can't both get through
  perform pg_advisory_xact_lock(hashtext('call_organiser:' || auth.uid()::text));
  if exists (select 1 from organiser_calls where caller_id = auth.uid() and created_at > now() - interval '5 minutes') then
    raise exception 'You called an organiser a moment ago. Give them a few minutes to get to you.';
  end if;

  -- who they're playing, from the battle they're in (only if it's theirs)
  if p_invite is not null then
    select id, case when from_user_id = auth.uid() then to_user_id else from_user_id end
      into v_invite, v_opponent
      from game_invites
     where id = p_invite and campaign_id = p_campaign and auth.uid() in (from_user_id, to_user_id);
  end if;
  -- their table, from tonight's game night booking
  select b.table_number into v_table
    from game_night_bookings b join game_nights n on n.id = b.night_id
   where b.player_id = auth.uid() and b.campaign_id = p_campaign and b.status = 'booked' and b.table_number is not null
     and n.starts_at between now() - interval '12 hours' and now() + interval '6 hours'
   order by n.starts_at desc limit 1;

  insert into organiser_calls (campaign_id, caller_id, reason, note, invite_id, opponent_id, table_number)
  values (p_campaign, auth.uid(), p_reason, v_note, v_invite, v_opponent, v_table)
  returning id into v_id;

  select display_name into v_name from players where id = auth.uid();
  select display_name into v_opp_name from players where id = v_opponent;
  v_reason := case p_reason when 'rules' then 'Rules question' when 'dispute' then 'Dispute'
                            when 'no_show' then 'Opponent hasn''t turned up' else 'Something else' end;
  v_body := v_reason || '.'
    || case when v_opp_name is not null and v_table is not null then ' Playing ' || v_opp_name || ' at table ' || v_table || '.'
            when v_opp_name is not null then ' Playing ' || v_opp_name || '.'
            when v_table is not null then ' At table ' || v_table || '.' else '' end
    || coalesce(' “' || v_note || '”', '');
  for v_org in select user_id from campaign_members where campaign_id = p_campaign and role = 'organiser' and user_id <> auth.uid() loop
    perform notify_user(v_org.user_id, p_campaign, 'call_organiser', coalesce(v_name, 'A player') || ' needs an organiser', v_body);
  end loop;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- handle_organiser_call: an organiser marks a call dealt with; the player
-- is told someone's on it.
-- ----------------------------------------------------------------------------
create or replace function handle_organiser_call(p_call bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_call organiser_calls%rowtype;
  v_name text;
begin
  select * into v_call from organiser_calls where id = p_call for update;
  if not found or not (is_campaign_organiser(v_call.campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser can handle a call.';
  end if;
  if v_call.status = 'handled' then return; end if;
  update organiser_calls set status = 'handled', handled_by = auth.uid(), handled_at = now() where id = p_call;
  select display_name into v_name from players where id = auth.uid();
  perform notify_user(v_call.caller_id, v_call.campaign_id, 'call_organiser_handled',
    coalesce(v_name, 'An organiser') || ' has seen your call', 'Help is on its way.');
end;
$$;

revoke all on function call_organiser(uuid, text, text, bigint) from public, anon;
revoke all on function handle_organiser_call(bigint) from public, anon;
grant execute on function call_organiser(uuid, text, text, bigint) to authenticated;
grant execute on function handle_organiser_call(bigint) to authenticated;
