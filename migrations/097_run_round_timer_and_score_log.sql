-- ============================================================================
-- 097_run_round_timer_and_score_log.sql
--
-- Run (admin console PR E1): the round timer can be paused and given more
-- time, and every change to a score is kept in a log the organisers can read.
--
-- 1. tournament_rounds.timer_paused_at: when the organiser paused the round's
--    timer (null while it runs). tournament_rounds.timer_extra_seconds: time
--    added (or taken off) by the organiser, plus time spent paused once it's
--    resumed. A round ends at activated_at + round_minutes + extra (+ the
--    pause so far, while paused). Written by organisers through the existing
--    "organisers manage tournament rounds" policy (039).
-- 2. tournament_score_changes: one row for every change to a pairing's
--    result or Victory Points (whoever made it: an organiser amending it, or
--    a player's confirmed battle filling it in, 057), and to a player's bonus
--    or penalty. Written only by the triggers below; organisers of the event
--    (and platform admins) read it.
--
-- To undo:
--   drop trigger if exists tournament_pairings_score_log on tournament_pairings;
--   drop trigger if exists tournament_entrants_score_log on tournament_entrants;
--   drop function if exists log_tournament_pairing_change();
--   drop function if exists log_tournament_entrant_change();
--   drop table if exists tournament_score_changes;
--   alter table tournament_rounds drop column if exists timer_paused_at,
--     drop column if exists timer_extra_seconds;
-- ============================================================================

alter table tournament_rounds add column if not exists timer_paused_at timestamptz;
alter table tournament_rounds add column if not exists timer_extra_seconds integer not null default 0
  check (timer_extra_seconds between -36000 and 86400);

create table if not exists tournament_score_changes (
  id            bigint generated always as identity primary key,
  tournament_id uuid not null references tournaments(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  changed_by    uuid references players(id) on delete set null,
  changed_at    timestamptz not null default now(),
  kind          text not null check (kind in ('result', 'adjustment')),
  round_number  integer,
  player_a_id   uuid references players(id) on delete set null,
  player_b_id   uuid references players(id) on delete set null,
  before        jsonb not null default '{}'::jsonb,
  after         jsonb not null default '{}'::jsonb
);
comment on table tournament_score_changes is 'Score audit trail for a tournament: written only by triggers on tournament_pairings (result, vp_a, vp_b) and tournament_entrants (score_adjust, vp_adjust, adjust_note).';
create index if not exists tournament_score_changes_tournament_idx on tournament_score_changes (tournament_id, changed_at desc);

alter table tournament_score_changes enable row level security;
drop policy if exists "organisers read score changes" on tournament_score_changes;
create policy "organisers read score changes" on tournament_score_changes
  for select to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin());
-- no insert/update/delete policies: only the triggers write here

create or replace function log_tournament_pairing_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (old.result, old.vp_a, old.vp_b) is not distinct from (new.result, new.vp_a, new.vp_b) then return new; end if;
  insert into tournament_score_changes (tournament_id, campaign_id, changed_by, kind, round_number, player_a_id, player_b_id, before, after)
  values (new.tournament_id, new.campaign_id, auth.uid(), 'result',
    (select round_number from tournament_rounds where id = new.round_id),
    new.player_a_id, new.player_b_id,
    jsonb_build_object('result', old.result, 'vp_a', old.vp_a, 'vp_b', old.vp_b),
    jsonb_build_object('result', new.result, 'vp_a', new.vp_a, 'vp_b', new.vp_b));
  return new;
end;
$$;
drop trigger if exists tournament_pairings_score_log on tournament_pairings;
create trigger tournament_pairings_score_log after update on tournament_pairings
  for each row execute function log_tournament_pairing_change();

create or replace function log_tournament_entrant_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (old.score_adjust, old.vp_adjust, old.adjust_note) is not distinct from (new.score_adjust, new.vp_adjust, new.adjust_note) then return new; end if;
  insert into tournament_score_changes (tournament_id, campaign_id, changed_by, kind, player_a_id, before, after)
  values (new.tournament_id, new.campaign_id, auth.uid(), 'adjustment', new.player_id,
    jsonb_build_object('score', old.score_adjust, 'vp', old.vp_adjust, 'note', old.adjust_note),
    jsonb_build_object('score', new.score_adjust, 'vp', new.vp_adjust, 'note', new.adjust_note));
  return new;
end;
$$;
drop trigger if exists tournament_entrants_score_log on tournament_entrants;
create trigger tournament_entrants_score_log after update on tournament_entrants
  for each row execute function log_tournament_entrant_change();

revoke all on function log_tournament_pairing_change() from public, anon, authenticated;
revoke all on function log_tournament_entrant_change() from public, anon, authenticated;
