-- ============================================================================
-- 103_profile_emblem.sql
--
-- A profile icon without a photo: each player can pick a faction emblem and
-- a colour for themselves (Account › Profile), shown wherever the app draws
-- a person, in place of their army's emblem. A photo (102) still comes
-- first; with neither, it's their army's emblem or their initial as before.
--
-- 1. players.avatar_emblem -- a faction id from index.html's FACTION_ACCENTS
--    (e.g. 'skaven'), or null for "my army's".
-- 2. players.avatar_colour -- a #rrggbb colour for behind the emblem, or null
--    for the emblem's own faction colour.
--
-- players already has an owner-write policy, so players set these with a
-- plain update; reading them follows players' existing read access.
--
-- index.html works before this is run: it asks for these separately, and
-- with no columns it hides the emblem and colour choice.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table players add column if not exists avatar_emblem text
  check (avatar_emblem is null or avatar_emblem ~ '^[a-z-]{2,40}$');
alter table players add column if not exists avatar_colour text
  check (avatar_colour is null or avatar_colour ~ '^#[0-9a-f]{6}$');
comment on column players.avatar_emblem is 'Faction id of the emblem this player shows as their icon, or null for their army''s.';
comment on column players.avatar_colour is 'Colour (#rrggbb) behind this player''s icon emblem, or null for the emblem''s faction colour.';
