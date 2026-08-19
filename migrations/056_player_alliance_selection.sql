-- ============================================================================
-- 056_player_alliance_selection.sql
--
-- Alliances (team groupings for campaign standings) could previously only
-- be assigned by an organiser, via set_campaign_member_alliance
-- (migrations/011). This lets a player pick their own from Muster List
-- instead -- a new, narrow RPC scoped to auth.uid() rather than loosening
-- the existing organiser-only one, which stays exactly as strict as it
-- is today.
--
-- alliance_selection_locked lets an organiser freeze this once teams are
-- settled -- defaults open (false) so self-service works immediately for
-- campaigns that never bother locking it. An organiser can always still
-- reassign anyone via the existing Membership tooling regardless of the
-- lock (that RPC has no lock check -- it's their own lock to override).
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table campaigns add column if not exists alliance_selection_locked boolean not null default false;

comment on column campaigns.alliance_selection_locked is 'When true, players can no longer change their own alliance from Muster List (set_my_alliance below refuses). Organisers can still reassign anyone from Membership regardless.';

create or replace function set_my_alliance(p_campaign_id uuid, p_alliance_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_campaign_member(p_campaign_id) then
    raise exception 'You are not a member of that campaign.';
  end if;
  if exists (select 1 from campaigns where id = p_campaign_id and alliance_selection_locked) then
    raise exception 'The organiser has locked alliance selection for this campaign.';
  end if;
  if p_alliance_id is not null and not exists (
    select 1 from alliances where id = p_alliance_id and campaign_id = p_campaign_id
  ) then
    raise exception 'That alliance does not belong to this campaign.';
  end if;

  update campaign_members
     set alliance_id = p_alliance_id
   where campaign_id = p_campaign_id
     and user_id = auth.uid();
end;
$$;

revoke all on function set_my_alliance(uuid, text) from public;
grant execute on function set_my_alliance(uuid, text) to authenticated;
