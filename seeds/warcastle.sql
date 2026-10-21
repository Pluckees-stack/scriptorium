-- ============================================================================
-- seeds/warcastle.sql
--
-- Marks the real WarCastle event as a WarCastle event, so it gets the
-- Fortenhaf map and the WarCastle steps (warcastle-brief.md).
--
-- 1. Create the event in Scriptorium as usual: the event builder's
--    Tournament type, named exactly WarCastle (or change the name below).
-- 2. Run this in the Supabase SQL editor (after migrations/100).
--
-- Safe to run again: it only sets campaigns.settings.template.
-- ============================================================================

update campaigns
set settings = settings || '{"template": "warcastle"}'::jsonb
where name = 'WarCastle' and format = 'tournament';

-- should show one row, template warcastle
select id, name, status, settings ->> 'template' as template
from campaigns
where name = 'WarCastle';
