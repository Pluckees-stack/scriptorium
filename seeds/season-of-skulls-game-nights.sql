-- ============================================================================
-- seeds/season-of-skulls-game-nights.sql
--
-- One-off: loads the Season of Skulls gaming nights and tournament days
-- still to come (from 22 October 2026) into Game nights, each linked to its
-- ticket in the Bad Moon Cafe shop. Run once, after migrations/085, in the
-- Supabase SQL editor. Running it again adds the nights again.
--
-- Check before running, and change here or afterwards in Admin > Game nights:
--   - tables: 8 a night (a guess)
--   - times: gaming nights 6pm-10pm; tournament days 10am-6pm (a guess:
--     the shop only gives the 6pm start for gaming nights)
-- ============================================================================

insert into game_nights (campaign_id, title, starts_at, ends_at, venue, tables, players_per_table, points, price_text, ticket_url, notes)
select c.id, n.title, (n.starts || ' Europe/London')::timestamptz, (n.ends || ' Europe/London')::timestamptz,
       'Bad Moon Cafe, Holloway Road', 8, n.per_table, n.points, n.price, n.ticket,
       '48-hour cancellation policy for refunds or booking amendments. Under 18s need to be with a responsible adult.'
from campaigns c,
(values
  ('1250 Point Singles', '2026-10-22 18:00', '2026-10-22 22:00', 1250, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047360380'),
  ('1250 Point Singles', '2026-10-29 18:00', '2026-10-29 22:00', 1250, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047393148'),
  ('1500 Point Singles', '2026-11-12 18:00', '2026-11-12 22:00', 1500, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047425916'),
  ('1500 Point Singles', '2026-11-19 18:00', '2026-11-19 22:00', 1500, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047458684'),
  ('1500 Point Singles', '2026-11-26 18:00', '2026-11-26 22:00', 1500, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047491452'),
  ('2000 Point Singles', '2026-12-03 18:00', '2026-12-03 22:00', 2000, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047524220'),
  ('2000 Point Singles', '2026-12-10 18:00', '2026-12-10 22:00', 2000, 2, '£10', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047556988'),
  ('Campaign Finale Full Day Tournament', '2026-12-19 10:00', '2026-12-19 18:00', null, 2, '£30', 'https://shop.badmooncafe.co.uk/products/warhammer-the-old-world-slow-grow-holloway-road-1?variant=57148047589756')
) as n(title, starts, ends, points, per_table, price, ticket)
where c.name = 'Season of Skulls';
