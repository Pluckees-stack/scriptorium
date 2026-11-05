-- ============================================================================
-- seeds/warcastle-feature-names.sql
--
-- WarCastle's Special Features named as the Player Compendium has them
-- (3.6; Grant, 5 Nov), in every WarCastle event's tables (the real one and
-- WarCastle (test)), where they are now, without moving anything:
--   Hanging Tree  -> The Hanging Tree               (table 3)
--   World Roots   -> The Nagenhof World Roots Tree  (table 4)
--   Altar         -> The Altar at Mount Kalnas      (table 6)
--   Shard of Morr -> Möller's Shard                 (table 13)
-- Fortenhaf Manor (table 7) is already right. Only the special feature
-- pieces are renamed. The table seeds (warcastle-tables-*.sql) have the new
-- names too, so re-running them is no longer needed for this.
--
-- Run in the Supabase SQL editor. Safe to run again.
-- ============================================================================

update missions m
set terrain = jsonb_set(m.terrain, '{builder,layout,pieces}', (
  select jsonb_agg(case when (p ->> 'special')::boolean is true and p ->> 'name' in ('Hanging Tree', 'World Roots', 'Altar', 'Shard of Morr')
    then jsonb_set(p, '{name}', to_jsonb(case p ->> 'name'
      when 'Hanging Tree' then 'The Hanging Tree'
      when 'World Roots' then 'The Nagenhof World Roots Tree'
      when 'Altar' then 'The Altar at Mount Kalnas'
      else 'Möller’s Shard' end))
    else p end order by n)
  from jsonb_array_elements(m.terrain -> 'builder' -> 'layout' -> 'pieces') with ordinality as e(p, n)))
where m.campaign_id in (select id from campaigns where settings ->> 'template' = 'warcastle')
  and jsonb_typeof(m.terrain -> 'builder' -> 'layout' -> 'pieces') = 'array'
  and exists (select 1 from jsonb_array_elements(m.terrain -> 'builder' -> 'layout' -> 'pieces') p
              where (p ->> 'special')::boolean is true and p ->> 'name' in ('Hanging Tree', 'World Roots', 'Altar', 'Shard of Morr'));

-- should show each WarCastle table's special feature by its new name
select c.name as event, m.name as table_name, p ->> 'name' as special_feature
from missions m join campaigns c on c.id = m.campaign_id
cross join lateral jsonb_array_elements(m.terrain -> 'builder' -> 'layout' -> 'pieces') p
where c.settings ->> 'template' = 'warcastle' and (p ->> 'special')::boolean is true
order by c.name, m.name;
