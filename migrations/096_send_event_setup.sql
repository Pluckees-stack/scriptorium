-- ============================================================================
-- 096_send_event_setup.sql
--
-- Set up › Send to players (admin console PR D). Sending publishes the
-- event's set-up to everyone's Play tab (campaigns.settings.setup, which
-- organisers already write) and notifies every player; sending again after
-- a change tells them what changed. Notifications are only ever written by
-- the database (075), so this does the notifying, for an organiser of the
-- event (two-factor login, as for every organiser tool) or a platform admin.
--
-- To undo:
--   drop function if exists notify_event_players(uuid, text, text);
-- ============================================================================

create or replace function notify_event_players(p_campaign uuid, p_title text, p_body text)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_title text := nullif(left(trim(coalesce(p_title, '')), 120), '');
  v_body text := nullif(left(trim(coalesce(p_body, '')), 1000), '');
  v_count integer;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if not (is_campaign_organiser(p_campaign) or is_platform_admin()) then
    raise exception 'Only an organiser of this event can send to its players.';
  end if;
  if v_title is null then raise exception 'Give the message a title.'; end if;
  perform notify_campaign(p_campaign, 'event_setup', v_title, v_body, false, array[auth.uid()]);
  select count(*) - 1 into v_count from campaign_members where campaign_id = p_campaign;
  return greatest(v_count, 0);
end;
$$;
revoke all on function notify_event_players(uuid, text, text) from public, anon;
grant execute on function notify_event_players(uuid, text, text) to authenticated;
