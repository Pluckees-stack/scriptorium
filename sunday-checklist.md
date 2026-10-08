# Sunday checklist

Parts 1–3 are the security fixes; parts 4–5 are quick housekeeping.

Everything is written and waiting on the `security-fixes` branch. Do this on a
computer, in one sitting, in this order. Allow about 30 minutes, at a quiet
time when nobody's mid-game. You'll need a second account to confirm a test
battle (a friend, or a spare login of your own).

Each part ends with a check. If a check fails, stop and use the undo step in
that part.

---

## Part 1 — stop players editing their own battles (SQL only)

1. Supabase → **SQL Editor** → **New query**. Paste this and press **Run**:

   ```sql
   alter function log_game_with_xp(jsonb) security definer;
   drop policy if exists "players manage their own games" on games;
   revoke all on function apply_game_kill_credits(bigint) from public, anon, authenticated;
   revoke all on function reverse_game_kill_credits(bigint) from public, anon, authenticated;
   revoke all on function sync_tournament_pairing_for_game(bigint) from public, anon, authenticated;
   ```

2. **Check:** run this. All six values should say `false`.

   ```sql
   select p.proname, has_function_privilege('anon', p.oid, 'execute') anon,
          has_function_privilege('authenticated', p.oid, 'execute') authed
   from pg_proc p where p.proname in
   ('apply_game_kill_credits','reverse_game_kill_credits','sync_tournament_pairing_for_game');
   ```

3. **Check in the app:** log a test battle, confirm it from the other account,
   then check it appears in standings and the units got their XP. Then delete
   the test battle from the admin game log.

**Undo** (only if logging a battle now fails):

```sql
alter function log_game_with_xp(jsonb) security invoker;
create policy "players manage their own games" on games for all to authenticated
  using (((select auth.uid()) = player_id) and is_campaign_member(campaign_id))
  with check (((select auth.uid()) = player_id) and is_campaign_member(campaign_id));
```

---

## Part 2 — stop email addresses leaking

This changes how players sign in: **anyone who's added an email signs in with
that email instead of their username.** Post the announcement at the end.

1. **Supabase setting.** Supabase → **Authentication** → **Sign In / Providers**
   (on some screens just **Providers**) → **Email**. Switch **Secure email change** *off* and save.
   *(Why: with it on, Supabase also sends a confirmation to the player's old
   made-up address, which nobody can receive, so adding an email never
   finishes.)*

2. **Put the new app live.** Open
   <https://github.com/pluckees-stack/scriptorium/compare/main...security-fixes>,
   press **Create pull request**, then **Merge pull request**. The live site
   updates by itself within a few minutes.

3. **Check the new page is live:** open the site and refresh. The sign-in box
   should say **Email or username**. If it still says **Username**, wait a
   couple of minutes and refresh again.

4. **Check signing in:** sign out, then sign back in **with your email
   address**. Then try **Forgot password?** with your email. The reset email
   should arrive.

5. **Remove the old lookup.** Only once step 3 shows the new page: Supabase →
   **SQL Editor**, paste this and press **Run**:

   ```sql
   drop function if exists email_for_username(text);
   ```

6. **Remove the old server function.** Supabase → **Edge Functions** →
   **set-my-email** → delete it. (Keep `admin-reset-password`.)

**Undo:** if players can't sign in after step 2, open the merged pull request
on GitHub and press **Revert**. If you'd already done step 5, also re-run
`migrations/047_email_for_username_lookup.sql` in the SQL Editor.

---

## Part 3 — tell the players

Suggested announcement, posted the way you normally post announcements:

> **Signing in has changed.** If you've added an email address to your
> account, sign in with that email instead of your username, using the same
> password. Forgot your password? Use "Forgot password?" with your email
> address. Haven't added an email yet? Keep using your username. You'll be
> asked to add one, and it's confirmed by a link sent to that address.

---

## Part 4 — update the Old World Builder unit data

The app reads unit rules, points and spells from Old World Builder, frozen at
a chosen version. Pull request **#20** moves it to OWB's version from late
July; the app is still on the earlier one. It's a one-line change.

1. Open <https://github.com/pluckees-stack/scriptorium/pull/20>. In its
   description, click the **Diff** link to see what OWB changed. You're only
   looking for anything alarming (e.g. a whole army file deleted); new units,
   points tweaks and typo fixes are what you want.
2. Press **Merge pull request**. The live site updates within a few minutes.
3. **Check:** open the site, refresh, and import a list (or open an existing
   roster). Units should show their points and rules, and the spell list
   should open in Game view.

**Undo:** open the merged pull request and press **Revert**.

---

## Part 5 — delete the old update branches

Skip this if Claude has already done it (it'll have said so).

1. Open <https://github.com/pluckees-stack/scriptorium/branches/all>.
2. Click the bin icon next to each `owb-update-202607…` branch. **Don't**
   delete plain `owb-update` (no date), `warcastle-map-movement`,
   `roadmap-brief` or `security-fixes`.

---

## Done

Tick both `070` and `071` as **Run** in `migrations/README.md` (or tell Claude
and it'll do it).
