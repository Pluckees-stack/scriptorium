-- ============================================================================
-- 091_draft_round_scenarios.sql
--
-- The event builder now picks a scenario for each round of a tournament.
-- save_campaign_draft (088) makes the draft's tournament; this stages its
-- per-round picks on tournaments.round_scenarios (060/061), which Lock
-- Entrants copies onto each round as it does now. Separate from
-- save_campaign_draft so the draft's creator can do it before they have
-- two-factor login, like the rest of the builder.
--
-- p_scenarios: a jsonb array, index i = round i+1, each a missions.id or
-- null ("choose later"). Scenarios not in the library or this campaign are
-- dropped to null.
--
-- To undo:
--   drop function if exists set_draft_round_scenarios(uuid, jsonb);
-- ============================================================================

create or replace function set_draft_round_scenarios(p_campaign uuid, p_scenarios jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_tid uuid;
  v_out jsonb := '[]'::jsonb;
  v_item jsonb;
  v_mid uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if not can_build_campaign(p_campaign) then
    raise exception 'Only an organiser of this event can change it.';
  end if;
  if not exists (select 1 from campaigns where id = p_campaign and status = 'draft') then
    raise exception 'This event is already open. Choose round scenarios in Events › Tournaments instead.';
  end if;
  if jsonb_typeof(p_scenarios) <> 'array' then raise exception 'Choose a scenario for each round, or leave it for later.'; end if;
  if jsonb_array_length(p_scenarios) > 10 then raise exception 'A tournament can have up to 10 rounds.'; end if;

  select id into v_tid from tournaments
   where campaign_id = p_campaign and status = 'setup' and entrants_locked_at is null
   order by created_at limit 1;
  if v_tid is null then return; end if;

  for v_item in select * from jsonb_array_elements(p_scenarios) loop
    v_mid := null;
    if jsonb_typeof(v_item) = 'string' and (v_item #>> '{}') ~* '^[0-9a-f-]{36}$' then
      select m.id into v_mid from missions m
       where m.id = (v_item #>> '{}')::uuid and (m.campaign_id is null or m.campaign_id = p_campaign);
    end if;
    v_out := v_out || jsonb_build_array(case when v_mid is null then 'null'::jsonb
                                             else jsonb_build_object('perTable', false, 'missionId', v_mid) end);
  end loop;

  update tournaments set round_scenarios = v_out where id = v_tid;
end;
$$;
revoke all on function set_draft_round_scenarios(uuid, jsonb) from public, anon;
grant execute on function set_draft_round_scenarios(uuid, jsonb) to authenticated;
