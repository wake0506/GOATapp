-- Read-only post-deletion check. Replace the placeholder UUID before running.
-- The temporary result table is session-local and is not persisted.
begin;

create temporary table pg_temp.goat_deleted_account_check (
  table_name text not null,
  remaining_rows bigint,
  status text not null
) on commit preserve rows;

do $$
declare
  target_user_id uuid := '00000000-0000-0000-0000-000000000000';
  table_name text;
  remaining_rows bigint;
  table_exists boolean;
begin
  if pg_catalog.to_regclass('auth.users') is null then
    insert into pg_temp.goat_deleted_account_check values ('auth.users', null, 'FAIL');
  else
    execute 'select count(*) from auth.users where id = $1' into remaining_rows using target_user_id;
    insert into pg_temp.goat_deleted_account_check values ('auth.users', remaining_rows, case when remaining_rows = 0 then 'PASS' else 'FAIL' end);
  end if;

  foreach table_name in array array[
    'user_profiles', 'diet_logs', 'exercise_logs', 'daily_tracking',
    'water_intake_records', 'body_weight_logs', 'training_sessions',
    'sync_tombstones', 'client_operations', 'sync_diagnostics', 'chat_history'
  ] loop
    table_exists := pg_catalog.to_regclass(pg_catalog.format('public.%I', table_name)) is not null;
    if not table_exists then
      insert into pg_temp.goat_deleted_account_check values (table_name, null, 'FAIL');
    else
      if table_name = 'user_profiles' then
        execute pg_catalog.format('select count(*) from public.%I where id = $1', table_name) into remaining_rows using target_user_id;
      else
        execute pg_catalog.format('select count(*) from public.%I where user_id = $1', table_name) into remaining_rows using target_user_id;
      end if;
      insert into pg_temp.goat_deleted_account_check values (table_name, remaining_rows, case when remaining_rows = 0 then 'PASS' else 'FAIL' end);
    end if;
  end loop;
end;
$$;

select table_name, remaining_rows, status
from pg_temp.goat_deleted_account_check
order by table_name;

commit;
