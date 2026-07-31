-- ============================================================================
-- 041_fix_audit_log_campaign_id_lookup.sql
--
-- Fixes: removing a player from a campaign (and any other write to
-- campaign_members) fails with "record 'new' has no field 'id'".
--
-- log_admin_audit() (029_admin_audit_log.sql) is one shared trigger function
-- attached to seven tables. Its own comment already explains why every field
-- access on NEW/OLD has to go through to_jsonb(...)->>'...' rather than dot
-- notation -- PL/pgSQL's plan cache for a shared trigger function isn't
-- guaranteed to be keyed per actual row type, so a direct NEW.field
-- reference can error even when that CASE branch isn't the one logically
-- selected for the table currently firing. The games/player_id check
-- already followed that rule -- the v_campaign_id lookup's 'campaigns'
-- branch was the one spot that didn't, and campaign_members (a composite
-- key of user_id + campaign_id, no id column at all) is exactly the table
-- that trips it.
--
-- Idempotent: safe to re-run. Run after 040.
-- ============================================================================

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

  if TG_TABLE_NAME = 'games' and coalesce(
    (to_jsonb(NEW)->>'player_id')::uuid, (to_jsonb(OLD)->>'player_id')::uuid
  ) = v_actor then
    return coalesce(NEW, OLD); -- players managing their own battles, not an admin action
  end if;

  v_campaign_id := case TG_TABLE_NAME
    when 'campaigns' then coalesce((to_jsonb(NEW)->>'id')::uuid, (to_jsonb(OLD)->>'id')::uuid)
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
