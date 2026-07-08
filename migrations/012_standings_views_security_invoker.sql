-- ============================================================================
-- 012_standings_views_security_invoker.sql
--
-- Phase 2, part 4.
--
-- Confirmed via `select version()` that this database runs PostgreSQL
-- 17.6, well past the PG15 minimum for view-level security_invoker.
-- Setting it on both standings views makes them evaluate RLS as the
-- QUERYING user, not the view owner -- without this, campaign isolation on
-- these views would depend entirely on the client remembering to filter by
-- campaign_id (a convention, not a real boundary; any direct API call
-- could ignore it and see every campaign's standings blended together).
-- With it, the views' own underlying-table RLS (campaign_members' and
-- games' policies from 010) enforces isolation automatically, the same as
-- querying those tables directly.
--
-- This does not change the views' existing SELECT grant to `authenticated`
-- -- security_invoker only changes whose RLS applies, not who can query the
-- view at all.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter view alliance_standings set (security_invoker = true);
alter view player_standings set (security_invoker = true);
