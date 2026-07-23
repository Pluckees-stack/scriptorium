-- ============================================================================
-- 037_mission_maps.sql
--
-- Backs the new "Deployment map" step of the Mission Admin creation wizard:
-- maps become a real table (name + image) instead of the hardcoded
-- MISSION_MAPS/MISSION_MAP_IMAGES lists in index.html, so organisers can
-- upload their own custom maps alongside the 11 built-in ones. Same
-- official/campaign-custom hybrid as missions and trait_objectives
-- (campaign_id null = official, visible in every campaign).
--
-- missions.deployment_type keeps storing the map's *name* as free text,
-- unchanged -- existing missions' values already match the 11 built-in
-- map names seeded below, so no backfill is needed on missions itself.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists maps (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  image_path   text not null,   -- static "assets/maps/..." path (built-ins) or a Storage public URL (uploads)
  campaign_id  uuid references campaigns(id) on delete cascade,
  created_by   uuid references players(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists maps_campaign_id_idx on maps (campaign_id);
alter table maps enable row level security;

drop policy if exists "read official or own-campaign maps" on maps;
create policy "read official or own-campaign maps" on maps
  for select to authenticated
  using (campaign_id is null or is_campaign_member(campaign_id) or is_platform_admin());

drop policy if exists "admins manage official maps" on maps;
create policy "admins manage official maps" on maps
  for all to authenticated
  using (campaign_id is null and is_platform_admin())
  with check (campaign_id is null and is_platform_admin());

drop policy if exists "organisers manage campaign maps" on maps;
create policy "organisers manage campaign maps" on maps
  for all to authenticated
  using (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()))
  with check (campaign_id is not null and (is_campaign_organiser(campaign_id) or is_platform_admin()));

-- seed the 11 existing built-in maps as official rows, once only
insert into maps (name, image_path, campaign_id)
select v.name, v.image_path, null
from (values
  ('Break Point', 'assets/maps/break-point.jpeg'),
  ('Chance Encounter', 'assets/maps/chance-encounter.jpg'),
  ('Close Quarters', 'assets/maps/close-quarters.jpg'),
  ('Command and Control', 'assets/maps/command-and-control.jpeg'),
  ('Drawn Battle Lines', 'assets/maps/drawn-battle-lines.jpg'),
  ('Encirclement', 'assets/maps/encirclement.jpg'),
  ('Flank Attack', 'assets/maps/flank-attack.jpeg'),
  ('King of the Hill', 'assets/maps/king-of-the-hill.jpg'),
  ('Meeting Engagement', 'assets/maps/meeting-engagement.jpeg'),
  ('Mountain Pass', 'assets/maps/mountain-pass.jpeg'),
  ('Open War', 'assets/maps/open-war.jpg')
) as v(name, image_path)
where not exists (select 1 from maps where campaign_id is null);

-- storage bucket for uploaded map images, path convention "{campaign_id}/{uuid}-{filename}"
insert into storage.buckets (id, name, public) values ('map-images', 'map-images', true)
on conflict (id) do nothing;

drop policy if exists "map images public read" on storage.objects;
create policy "map images public read" on storage.objects
  for select using (bucket_id = 'map-images');

drop policy if exists "organisers upload campaign map images" on storage.objects;
create policy "organisers upload campaign map images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'map-images' and is_campaign_organiser(((storage.foldername(name))[1])::uuid));
