-- ============================================================================
-- 067_mission_special_rules_list.sql
--
-- missions.special_rules was a single free-text blob -- fine for one rule,
-- unreadable for several (no line breaks survive into the rendered <p>).
-- Converts it to a jsonb array of individual rule strings, one per entry,
-- each optionally carrying **bold**/_italic_ markup (rendered by
-- index.html's formatRuleText, not enforced here). An existing single
-- blob becomes a one-item array so nothing already saved is lost.
--
-- Idempotent: safe to re-run -- only converts if the column is still text.
-- ============================================================================

do $$
begin
  if (select data_type from information_schema.columns
      where table_name = 'missions' and column_name = 'special_rules') = 'text' then
    alter table missions alter column special_rules type jsonb using (
      case when special_rules is null or special_rules = '' then '[]'::jsonb
           else jsonb_build_array(special_rules) end
    );
  end if;
end $$;

alter table missions alter column special_rules set default '[]'::jsonb;
comment on column missions.special_rules is 'Array of individual special-rule strings (jsonb), each optionally carrying **bold**/_italic_ markup rendered by index.html''s formatRuleText. One entry per rule, so multiple rules render as a readable list instead of one run-on paragraph.';
