-- ============================================================================
-- 020_campaign_phases_and_free_play.sql
--
-- Two new features:
--
-- 1. Campaign phases/rounds -- an organiser hard-picks a set of missions for
--    a round (campaign_phases + campaign_phase_missions); each mission is a
--    one-shot game slot -- once a player logs a game against a mission
--    within the currently active phase, that slot is used up for them until
--    the organiser marks the whole phase completed. Only one phase per
--    campaign can be 'active' at a time (whole-campaign lockstep, not
--    per-player pacing), enforced with a partial unique index rather than a
--    trigger. games.phase_id records which phase (if any) a logged game
--    counted toward; a second partial unique index stops the same
--    player from logging the same mission twice within the same phase.
--
-- 2. Free play -- games.free_play_log is deliberately minimal (no mission,
--    no opponent, no result): the Game View mechanics (roster display,
--    wound/kill tracking) work identically in this mode, but nothing beyond
--    "this player played a free-play game on this date" is persisted, and it
--    never touches XP/Glory/log_game_with_xp at all.
--
-- Follows the exact RLS helper convention from 009_rls_helper_functions.sql
-- (is_campaign_member / is_campaign_organiser / is_platform_admin) rather
-- than introducing a new access pattern.
--
-- Idempotent: safe to re-run. Run after 019.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- campaign_phases
-- ---------------------------------------------------------------------------
create table if not exists campaign_phases (
  id            uuid primary key default gen_random_uuid(),
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  name          text not null,
  sequence      integer not null,
  status        text not null default 'draft' check (status in ('draft', 'active', 'completed')),
  created_by    uuid references players(id) on delete set null,
  created_at    timestamptz not null default now(),
  activated_at  timestamptz,
  completed_at  timestamptz
);

comment on table campaign_phases is 'A round of a campaign (or tournament): an organiser-defined set of missions (see campaign_phase_missions) that players work through one game each. Only one phase per campaign may be ''active'' at a time -- see one_active_phase_per_campaign.';

create index if not exists campaign_phases_campaign_id_idx on campaign_phases (campaign_id);

-- Whole-campaign lockstep: at most one active phase per campaign. A plain
-- unique index on campaign_id would block ever having a second phase at
-- all -- the partial WHERE clause means only 'active' rows compete.
drop index if exists one_active_phase_per_campaign;
create unique index one_active_phase_per_campaign on campaign_phases (campaign_id) where status = 'active';

alter table campaign_phases enable row level security;

drop policy if exists "campaign members can read phases" on campaign_phases;
drop policy if exists "organisers manage phases" on campaign_phases;

create policy "campaign members can read phases" on campaign_phases
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

create policy "organisers manage phases" on campaign_phases
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());

-- ---------------------------------------------------------------------------
-- campaign_phase_missions -- the organiser's hard-picked game slots
-- ---------------------------------------------------------------------------
create table if not exists campaign_phase_missions (
  id          uuid primary key default gen_random_uuid(),
  phase_id    uuid not null references campaign_phases(id) on delete cascade,
  mission_id  uuid not null references missions(id) on delete cascade,
  unique (phase_id, mission_id)
);

comment on table campaign_phase_missions is 'One row per mission slot in a phase. A player uses up a slot by logging a game with that phase_id + mission_id (see games.phase_id and one_game_per_phase_mission_per_player) -- once every slot is used, they have nothing left to pick until the organiser completes the phase.';

create index if not exists campaign_phase_missions_phase_id_idx on campaign_phase_missions (phase_id);

alter table campaign_phase_missions enable row level security;

drop policy if exists "campaign members can read phase missions" on campaign_phase_missions;
drop policy if exists "organisers manage phase missions" on campaign_phase_missions;

create policy "campaign members can read phase missions" on campaign_phase_missions
  for select to authenticated
  using (
    exists (
      select 1 from campaign_phases cp
       where cp.id = phase_id
         and (is_campaign_member(cp.campaign_id) or is_platform_admin())
    )
  );

create policy "organisers manage phase missions" on campaign_phase_missions
  for all to authenticated
  using (
    exists (
      select 1 from campaign_phases cp
       where cp.id = phase_id
         and (is_campaign_organiser(cp.campaign_id) or is_platform_admin())
    )
  )
  with check (
    exists (
      select 1 from campaign_phases cp
       where cp.id = phase_id
         and (is_campaign_organiser(cp.campaign_id) or is_platform_admin())
    )
  );

