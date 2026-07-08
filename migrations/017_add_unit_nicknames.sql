-- ============================================================================
-- 017_add_unit_nicknames.sql
--
-- Lets a player give one of their units a custom display name (e.g. "Boris"),
-- shown everywhere as "nickname (unit type)" -- most usefully in the
-- killed-by picker on Game view's End game screen, where two units of the
-- same type are otherwise indistinguishable by name alone. `units.name`
-- itself is left untouched -- it's still the OWB import's type name, used
-- for rules-index lookups (unitMaxWounds, spell matching, etc. all key off
-- it), so the nickname has to live in its own column, not overwrite it.
--
-- No RLS changes needed: "players manage their own units"
-- (016_fix_own_row_policies_membership_gap.sql) already covers UPDATE on any
-- column of an owned, campaign-scoped unit row.
--
-- Idempotent: safe to re-run.
-- ============================================================================

alter table units add column if not exists nickname text;

comment on column units.nickname is 'Player-given custom name for this unit instance, shown as "nickname (name)" wherever the unit is displayed. NULL = no nickname set, falls back to the plain unit type name.';
