-- ============================================================================
-- 089_players_run_tournaments.sql
--
-- For now, players run tournaments; long-form campaigns are set up by
-- platform admins. The campaign builder (088) only offers players the
-- tournament format, and this enforces it: a campaign a non-admin creates, or
-- switches the format of, has to be a tournament. Existing campaigns, and
-- organisers changing anything other than the format, are untouched.
--
-- Two-factor login stays as it is: opening an event and running it from the
-- admin console already need it, as for every organiser.
--
-- To undo:
--   drop trigger if exists campaigns_players_run_tournaments on campaigns;
--   drop function if exists campaigns_players_run_tournaments_trg();
-- ============================================================================

create or replace function campaigns_players_run_tournaments_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- migrations and the dashboard (no signed-in user) aren't limited
  if auth.uid() is null or is_platform_admin() then return new; end if;
  if new.format = 'tournament' or new.format = 'open' then return new; end if;
  if tg_op = 'INSERT' or new.format is distinct from old.format then
    raise exception 'For now, players can run tournaments. Choose the tournament format.';
  end if;
  return new;
end;
$$;

drop trigger if exists campaigns_players_run_tournaments on campaigns;
create trigger campaigns_players_run_tournaments
  before insert or update of format on campaigns
  for each row execute function campaigns_players_run_tournaments_trg();
