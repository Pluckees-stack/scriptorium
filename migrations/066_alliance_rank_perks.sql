-- ============================================================================
-- 066_alliance_rank_perks.sql
--
-- Awards a narrative rule to the top 3 alliances (by Campaign Points) when
-- a phase/round is marked completed -- e.g. 1st place gets "Quenched" (a
-- special rule), 2nd "Thirsty", 3rd "Parched". The three names/rule-texts
-- are a reusable campaign template (campaigns.rank_perks) the organiser
-- edits once -- only which alliance holds each slot changes each phase.
-- "Mark completed" snapshots the template's current wording onto whichever
-- alliances are 1st/2nd/3rd at that moment (phase_alliance_perks), so
-- editing the template later never rewrites a past award. The most
-- recently completed phase's rows are what's "currently active" -- index.html
-- reads them that way, nothing here tracks "active" explicitly.
--
-- alliance_id is text (alliances.id is a slugified name, not a uuid --
-- same as migrations/043's alliance_point_adjustments).
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table campaigns add column if not exists rank_perks jsonb not null default '[]'::jsonb;
comment on column campaigns.rank_perks is 'Reusable per-rank perk template, index 0 = 1st place, 1 = 2nd, 2 = 3rd: [{name, rule_text}, ...]. Snapshotted onto phase_alliance_perks when a phase is marked completed -- editing this later does not change past awards.';

create table if not exists phase_alliance_perks (
  id           uuid primary key default gen_random_uuid(),
  campaign_id  uuid not null references campaigns(id) on delete cascade,
  phase_id     uuid not null references campaign_phases(id) on delete cascade,
  alliance_id  text not null references alliances(id) on delete cascade,
  rank         integer not null check (rank between 1 and 3),
  name         text not null,
  rule_text    text not null,
  awarded_at   timestamptz not null default now(),
  unique (phase_id, rank)
);
comment on table phase_alliance_perks is 'Which alliance held which rank_perks-template slot when a phase completed -- a snapshot (name/rule_text copied in, not a live join to campaigns.rank_perks), so editing the template later never rewrites past awards.';

create index if not exists phase_alliance_perks_campaign_id_idx on phase_alliance_perks (campaign_id);
create index if not exists phase_alliance_perks_phase_id_idx on phase_alliance_perks (phase_id);

alter table phase_alliance_perks enable row level security;

drop policy if exists "campaign members can read alliance rank perks" on phase_alliance_perks;
create policy "campaign members can read alliance rank perks" on phase_alliance_perks
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

-- No client insert/update/delete policy -- only complete_phase_and_award_perks
-- (below, security definer, re-checks organiser/admin itself) ever writes
-- this table. Nothing else should.

-- Replaces the plain "update campaign_phases set status='completed'" the
-- client used to do directly -- now goes through this so the perk award is
-- atomic with completing the phase, using the same ranking order
-- alliance_standings (050) and the player-facing Standings tab already use.
create or replace function complete_phase_and_award_perks(p_phase_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_template jsonb;
  v_rank int;
  v_alliance record;
begin
  select campaign_id into v_campaign_id from campaign_phases where id = p_phase_id;
  if v_campaign_id is null then
    raise exception 'Phase not found.';
  end if;
  if not (is_campaign_organiser(v_campaign_id) or is_platform_admin()) then
    raise exception 'Only an organiser of this campaign, or a platform admin, can complete a phase.';
  end if;

  update campaign_phases set status = 'completed', completed_at = now() where id = p_phase_id;

  select rank_perks into v_template from campaigns where id = v_campaign_id;
  if v_template is null then v_template := '[]'::jsonb; end if;

  v_rank := 1;
  for v_alliance in
    select id from alliance_standings where campaign_id = v_campaign_id order by campaign_points desc, id limit 3
  loop
    if jsonb_array_length(v_template) >= v_rank
       and coalesce(v_template -> (v_rank - 1) ->> 'name', '') <> '' then
      insert into phase_alliance_perks (campaign_id, phase_id, alliance_id, rank, name, rule_text)
      values (
        v_campaign_id, p_phase_id, v_alliance.id, v_rank,
        v_template -> (v_rank - 1) ->> 'name',
        coalesce(v_template -> (v_rank - 1) ->> 'rule_text', '')
      )
      on conflict (phase_id, rank) do nothing;
    end if;
    v_rank := v_rank + 1;
  end loop;
end;
$$;

revoke all on function complete_phase_and_award_perks(uuid) from public;
grant execute on function complete_phase_and_award_perks(uuid) to authenticated;
