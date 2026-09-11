-- ============================================================================
-- 063_auto_create_players_row.sql
--
-- Durable fix for the recurring "insert or update on table campaign_members
-- violates foreign key constraint campaign_members_user_id_fkey" join/login
-- failure (alexjclark 2026-09-02, synners 2026-09-11). Root cause: a
-- players row is only ever created client-side (doSignUp at signup, or
-- loadApp's self-heal for a brand new Google sign-in), and both paths can
-- lose the race or silently fail -- leaving an auth.users account with
-- nothing in players, which then can't join any campaign.
--
-- This adds the standard Supabase pattern instead: a trigger on auth.users
-- that creates the players row server-side, synchronously, the moment the
-- account exists -- so it's no longer possible for one not to.
--
--   handle_new_auth_user()  picks a starting display name from the user's
--     signup metadata (full_name/name, set by doSignUp) or the email's
--     local part, sanitised the same way doSignUp already does
--     (alphanumeric/hyphen/underscore, 30 chars), then disambiguates against
--     players_display_name_lower_idx (047) by appending -2, -3, ... if
--     that name's taken, so the trigger itself never fails on collision.
--   on_auth_user_created    fires it after every auth.users insert.
--
-- doSignUp's own players insert (index.html) becomes an UPDATE of the row
-- the trigger just created, setting the display name the user actually
-- chose -- still enforces "that username is already taken" the same way
-- (same unique index, same error text), just as an update instead of an
-- insert. loadApp's self-heal upsert is untouched as a harmless fallback.
--
-- Idempotent: safe to re-run. Run after 062.
-- ============================================================================

create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_name text;
  final_name text;
  suffix int := 0;
begin
  -- Client code (doSignUp) may have already raced this trigger and won --
  -- nothing to do.
  if exists (select 1 from players where id = new.id) then
    return new;
  end if;

  base_name := coalesce(
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Player'
  );
  base_name := regexp_replace(base_name, '[^a-zA-Z0-9_-]', '', 'g');
  if base_name = '' then base_name := 'Player'; end if;
  base_name := left(base_name, 30);

  final_name := base_name;
  while exists (select 1 from players where lower(display_name) = lower(final_name)) loop
    suffix := suffix + 1;
    final_name := left(base_name, greatest(1, 30 - length(suffix::text) - 1)) || '-' || suffix::text;
  end loop;

  insert into players (id, display_name) values (new.id, final_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

comment on function handle_new_auth_user() is 'Auto-creates a players row for every new auth.users account (signup or OAuth), so campaign_members_user_id_fkey can never be violated by a missing profile. See migrations/063.';
