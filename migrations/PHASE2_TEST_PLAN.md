# Phase 2 RLS test plan

Covers `009`–`014`: the helper functions, every table's policies, the
campaign-membership and platform-role admin functions, the standings views,
and the XP function rewrite.

## How to actually test this

Running queries in the SQL editor normally executes as the `postgres` role,
which **bypasses RLS entirely** — every query would look like it works,
policies or not. To test as a specific real user, impersonate them:

```sql
begin;
select set_config('request.jwt.claims', json_build_object('sub', '<user-uuid>', 'role', 'authenticated')::text, true);
set local role authenticated;

-- your test query goes here

rollback; -- always rollback in test transactions, so nothing you do while impersonating actually sticks
```

`auth.uid()` reads `request.jwt.claims ->> 'sub'`, so this makes every policy
see exactly what it would see for that real user. The `begin`/`rollback`
wrapper means write tests are free to attempt inserts/updates/deletes
without needing to clean up afterwards.

To find user ids to test with:
```sql
select p.id, p.display_name, p.platform_role, cm.campaign_id, cm.role
  from players p
  left join campaign_members cm on cm.user_id = p.id
 order by p.display_name;
```

## Setup

There's no UI yet for assigning roles (that's the Admin Console, Phase 5) —
`011`/`013`'s functions are the mechanism it'll eventually call, but nothing
calls them yet. For testing, that's fine: you're running as the database
owner in the SQL editor, which bypasses RLS and the column `REVOKE`s
entirely, so you can just set these up directly with plain `UPDATE`s. This
is the one place in this whole plan where you *don't* need to impersonate
anyone — you're deliberately using your real, unrestricted access to
manufacture the test personas that the rest of the plan will then test
*with* restricted access.

Start by seeing what you've got:
```sql
select id, display_name, platform_role from players order by display_name;
```

Right now everyone but your superadmin account is a plain player in
`SKULL-0001` — that's expected, nothing's gone wrong. Pick two of those
other accounts and turn one into an organiser (the other stays a plain
player, no change needed):

```sql
update campaign_members
   set role = 'organiser'
 where user_id = '<player-a-uuid>'
   and campaign_id = (select id from campaigns where join_code = 'SKULL-0001');
```

Optionally, pick a third account to test the platform-admin tier
specifically (distinct from your superadmin — several test cases in
section D depend on "admin, but not superadmin" being a real distinction):

```sql
update players set platform_role = 'admin' where id = '<player-c-uuid>';
```

For the cross-campaign isolation tests (A2, A6, A8, A10, B12, etc.), create
a second campaign — nobody's a member of it yet, so any existing
`SKULL-0001` player already qualifies as "not a member of campaign 2" with
no extra setup:

```sql
insert into campaigns (name, join_code, created_by)
values ('Second Test Campaign', 'TEST-0002', (select id from players where platform_role = 'superadmin' limit 1));
```

**Section C (the "outsider" persona — member of no campaign at all) is the
one case that doesn't exist naturally**, since Phase 1 auto-enrolled every
existing player into `SKULL-0001`. You can manufacture it:

```sql
delete from campaign_members
 where user_id = '<player-d-uuid>'
   and campaign_id = (select id from campaigns where join_code = 'SKULL-0001');

-- afterwards, put them back:
insert into campaign_members (user_id, campaign_id, role)
values ('<player-d-uuid>', (select id from campaigns where join_code = 'SKULL-0001'), 'player');
```

...or skip section C for now — it's genuinely the simplest case in the
whole model (no `campaign_members` row means every campaign-scoped check
just returns false), and it'll get exercised naturally the first time a
real new signup joins nothing yet, once Phase 4 is built. Your call whether
that's worth the manual setup today.

## A. As the organiser (of `SKULL-0001`)

| # | Action | Expected |
|---|---|---|
| A1 | `select * from campaign_members where campaign_id = '<skull-0001-id>';` | Allow — sees every member |
| A2 | `select * from campaign_members where campaign_id = '<test-0002-id>';` | Empty result (not a member there, not admin) |
| A3 | `update campaign_members set faction_id = 'empire-of-man' where user_id = auth.uid() and campaign_id = '<skull-0001-id>';` | Allow |
| A4 | `update campaign_members set role = 'organiser' where user_id = '<some-player-uuid>' and campaign_id = '<skull-0001-id>';` (raw update, not the function) | **Deny** — `role` is column-revoked, fails regardless of row match |
| A5 | `select set_campaign_member_role('<skull-0001-id>', '<player-uuid>', 'organiser');` | Allow — promotes that player |
| A6 | `select set_campaign_member_role('<test-0002-id>', '<anyone>', 'organiser');` | Deny — exception, not organiser of that campaign |
| A7 | `insert into alliances (id, name, campaign_id) values ('test-alliance', 'Test Alliance', '<skull-0001-id>');` | Allow |
| A8 | Same insert with `campaign_id = '<test-0002-id>'` | Deny |
| A9 | `update campaigns set name = 'Renamed' where id = '<skull-0001-id>';` | Allow |
| A10 | Same update targeting `<test-0002-id>` | Deny |
| A11 | `insert into campaigns (name, join_code) values ('New Campaign', 'NEW-0001');` | Deny — superadmin only |
| A12 | `update units set experience = 99 where id = <some-other-players-unit-id-in-skull-0001>;` | **Deny** — no organiser override, per decision |
| A13 | `insert into missions (campaign_id, name) values ('<skull-0001-id>', 'Custom Mission');` | Allow |
| A14 | `insert into missions (campaign_id, name) values (null, 'Official Mission');` | Deny — official templates are admin/superadmin only |
| A15 | `select * from trait_objectives where campaign_id is null;` | Allow — official objectives visible to everyone |

