-- ============================================================================
-- 011_campaign_membership_admin_functions.sql
--
-- Phase 2, part 3.
--
-- campaign_members.role/alliance_id/tier are REVOKEd from `authenticated`
-- entirely (010_rls_policies_all_tables.sql). Postgres RLS can't express
-- "self can write column A but not column B, while an organiser can write
-- both, on the same row, for the same database role" in a single UPDATE
-- policy -- RLS decides which ROWS a policy applies to, not which COLUMNS
-- within an allowed row. These four SECURITY DEFINER functions are the
-- privileged escape hatch: they run as the function owner, which bypasses
-- the column REVOKE the same way SECURITY DEFINER bypasses RLS, after
-- re-checking authorisation themselves internally. There is no direct
-- UPDATE path to these three columns for anyone, including organisers --
-- only through these functions.
--
-- search_path is pinned, same hardening reasoning as 009.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function set_campaign_member_role(p_campaign_id uuid, p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can change member roles.';
  end if;
  if p_role not in ('organiser', 'player') then
    raise exception 'Role must be organiser or player.';
  end if;

  update campaign_members
     set role = p_role
   where campaign_id = p_campaign_id
     and user_id = p_user_id;

  if not found then
    raise exception 'That user is not a member of this campaign.';
  end if;
end;
$$;

create or replace function set_campaign_member_alliance(p_campaign_id uuid, p_user_id uuid, p_alliance_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can assign alliances.';
  end if;
  if p_alliance_id is not null and not exists (
    select 1 from alliances where id = p_alliance_id and campaign_id = p_campaign_id
  ) then
    raise exception 'That alliance does not belong to this campaign.';
  end if;

  update campaign_members
     set alliance_id = p_alliance_id
   where campaign_id = p_campaign_id
     and user_id = p_user_id;

  if not found then
    raise exception 'That user is not a member of this campaign.';
  end if;
end;
$$;

create or replace function set_campaign_member_tier(p_campaign_id uuid, p_user_id uuid, p_tier player_tier)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can set a member''s tier.';
  end if;

  update campaign_members
     set tier = p_tier
   where campaign_id = p_campaign_id
     and user_id = p_user_id;

  if not found then
    raise exception 'That user is not a member of this campaign.';
  end if;
end;
$$;

create or replace function remove_campaign_member(p_campaign_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_campaign_organiser(p_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can remove a member.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Use the leave-campaign action to remove yourself.';
  end if;

  delete from campaign_members
   where campaign_id = p_campaign_id
     and user_id = p_user_id;

  if not found then
    raise exception 'That user is not a member of this campaign.';
  end if;
end;
$$;

revoke all on function set_campaign_member_role(uuid, uuid, text) from public;
revoke all on function set_campaign_member_alliance(uuid, uuid, text) from public;
revoke all on function set_campaign_member_tier(uuid, uuid, player_tier) from public;
revoke all on function remove_campaign_member(uuid, uuid) from public;
grant execute on function set_campaign_member_role(uuid, uuid, text) to authenticated;
grant execute on function set_campaign_member_alliance(uuid, uuid, text) to authenticated;
grant execute on function set_campaign_member_tier(uuid, uuid, player_tier) to authenticated;
grant execute on function remove_campaign_member(uuid, uuid) to authenticated;
