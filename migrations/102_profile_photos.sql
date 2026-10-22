-- ============================================================================
-- 102_profile_photos.sql
--
-- Profile photos: each player can add a photo of themselves (Account ›
-- Profile), shown wherever the app draws a person (the header button, the
-- chronicle, list headers, WarCastle pieces) in place of their faction
-- emblem or initial.
--
-- 1. players.avatar_path -- the object's path in the avatars bucket
--    ("{user_id}/{timestamp}.webp"), or null. index.html turns it into a
--    public URL with getPublicUrl(). A new photo gets a new path, so no
--    stale copy is ever served from a cache.
-- 2. The avatars bucket: public (like unit-photos, 073), with no listing
--    policy, so an <img> loads a photo from its URL but nobody can browse
--    the bucket. 1MB cap and image types only; index.html crops photos to a
--    320px square before upload, so real ones are a few tens of KB.
-- 3. Each player may add, replace and delete objects only inside their own
--    folder (the first path segment must be their auth.uid()).
--
-- players already has an owner-write policy, so players set their own
-- avatar_path with a plain update; reading it follows players' existing
-- read access (as display_name does).
--
-- index.html works before this is run: it asks for avatar_path separately,
-- and with no column it simply shows emblems and hides the photo picker.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table players add column if not exists avatar_path text;
comment on column players.avatar_path is 'Path of this player''s profile photo in the avatars storage bucket, or null.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/webp', 'image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "players read their own avatars" on storage.objects;
create policy "players read their own avatars" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players upload their own avatars" on storage.objects;
create policy "players upload their own avatars" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players replace their own avatars" on storage.objects;
create policy "players replace their own avatars" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "players delete their own avatars" on storage.objects;
create policy "players delete their own avatars" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
