-- ============================================================================
-- 030_alliance_emblem.sql
--
-- alliances.emblem_url -- optional image for an alliance, shown as a small
-- roundel next to its name in Player Admin and on the standings hub. Same
-- shape as narrative_pages.image_url (026_narrative_updates.sql): a plain
-- pasted URL, not a Supabase Storage upload -- this app has no upload
-- pipeline anywhere yet, and one column is enough to match that existing
-- convention rather than stand up storage/RLS for it.
--
-- No RLS change needed: alliances' existing "organiser of that campaign, or
-- platform admin/superadmin" ALL policy already covers this column.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table alliances add column if not exists emblem_url text;

comment on column alliances.emblem_url is 'Optional pasted image URL shown as a small roundel next to the alliance name. Null falls back to a plain colour swatch (the existing alliances.colour column).';

-- alliance_standings (most recently redefined in 023) gains emblem_url as a
-- new trailing output column -- CREATE OR REPLACE VIEW can append columns
-- without a drop (per 007's header comment on why campaign_points/glory_points
-- needed a full drop+recreate instead, since that was a rename), but ONLY at
-- the true end: every pre-existing column must keep both its name AND its
-- ordinal position, or Postgres reads it as a rename of whatever column now
-- sits in that slot (confirmed live: inserting emblem_url before `members`
-- errored with "cannot change name of view column 'members' to
-- 'emblem_url'", 42P16, because it shifted every column after it along by
-- one). emblem_url goes after campaign_id, the view's actual last column.
create or replace view alliance_standings as
select a.id,
       a.name,
       a.colour,
       count(distinct cm.user_id) as members,
       coalesce(sum(g.campaign_points), 0::bigint) as campaign_points,
       count(g.id) filter (where g.result = 'win'::game_result) as wins,
       count(g.id) filter (where g.result = 'loss'::game_result) as losses,
       count(g.id) filter (where g.result = 'draw'::game_result) as draws,
       a.campaign_id,
       a.emblem_url
  from alliances a
  left join campaign_members cm on cm.alliance_id = a.id and cm.campaign_id = a.campaign_id
  left join games g on g.player_id = cm.user_id and g.campaign_id = a.campaign_id
 group by a.id
 order by coalesce(sum(g.campaign_points), 0::bigint) desc;
