-- ============================================================================
-- 094_draft_settings.sql
--
-- The event builder now asks for the kind of battles: normal battles or
-- Battle March. It's kept in campaigns.settings.battle_type and decides which
-- scenarios are offered and how the scenario builder opens. save_campaign_draft
-- (088) only keeps its own settings keys, and a draft's creator may not have
-- two-factor login yet (so can't update campaigns directly), so this sets the
-- builder's other settings on a draft.
--
-- p_patch: a jsonb object of settings to merge. Only these keys are taken:
--   battle_type: 'normal' or 'battle-march'
-- Anything else is ignored.
--
-- To undo:
--   drop function if exists set_draft_settings(uuid, jsonb);
-- ============================================================================

create or replace function set_draft_settings(p_campaign uuid, p_patch jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_add jsonb := '{}'::jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if not can_build_campaign(p_campaign) then
    raise exception 'Only an organiser of this event can change it.';
  end if;
  if not exists (select 1 from campaigns where id = p_campaign and status = 'draft') then
    raise exception 'This event is already open. Change it from the admin tabs instead.';
  end if;
  if jsonb_typeof(p_patch) <> 'object' then return; end if;

  if p_patch->>'battle_type' in ('normal', 'battle-march') then
    v_add := v_add || jsonb_build_object('battle_type', p_patch->>'battle_type');
  end if;

  update campaigns set settings = coalesce(settings, '{}'::jsonb) || v_add where id = p_campaign;
end;
$$;
revoke all on function set_draft_settings(uuid, jsonb) from public, anon;
grant execute on function set_draft_settings(uuid, jsonb) to authenticated;
