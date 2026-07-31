-- ============================================================================
-- 043_alliance_point_adjustments.sql
--
-- Lets an organiser hand out (or claw back) campaign points to a whole
-- alliance directly, for event rules that award points outside of normal
-- battle logging (e.g. "the alliance holding the most territory at the end
-- of the day gets +50"). A log of adjustments, not a single overwritable
-- number on alliances itself, so there's a visible trail of who added what
-- and why, and nothing is ever silently lost by one admin overwriting
-- another's entry.
--
-- Deliberately doesn't touch alliance_standings (023) or games at all --
-- an alliance's displayed total is battle-derived campaign_points (that
-- view) plus the sum of its adjustments here, added together client-side.
-- Keeps the existing player-facing Campaign standings tab exactly as it
-- was; this is purely additive, surfaced in Admin Overview.
--
-- alliance_id is text (alliances.id is a slugified name, not a uuid --
-- see index.html's renderAdminAlliances/`id: slugify(name)`).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists alliance_point_adjustments (
  id            uuid primary key default gen_random_uuid(),
  alliance_id   text not null references alliances(id) on delete cascade,
  campaign_id   uuid not null references campaigns(id) on delete cascade,
  amount        integer not null,
  reason        text,
  created_by    uuid references players(id) on delete set null,
  created_at    timestamptz not null default now()
);

comment on table alliance_point_adjustments is 'Manual campaign-point bonuses/penalties an organiser awards to a whole alliance, outside normal battle logging. amount may be negative (a penalty or correction).';

create index if not exists alliance_point_adjustments_alliance_id_idx on alliance_point_adjustments (alliance_id);
create index if not exists alliance_point_adjustments_campaign_id_idx on alliance_point_adjustments (campaign_id);

alter table alliance_point_adjustments enable row level security;

drop policy if exists "campaign members can read alliance point adjustments" on alliance_point_adjustments;
create policy "campaign members can read alliance point adjustments" on alliance_point_adjustments
  for select to authenticated
  using (is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "organisers manage alliance point adjustments" on alliance_point_adjustments;
create policy "organisers manage alliance point adjustments" on alliance_point_adjustments
  for all to authenticated
  using (is_campaign_organiser(campaign_id) or is_platform_admin())
  with check (is_campaign_organiser(campaign_id) or is_platform_admin());
