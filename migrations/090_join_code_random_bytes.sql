-- ============================================================================
-- 090_join_code_random_bytes.sql
--
-- Saving a new event in the builder failed with "function
-- gen_random_bytes(integer) does not exist". generate_join_code (088) only
-- looks in the public schema, but Supabase keeps pgcrypto's gen_random_bytes
-- in the extensions schema (074 already calls it as
-- extensions.gen_random_bytes). Same function, with the schema named.
--
-- To undo: re-run generate_join_code from 088 (it will be broken again).
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

create or replace function generate_join_code(p_name text)
returns text language plpgsql volatile set search_path = public as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_word text;
  v_prefix text := '';
  v_code text;
  v_tries integer := 0;
begin
  foreach v_word in array regexp_split_to_array(upper(coalesce(p_name, '')), '\s+') loop
    v_word := regexp_replace(v_word, '[^A-Z]', '', 'g');
    if length(v_word) >= 3 and v_word not in ('THE', 'AND', 'FOR', 'WITH') then
      v_prefix := left(v_word, 6);
      exit;
    end if;
  end loop;
  if v_prefix = '' then v_prefix := 'CAMP'; end if;

  loop
    v_tries := v_tries + 1;
    v_code := v_prefix || '-';
    for i in 1..4 loop
      v_code := v_code || substr(v_alphabet, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    exit when not exists (select 1 from campaigns where normalise_join_code(join_code) = normalise_join_code(v_code));
    if v_tries > 50 then raise exception 'Couldn''t find a free join code. Try again.'; end if;
  end loop;
  return v_code;
end;
$$;

revoke all on function generate_join_code(text) from public, anon;
grant execute on function generate_join_code(text) to authenticated;
