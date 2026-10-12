-- ============================================================================
-- 073_unit_photos.sql
--
-- Photos of players' own models, one per unit, shown on the unit's card in
-- Game view and in its Muster details.
--
-- 1. units.photo_path -- the object's path in the unit-photos bucket
--    ("{user_id}/{unit_id}-{timestamp}.webp"), or null. index.html turns it
--    into a public URL with getPublicUrl().
-- 2. The unit-photos bucket: public (like map-images, 037), so an <img> can
--    load a photo straight from its URL, with no listing policy (see 046) so
--    nobody can browse the bucket. 2MB cap and image types only; index.html
--    shrinks photos to about 1280px before upload, so real ones are far
--    smaller.
-- 3. Each player may add, replace and delete objects only inside their own
--    folder (the first path segment must be their auth.uid()). The select
--    policy is needed for upsert and delete, and is limited to their own
--    folder too.
--
-- RUN THIS BEFORE merging the unit-photos index.html: that page asks for
-- units.photo_path when it loads rosters, and would fail without it.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table units add column if not exists photo_path text;
comment on column units.photo_path is 'Path of this unit''s photo in the unit-photos storage bucket, or null.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('unit-photos', 'unit-photos', true, 2097152, array['image/webp', 'image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "players read their own unit photos" on storage.objects;
create policy "players read their own unit photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'unit-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players upload their own unit photos" on storage.objects;
create policy "players upload their own unit photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'unit-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players replace their own unit photos" on storage.objects;
create policy "players replace their own unit photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'unit-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'unit-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players delete their own unit photos" on storage.objects;
create policy "players delete their own unit photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'unit-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
