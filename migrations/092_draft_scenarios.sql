-- ============================================================================
-- 092_draft_scenarios.sql
--
-- The event builder now opens the scenario builder, so an organiser can
-- make their own scenarios while setting up an event. The event doesn't
-- exist until Create event, so the builder holds them until then and saves
-- them here, against the new draft, in one go.
--
-- Missions are normally written by organisers through RLS, which needs
-- two-factor login (072/074); a draft's creator may not have it yet, like
-- the rest of the builder (088), so this checks can_build_campaign instead.
--
-- p_scenarios: a jsonb array of missions rows as the scenario builder
-- builds them (buildMissionPayload in index.html). Each is saved with this
-- campaign, its creator and the table's defaults for anything left out.
-- id, campaign_id, created_by and created_at are always ours; custom
-- objectives belong to a campaign that exists, so none come across.
-- Returns the new ids, in the order sent.
--
-- To undo:
--   drop function if exists save_draft_scenarios(uuid, jsonb);
-- ============================================================================

create or replace function save_draft_scenarios(p_campaign uuid, p_scenarios jsonb)
returns uuid[] language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_item jsonb;
  v_name text;
  v_row missions%rowtype;
  v_ids uuid[] := '{}';
begin
  if v_uid is null then raise exception 'Sign in first.'; end if;
  if not can_build_campaign(p_campaign) then
    raise exception 'Only an organiser of this event can add scenarios to it.';
  end if;
  if not exists (select 1 from campaigns where id = p_campaign and status = 'draft') then
    raise exception 'This event is already open. Add scenarios in the Scenarios tab instead.';
  end if;
  if jsonb_typeof(p_scenarios) <> 'array' then raise exception 'No scenarios to save.'; end if;
  if jsonb_array_length(p_scenarios) > 20 then raise exception 'Up to 20 new scenarios at a time.'; end if;
  if length(p_scenarios::text) > 200000 then raise exception 'These scenarios are too long to save. Try trimming their text.'; end if;

  for v_item in select * from jsonb_array_elements(p_scenarios) loop
    v_name := nullif(left(trim(coalesce(v_item->>'name', '')), 120), '');
    if v_name is null then raise exception 'Every new scenario needs a name.'; end if;

    -- a row with the table's defaults, then the scenario's own fields on top
    insert into missions (name, campaign_id, created_by) values (v_name, p_campaign, v_uid)
    returning * into v_row;
    v_row := jsonb_populate_record(v_row, v_item - 'id' - 'campaign_id' - 'created_by' - 'created_at' - 'custom_objective_ids');
    v_row.name := v_name;
    v_row.campaign_id := p_campaign;
    v_row.created_by := v_uid;
    delete from missions where id = v_row.id;
    insert into missions select v_row.*;
    v_ids := v_ids || v_row.id;
  end loop;
  return v_ids;
end;
$$;
revoke all on function save_draft_scenarios(uuid, jsonb) from public, anon;
grant execute on function save_draft_scenarios(uuid, jsonb) to authenticated;
