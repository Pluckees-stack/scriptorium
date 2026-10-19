-- ============================================================================
-- 095_tournament_scoring.sql
--
-- Tournament scoring and comp (admin console PR C2). The rules themselves
-- (scoring preset, byes, tiebreaks, pairing options, soft scores, comp
-- tiers) live in campaigns.settings.scoring, which organisers already
-- write; this adds what belongs to players:
--
-- 1. players.club: a player's club, set in Account, so pairings can keep
--    clubmates apart.
-- 2. campaign_members.sbc_tier: the player's Square Based Comp tier for this
--    event, which they pick on their Lists page and an organiser can
--    correct. Set through set_sbc_tier (yourself, or an organiser).
-- 3. set_draft_settings (094) also takes a starting `scoring` object, so a
--    tournament made in the event builder starts on the official scoring.
--
-- To undo:
--   drop function if exists set_sbc_tier(uuid, uuid, text);
--   alter table campaign_members drop column if exists sbc_tier;
--   alter table players drop column if exists club;
--   then re-run set_draft_settings from 094.
-- ============================================================================

alter table players add column if not exists club text check (club is null or length(club) <= 60);
comment on column players.club is 'The player''s club, set in Account; tournaments can avoid pairing clubmates.';

alter table campaign_members add column if not exists sbc_tier text check (sbc_tier is null or length(sbc_tier) <= 40);
comment on column campaign_members.sbc_tier is 'Square Based Comp tier for this event (a name from campaigns.settings.scoring.comp.tiers), picked by the player or set by an organiser.';

create or replace function set_sbc_tier(p_campaign uuid, p_user uuid, p_tier text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if not (p_user = auth.uid() or is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only the player or an organiser can set their tier.';
  end if;
  if p_user = auth.uid() and exists (select 1 from campaigns where id = p_campaign and lists_locked)
     and not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Lists are locked for this event. Ask the organiser if your tier needs changing.';
  end if;
  update campaign_members set sbc_tier = nullif(left(trim(coalesce(p_tier, '')), 40), '')
   where campaign_id = p_campaign and user_id = p_user;
  if not found then raise exception 'That player isn''t in this event.'; end if;
end;
$$;
revoke all on function set_sbc_tier(uuid, uuid, text) from public, anon;
grant execute on function set_sbc_tier(uuid, uuid, text) to authenticated;

-- set_draft_settings, as in 094, plus a starting scoring object
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
  if jsonb_typeof(p_patch->'scoring') = 'object' and length((p_patch->'scoring')::text) <= 20000 then
    v_add := v_add || jsonb_build_object('scoring', p_patch->'scoring');
  end if;

  update campaigns set settings = coalesce(settings, '{}'::jsonb) || v_add where id = p_campaign;
end;
$$;
revoke all on function set_draft_settings(uuid, jsonb) from public, anon;
grant execute on function set_draft_settings(uuid, jsonb) to authenticated;