## B. As the player (member of `SKULL-0001`, not organiser)

| # | Action | Expected |
|---|---|---|
| B1 | `select * from rosters where player_id = auth.uid();` | Allow |
| B2 | `select * from rosters where campaign_id = '<skull-0001-id>' and player_id != auth.uid();` | Allow — read is member-wide, needed for standings/opponent lists |
| B3 | `update rosters set name = 'x' where player_id = auth.uid();` | Allow |
| B4 | `update rosters set name = 'x' where player_id = '<someone-else>';` | Deny |
| B5 | `select * from campaign_members where campaign_id = '<skull-0001-id>';` | Allow |
| B6 | `update campaign_members set faction_id = 'skaven' where user_id = auth.uid() and campaign_id = '<skull-0001-id>';` | Allow |
| B7 | `update campaign_members set alliance_id = 'x' where user_id = auth.uid() and campaign_id = '<skull-0001-id>';` | **Deny** — column-revoked, even for your own row |
| B8 | `select set_campaign_member_role('<skull-0001-id>', auth.uid(), 'organiser');` | Deny — not organiser/admin |
| B9 | `insert into alliances (id, name, campaign_id) values ('x', 'x', '<skull-0001-id>');` | Deny |
| B10 | `delete from campaign_members where user_id = auth.uid() and campaign_id = '<skull-0001-id>';` | Allow — leaving is self-service |
| B11 | `select * from campaigns where id = '<test-0002-id>';` | Allow — campaign metadata is readable by everyone |
| B12 | `select * from campaign_members where campaign_id = '<test-0002-id>';` | Empty — not a member, not admin |
| B13 | `insert into campaign_members (user_id, campaign_id, role) values (auth.uid(), '<test-0002-id>', 'player');` | Allow — this is how joining works |
| B14 | Same insert with `role = 'organiser'` | Deny — WITH CHECK forces `'player'` |

## C. As the outsider (member of no campaign)

| # | Action | Expected |
|---|---|---|
| C1 | `select * from campaigns;` | Allow — full list, metadata only |
| C2 | `select * from campaign_members where campaign_id = '<skull-0001-id>';` | Empty |
| C3 | `select * from rosters where campaign_id = '<skull-0001-id>';` | Empty |
| C4 | `select * from alliances where campaign_id = '<skull-0001-id>';` | Empty |
| C5 | `select * from missions where campaign_id is null;` | Allow — official templates, visible to everyone |
| C6 | `select * from missions where campaign_id = '<skull-0001-id>';` | Empty |
| C7 | `insert into campaign_members (user_id, campaign_id, role) values (auth.uid(), '<skull-0001-id>', 'player');` | Allow — joining by code |
| C8 | Any write to `rosters`/`units`/`games`/`alliances` | Deny |

## D. Platform admin / superadmin (test separately from the above — these bypass campaign membership entirely)

| # | Action | Expected |
|---|---|---|
| D1 | As an **admin** (not superadmin, not a member of either campaign): `select * from campaign_members where campaign_id = '<test-0002-id>';` | Allow — platform-wide read on administration tables |
| D2 | Same admin: `select * from rosters where campaign_id = '<test-0002-id>';` | Empty — deliberately NOT extended to player-owned data (your call to revisit later) |
| D3 | Same admin: `select set_campaign_member_role('<test-0002-id>', '<someone>', 'organiser');` | Allow |
| D4 | Same admin: `insert into campaigns (name, join_code) values ('x', 'ADMIN-1');` | Deny — campaign creation stays superadmin-only |
| D5 | Same admin: `select set_platform_role('<someone>', 'admin');` | Deny — minting admins is superadmin-only |
| D6 | As **superadmin**: `select set_platform_role('<someone>', 'admin');` | Allow |
| D7 | As superadmin: `insert into campaigns (name, join_code) values ('x', 'SUPER-1');` | Allow |

## E. Functions

| # | Action | Expected |
|---|---|---|
| E1 | As the player: `select increment_unit_xp(<own-unit-id>, 1);` | Allow, returns new XP |
| E2 | As the player: `select increment_unit_xp(<someone-elses-unit-id>, 1);` | Deny — "Unit not found, or it does not belong to you." |
| E3 | As the player: `select log_game_with_xp('{"campaign_id": "<skull-0001-id>", "result": "win", "glory_points": 3}'::jsonb);` | Allow, row inserted with correct `campaign_id` |
| E4 | As the player: same call with `"campaign_id": "<test-0002-id>"` (not a member there) | Deny — "You are not a member of that campaign." |
| E5 | As the player: `select delete_game_with_xp(<own-game-id>);` | Allow, XP reversed |
| E6 | As the player: `select delete_game_with_xp(<someone-elses-game-id>);` | Deny — "Battle not found, or it is not yours to delete." |

## F. Standings views (confirms `security_invoker` is actually working)

| # | Action | Expected |
|---|---|---|
| F1 | As a `SKULL-0001` member: `select * from alliance_standings;` | Only `SKULL-0001`'s alliances appear |
| F2 | As the outsider: `select * from alliance_standings;` | Empty — no membership anywhere, so the view's underlying `alliances`/`campaign_members` RLS shows nothing |
| F3 | As a `SKULL-0001` member: `select * from player_standings where campaign_id = '<skull-0001-id>';` | One row per member of that campaign |
| F4 | Same member: `select count(*) from player_standings where id = auth.uid();` | If you're only in one campaign, this is `1` — confirms the grain change (would be 1-per-campaign if you joined a second one) |

If any row in this plan comes back the wrong way, that's a real policy bug
to fix before moving past Phase 2 — this is the actual security boundary
for the whole platform.
