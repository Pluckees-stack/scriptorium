# Sunday checklist

Everything goes live through one pull request:
**[#22](https://github.com/Pluckees-stack/scriptorium/pull/22)**. It carries
the security fixes, the interface tidy-up (slimmer dropdowns, bigger
checkboxes, plain switches, consistent wording) and two-factor login.

Do this on a computer, in this order, at a quiet time. Allow about an hour.
You'll need:

- your phone with an authenticator app (Google Authenticator, Microsoft
  Authenticator, 1Password…)
- a second account to confirm a test battle (a friend, or a spare login)

Each part ends with a check. If a check fails, stop and use that part's undo.

---

## Part 0 — have a look first (optional, any time before)

Netlify builds a live copy of the pull request:
<https://deploy-preview-22--pluckees-scriptorium.netlify.app>

It uses the **real** database, so anything you do there is real. Sign in with
your **email and password** (Google sign-in won't work on the preview
address). **Don't set up two-factor login there yet.** That waits for Part 4.

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
   the test battle from the admin battle log.

**Undo** (only if logging a battle now fails):

```sql
alter function log_game_with_xp(jsonb) security invoker;
create policy "players manage their own games" on games for all to authenticated
  using (((select auth.uid()) = player_id) and is_campaign_member(campaign_id))
  with check (((select auth.uid()) = player_id) and is_campaign_member(campaign_id));
```

---

## Part 2 — two Supabase settings

1. Supabase → **Authentication** → **Sign In / Providers** (on some screens
   just **Providers**) → **Email**. Switch **Secure email change** *off* and
   save. *(With it on, adding an email also sends a link to the player's old
   made-up address, which nobody can receive, so it never finishes.)*
2. Supabase → **Authentication** → **Multi-Factor** (or **MFA**). Make sure
   **TOTP / authenticator app** is enabled.

---

## Part 3 — put it all live

1. Open <https://github.com/Pluckees-stack/scriptorium/pull/22> and press
   **Merge pull request**. The live site updates by itself within a few
   minutes.
2. **Check the new version is live:** refresh the site. The sign-in box should
   say **Email or username**. If it still says **Username**, wait a couple of
   minutes and refresh again.
3. **Check signing in:** sign out, then sign back in **with your email
   address**. Try **Forgot password?** with your email too. The reset email
   should arrive.
4. **Check the tidy-up:** Game view's button says **Play campaign battle**, and
   the switches in Account settings are plain round toggles.

You'll notice the **Admin** button has gone, replaced by a note saying admin
tools need two-factor login. That's expected. Part 4 brings it back.

**Undo:** open the merged pull request and press **Revert**.

---

## Part 4 — set up two-factor login on your account

1. Press **Set it up** on the note (or Account settings → **Two-factor
   login**). Scan the QR code with your authenticator app and type in the
   6-digit code.
2. **Check:** sign out and back in. After your password it should ask for a
   code. Once you're in, the **Admin** button is back.

---

## Part 5 — finish in Supabase

Only once Parts 3 and 4 both work.

1. **Remove the old email lookup.** SQL Editor, paste and **Run**:

   ```sql
   drop function if exists email_for_username(text);
   ```

2. **Remove the old server function.** **Edge Functions** → **set-my-email** →
   delete it. (Keep `admin-reset-password`.)
3. **Lock admin powers to two-factor.** SQL Editor: paste the whole of
   [`migrations/072_admin_requires_two_factor.sql`](https://github.com/Pluckees-stack/scriptorium/blob/main/migrations/072_admin_requires_two_factor.sql)
   (use GitHub's copy button) and press **Run**.
4. **Check:** open an admin tab, e.g. Players, and make sure it still loads.
5. **Optional: password resets.** To make "reset a player's password" need
   two-factor too: **Edge Functions** → **admin-reset-password** → edit,
   replace the code with
   [`supabase/functions/admin-reset-password/index.ts`](https://github.com/Pluckees-stack/scriptorium/blob/main/supabase/functions/admin-reset-password/index.ts),
   and deploy. Skip it if it looks fiddly. It only matters if someone ever
   gets your password.

**Undo:**
- **Step 1:** re-run `migrations/047_email_for_username_lookup.sql`. You'd
  only need this if you'd also reverted Part 3.
- **Step 3:** re-run the three functions in
  `migrations/009_rls_helper_functions.sql` (`is_campaign_organiser`,
  `is_superadmin`, `is_platform_admin`).

**If someone loses their phone:** Supabase → **Authentication** → **Users** →
find them → remove their MFA factor. They can then sign in with just a
password and set it up again.

---

## Part 6 — tell everyone

Suggested announcement, posted the way you normally post announcements:

> **Signing in has changed.** If you've added an email address to your
> account, sign in with that email instead of your username, using the same
> password. Forgot your password? Use "Forgot password?" with your email
> address. Haven't added an email yet? Keep using your username. You'll be
> asked to add one, and it's confirmed by a link sent to that address.
>
> **Organisers:** admin tools now need two-factor login. You'll see a note
> with a **Set it up** button. It takes a minute with an authenticator app.

---

## Part 7 — update the Old World Builder unit data

Pull request **#20** moves the app's unit rules, points and spells to
Old World Builder's late-July version. It's a one-line change.

1. Open <https://github.com/Pluckees-stack/scriptorium/pull/20>. In its
   description, click the **Diff** link to see what OWB changed. You're only
   looking for anything alarming (e.g. a whole army file deleted).
2. Press **Merge pull request**.
3. **Check:** refresh the site and import a list (or open a roster). Units
   should show points and rules, and the spell list should open in Game view.

**Undo:** open the merged pull request and press **Revert**.

---

## Part 8 — tidy up old branches

Open <https://github.com/Pluckees-stack/scriptorium/branches/all> and click
the bin icon next to:

- the 19 `owb-update-202607…` branches (leftovers from July)
- once #22 is merged: `security-fixes`, `quick-ui-polish`, `language-pass`
  and `two-factor`. Their work is all inside #22.

**Don't** delete `main`, plain `owb-update`, `warcastle-map-movement` or
`roadmap-brief`.

---

## Done

Tick `070`, `071` and `072` as **Run** in `migrations/README.md`, or tell
Claude and it'll do it.
