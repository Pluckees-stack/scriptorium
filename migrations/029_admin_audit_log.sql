-- ============================================================================
-- 029_admin_audit_log.sql
--
-- admin_audit_log -- who did what, campaign-scoped, for the admin tables that
-- can only be written by an organiser/platform admin in the first place
-- (alliances, missions, trait_objectives, campaign_phases, campaigns), plus
-- the two places where an organiser now acts on data that isn't theirs:
-- campaign_members (promote/demote/alliance-assign/remove -- via
-- 011's SECURITY DEFINER functions) and games (the migrations/028 admin
-- override). With multiple organisers on a campaign there was previously no
-- record of who removed a player or deleted a mission.
--
-- Deliberately trigger-based, not logged from the client in index.html: a
-- trigger can't be skipped by forgetting to add a log call at one of the
-- ~15 admin write sites, and it still fires no matter which path (RPC or
-- direct RLS-gated write) the change came through.
--
-- Deliberately NOT logging ordinary player activity through the same
-- tables:
--   - campaign_members INSERT is a player joining themselves -- not an
--     admin action, skipped.
--   - games: only logged when the actor differs from the game's own
--     player_id, i.e. an organiser acting on someone else's battle via
--     028's override. A player editing/deleting their own battle (already
--     permitted by the pre-existing "players manage their own games"
--     policy) is routine self-service, not something an audit trail is for.
--
-- RLS: readable by that campaign's organiser or a platform admin, same as
-- the tables it's watching. No client write policy at all -- the trigger
-- function is SECURITY DEFINER, so it can insert here even though
-- `authenticated` has no direct grant on this table; that's the only path
-- rows can enter it.
--
-- Idempotent: safe to re-run. Run after 009 (is_campaign_organiser/
-- is_platform_admin) and 028 (games admin override).
-- ============================================================================

create table if not exists admin_audit_log (
  id bigint generated always as identity primary key,
  campaign_id uuid references campaigns(id) on delete cascade,
  table_name text not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  row_id text,
  actor_id uuid references auth.users(id),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_campaign_id_idx on admin_audit_log (campaign_id, created_at desc);

alter table admin_audit_log enable row level security;

drop policy if exists "organisers can read their campaign's audit log" on admin_audit_log;
create policy "organisers can read their campaign's audit log" on admin_audit_log
  for select
  using (is_campaign_organiser(campaign_id) or is_platform_admin());

create or replace function log_admin_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_row_id text;
  v_actor uuid := auth.uid();
begin
  if TG_TABLE_NAME = 'campaign_members' and TG_OP = 'INSERT' then
    return coalesce(NEW, OLD); -- self-join, not an admin action
  end if;

  -- Field access goes through to_jsonb()->>'...' rather than NEW.player_id
  -- directly: this function is shared across tables with different
  -- columns, and AND/OR operand evaluation order isn't guaranteed by
  -- Postgres, so a direct NEW.player_id reference could be evaluated (and
  -- error, "record has no field") even on a table that isn't 'games'.
  -- jsonb key lookup on a missing key just returns null instead, which is
  -- always safe.
  if TG_TABLE_NAME = 'games' and coalesce(
    (to_jsonb(NEW)->>'player_id')::uuid, (to_jsonb(OLD)->>'player_id')::uuid
  ) = v_actor then
    return coalesce(NEW, OLD); -- players managing their own battles, not an admin action
  end if;

  v_campaign_id := case TG_TABLE_NAME
    when 'campaigns' then coalesce(NEW.id, OLD.id)
    else coalesce(
      (to_jsonb(NEW)->>'campaign_id')::uuid,
      (to_jsonb(OLD)->>'campaign_id')::uuid
    )
  end;

  v_row_id := coalesce(to_jsonb(NEW)->>'id', to_jsonb(OLD)->>'id');

  insert into admin_audit_log (campaign_id, table_name, action, row_id, actor_id, old_data, new_data)
  values (
    v_campaign_id, TG_TABLE_NAME, TG_OP, v_row_id, v_actor,
    case when TG_OP <> 'INSERT' then to_jsonb(OLD) else null end,
    case when TG_OP <> 'DELETE' then to_jsonb(NEW) else null end
  );

  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists audit_campaign_members on campaign_members;
create trigger audit_campaign_members after insert or update or delete on campaign_members
  for each row execute function log_admin_audit();

drop trigger if exists audit_alliances on alliances;
create trigger audit_alliances after insert or update or delete on alliances
  for each row execute function log_admin_audit();

drop trigger if exists audit_missions on missions;
create trigger audit_missions after insert or update or delete on missions
  for each row execute function log_admin_audit();

drop trigger if exists audit_trait_objectives on trait_objectives;
create trigger audit_trait_objectives after insert or update or delete on trait_objectives
  for each row execute function log_admin_audit();

drop trigger if exists audit_campaign_phases on campaign_phases;
create trigger audit_campaign_phases after insert or update or delete on campaign_phases
  for each row execute function log_admin_audit();

drop trigger if exists audit_campaigns on campaigns;
create trigger audit_campaigns after insert or update on campaigns
  for each row execute function log_admin_audit();

drop trigger if exists audit_games on games;
create trigger audit_games after update or delete on games
  for each row execute function log_admin_audit();
