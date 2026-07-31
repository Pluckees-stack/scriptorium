-- ============================================================================
-- 042_fix_map_upload_storage_rls.sql
--
-- Fixes: uploading a map image can fail silently for a platform admin/
-- superadmin who isn't *also* specifically an organiser of the campaign
-- they're currently viewing.
--
-- 037_mission_maps.sql's storage.objects INSERT policy only checked
-- is_campaign_organiser(...), unlike every other admin-write policy in this
-- app (including the maps *table*'s own "organisers manage campaign maps"
-- policy, right above it in the same file), which all fall back to
-- is_platform_admin() too. This just brings the Storage policy in line with
-- that same convention.
--
-- Idempotent: safe to re-run. Run after 041.
-- ============================================================================

drop policy if exists "organisers upload campaign map images" on storage.objects;
create policy "organisers upload campaign map images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'map-images'
    and (is_campaign_organiser(((storage.foldername(name))[1])::uuid) or is_platform_admin())
  );