-- ---------------------------------------------------------------------------
-- games.phase_id -- which phase (if any) a logged game counted toward
-- ---------------------------------------------------------------------------
-- Defensive re-assertion of 019_add_mission_to_games.sql's column -- if that
-- migration was never actually run against this database (confirmed missing
-- live, "column mission_id does not exist" while running this file), the
-- unique index below needs it to exist regardless of that history.
alter table games add column if not exists mission_id uuid references missions(id) on delete set null;
alter table games add column if not exists phase_id uuid references campaign_phases(id) on delete set null;

-- Stops the same player double-submitting the same mission within one
-- phase (accidental double-click, or a client bug) -- the actual "which
-- missions are still available" gating is computed client-side from this
-- same (phase_id, player_id, mission_id) shape, this index just backstops it
-- at the database level.
drop index if exists one_game_per_phase_mission_per_player;
create unique index one_game_per_phase_mission_per_player on games (phase_id, player_id, mission_id) where phase_id is not null;

create or replace function log_game_with_xp(p_game jsonb)
returns bigint
language plpgsql
security invoker
as $function$
declare
  new_game_id bigint;
  credit jsonb;
  v_campaign_id uuid;
begin
  v_campaign_id := nullif(p_game->>'campaign_id', '')::uuid;

  if v_campaign_id is null then
    raise exception 'campaign_id is required to log a battle.';
  end if;

  if not is_campaign_member(v_campaign_id) then
    raise exception 'You are not a member of that campaign.';
  end if;

  insert into games (
    campaign_id, player_id, opponent_id, opponent_name, result, glory_points,
    scenario, mission_id, phase_id, trait_objective_id, trait_objective_met, played_on, notes,
    opponent_unit_outcomes, kill_credits
  )
  values (
    v_campaign_id,
    auth.uid(),
    nullif(p_game->>'opponent_id', '')::uuid,
    nullif(p_game->>'opponent_name', ''),
    (p_game->>'result')::game_result,
    coalesce((p_game->>'glory_points')::integer, 0),
    nullif(p_game->>'scenario', ''),
    nullif(p_game->>'mission_id', '')::uuid,
    nullif(p_game->>'phase_id', '')::uuid,
    nullif(p_game->>'trait_objective_id', '')::bigint,
    coalesce((p_game->>'trait_objective_met')::boolean, false),
    coalesce(nullif(p_game->>'played_on', '')::date, current_date),
    nullif(p_game->>'notes', ''),
    case when jsonb_typeof(p_game->'opponent_unit_outcomes') = 'array'
         then p_game->'opponent_unit_outcomes' else null end,
    case when jsonb_typeof(p_game->'kill_credits') = 'array'
         then p_game->'kill_credits' else null end
  )
  returning id into new_game_id;

  -- 1 XP per credited kill, applied to the logger's own units. Row level
  -- security means an update against anyone else's unit simply matches
  -- nothing -- it cannot award XP across players.
  for credit in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_game->'kill_credits') = 'array'
           then p_game->'kill_credits' else '[]'::jsonb end)
  loop
    update units
       set experience = experience + coalesce((credit->>'amount')::integer, 0),
           updated_at = now()
     where id = (credit->>'unitId')::bigint;
  end loop;

  return new_game_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- free_play_log -- deliberately minimal, never touches XP/Glory/standings
-- ---------------------------------------------------------------------------
create table if not exists free_play_log (
  id            uuid primary key default gen_random_uuid(),
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  user_id       uuid not null references players(id) on delete cascade,
  played_on     date not null default current_date,
  created_at    timestamptz not null default now()
);

comment on table free_play_log is 'A marker that a player used the Game View mechanics without it counting toward the campaign -- no mission/opponent/result recorded on purpose. Shown as a lightweight non-scoring line in that player''s own battle log.';

create index if not exists free_play_log_campaign_user_idx on free_play_log (campaign_id, user_id);

alter table free_play_log enable row level security;

drop policy if exists "players read their own free play log" on free_play_log;
drop policy if exists "players add their own free play log" on free_play_log;
drop policy if exists "players delete their own free play log" on free_play_log;

create policy "players read their own free play log" on free_play_log
  for select to authenticated
  using (is_campaign_member(campaign_id));

create policy "players add their own free play log" on free_play_log
  for insert to authenticated
  with check (user_id = auth.uid() and is_campaign_member(campaign_id));

create policy "players delete their own free play log" on free_play_log
  for delete to authenticated
  using (user_id = auth.uid());
