# Sunday checklist

Parts 1–3 are the security fixes; parts 4–5 are quick housekeeping; part 6
puts the interface tidy-up live; part 7 turns on two-factor login.

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

## Part 6 — interface tidy-up

Only after Part 2 is done and working. One merge brings in both:

- **Slimmer dropdowns, bigger checkboxes, plain on/off switches** (no more
  skulls).
- **Consistent wording:** "battle" not "game", campaign "phases" (only
  tournaments have rounds), "roster", sentence case, and shorter admin tabs
  (Players, Scenarios, Phases, Tournaments, Campaign settings). The full list
  is in `glossary.md`.

1. Open
   <https://github.com/pluckees-stack/scriptorium/compare/main...language-pass>,
   press **Create pull request**, then **Merge pull request**.
2. **Check:** refresh the site. The admin tabs should read *Players,
   Scenarios…*, Game view's button should say **Play campaign battle**, and
   switches in Account should be plain round toggles.

**Undo:** open the merged pull request and press **Revert**. Nothing in the
database changes, so this one is completely safe to undo.

(The separate `quick-ui-polish` branch is already included. Don't merge it
on its own.)

---

## Part 7 — two-factor login (required for admins)

Do this last, after Parts 2 and 6. You'll need your phone with an
authenticator app (Google Authenticator, Microsoft Authenticator,
1Password…).

1. **Check Supabase allows it.** Supabase → **Authentication** → **Multi-Factor**
   (or **MFA**). Make sure **TOTP / authenticator app** is enabled.
2. **Put it live.** Open
   <https://github.com/pluckees-stack/scriptorium/compare/main...two-factor>,
   press **Create pull request**, then **Merge pull request**. Wait a couple of
   minutes and refresh the site.
3. **Set it up on your own account.** You'll see a note saying admin tools
   need two-factor login. Press **Set it up**, scan the QR code with the app,
   and type in the 6-digit code.
4. **Check:** sign out, sign back in. After your password it should ask for a
   code. Once you're in, the **Admin** button is back.
5. **Lock admin powers to two-factor.** Only once step 4 works: Supabase →
   **SQL Editor**, paste the whole of `migrations/072_admin_requires_two_factor.sql`
   (open it on GitHub, on the `two-factor` branch, and use the copy button)
   and press **Run**. Then open an admin tab, e.g. Players, to check it still
   works.
6. **Optional: password resets.** To make the "reset a player's password"
   button need two-factor too: Supabase → **Edge Functions** →
   **admin-reset-password** → edit, replace the code with
   `supabase/functions/admin-reset-password/index.ts` from the `two-factor`
   branch, and deploy. Skip this if it looks fiddly. It only matters if
   someone ever gets your password.
7. **Tell your organisers.** They'll see the same note next time they open
   the app. It takes them a minute.

**If someone loses their phone:** Supabase → **Authentication** → **Users** →
find them → remove their MFA factor. They can then sign in with just a
password and set it up again.

**Undo:** revert the merged pull request on GitHub. If you'd run step 5, also
re-run the three functions in `migrations/009_rls_helper_functions.sql`
(`is_campaign_organiser`, `is_superadmin`, `is_platform_admin`) in the SQL
Editor.

---

## Done

Tick `070`, `071` and `072` as **Run** in `migrations/README.md` (or tell Claude
and it'll do it).
