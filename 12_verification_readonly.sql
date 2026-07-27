-- Purely read-only verification. It never invokes application functions or mutates
-- persistent objects; the temporary result table is session-local.
begin;

create temporary table pg_temp.goat_backend_verification (
  check_name text not null,
  status text not null,
  details text not null
) on commit preserve rows;

do $$
declare
  expected text[] := array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'sync_diagnostics', 'chat_history'
  ];
  table_name text;
  rel_oid oid;
  fn_oid oid;
  row_count bigint;
  orphan_count bigint;
  expected_column text;
  policy_count bigint;
  acl_has_public boolean;
  acl_has_anon boolean;
  acl_has_authenticated boolean;
  expr text;
  with_expr text;
begin
  -- Tables and immediate RLS state.
  foreach table_name in array array['sync_diagnostics', 'app_feature_flags'] loop
    rel_oid := pg_catalog.to_regclass(pg_catalog.format('public.%I', table_name));
    if rel_oid is null then
      insert into pg_temp.goat_backend_verification values (table_name || ':exists', 'FAIL', 'table is missing');
    else
      insert into pg_temp.goat_backend_verification
      select table_name || ':exists', 'PASS', 'table exists'
      from pg_catalog.pg_class c
      where c.oid = rel_oid;
      insert into pg_temp.goat_backend_verification
      select table_name || ':rls', case when c.relrowsecurity then 'PASS' else 'FAIL' end,
        case when c.relrowsecurity then 'RLS enabled' else 'RLS is disabled' end
      from pg_catalog.pg_class c where c.oid = rel_oid;
    end if;
  end loop;

  -- Policy shape, role scope, and expressions.
  rel_oid := pg_catalog.to_regclass('public.sync_diagnostics');
  if rel_oid is null then
    insert into pg_temp.goat_backend_verification values ('sync_diagnostics:policies', 'FAIL', 'table is missing');
  else
    foreach table_name in array array[
      'goat_sync_diagnostics_select_own', 'goat_sync_diagnostics_insert_own',
      'goat_sync_diagnostics_update_own', 'goat_sync_diagnostics_delete_own'
    ] loop
      select count(*) into policy_count from pg_catalog.pg_policy p
      where p.polrelid = rel_oid and p.polname = table_name;
      if policy_count = 0 then
        insert into pg_temp.goat_backend_verification values ('sync_diagnostics:policy:' || table_name, 'FAIL', 'policy is missing');
      else
        select pg_catalog.pg_get_expr(p.polqual, p.polrelid), pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid)
          into expr, with_expr
        from pg_catalog.pg_policy p where p.polrelid = rel_oid and p.polname = table_name;
        insert into pg_temp.goat_backend_verification values (
          'sync_diagnostics:policy:' || table_name,
          case when exists (
            select 1 from pg_catalog.pg_policy p
            where p.polrelid = rel_oid and p.polname = table_name and p.polpermissive
              and exists (
                select 1 from pg_catalog.unnest(p.polroles) role_oid
                join pg_catalog.pg_roles role_row on role_row.oid = role_oid
                where role_row.rolname = 'authenticated'
              )
              and not exists (
                select 1 from pg_catalog.unnest(p.polroles) role_oid
                join pg_catalog.pg_roles role_row on role_row.oid = role_oid
                where role_row.rolname <> 'authenticated'
              )
              and (
                (p.polcmd = 'r' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%auth.uid()%' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%user_id%')
                or (p.polcmd = 'a' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '')) like '%auth.uid()%' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '')) like '%user_id%')
                or (p.polcmd = 'w' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%auth.uid()%' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%user_id%'
                  and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '')) like '%auth.uid()%' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '')) like '%user_id%')
                or (p.polcmd = 'd' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%auth.uid()%' and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%user_id%')
              )
          ) then 'PASS' else 'FAIL' end,
          'permissive authenticated own-row policy; qual=' || pg_catalog.coalesce(expr, '') || '; with_check=' || pg_catalog.coalesce(with_expr, '')
        );
      end if;
    end loop;
    select count(*) into policy_count from pg_catalog.pg_policy p where p.polrelid = rel_oid;
    insert into pg_temp.goat_backend_verification values ('sync_diagnostics:policy_count', case when policy_count = 4 then 'PASS' else 'FAIL' end, policy_count::text || ' policies');
  end if;

  rel_oid := pg_catalog.to_regclass('public.app_feature_flags');
  if rel_oid is null then
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:policies', 'FAIL', 'table is missing');
  else
    select count(*) into policy_count from pg_catalog.pg_policy p where p.polrelid = rel_oid;
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:only_authenticated_select',
      case when policy_count = 1 and exists (
        select 1 from pg_catalog.pg_policy p
        where p.polrelid = rel_oid and p.polname = 'goat_feature_flags_authenticated_read'
          and p.polcmd = 'r' and p.polpermissive
          and exists (
            select 1 from pg_catalog.unnest(p.polroles) role_oid
            join pg_catalog.pg_roles role_row on role_row.oid = role_oid
            where role_row.rolname = 'authenticated'
          )
          and not exists (
            select 1 from pg_catalog.unnest(p.polroles) role_oid
            join pg_catalog.pg_roles role_row on role_row.oid = role_oid
            where role_row.rolname <> 'authenticated'
          )
          and pg_catalog.lower(pg_catalog.coalesce(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '')) like '%auth.uid()%'
      ) then 'PASS' else 'FAIL' end, policy_count::text || ' policy');
    select count(*) into policy_count from pg_catalog.pg_policy p where p.polrelid = rel_oid and p.polcmd in ('a', 'w', 'd', '*');
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:no_client_write_policy', case when policy_count = 0 then 'PASS' else 'FAIL' end, policy_count::text || ' write policies');
  end if;

  -- Table privileges are checked only after confirming the relation exists.
  if pg_catalog.to_regclass('public.app_feature_flags') is not null then
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:authenticated_no_insert', case when not pg_catalog.has_table_privilege('authenticated', 'public.app_feature_flags', 'INSERT') then 'PASS' else 'FAIL' end, 'table INSERT privilege');
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:authenticated_no_update', case when not pg_catalog.has_table_privilege('authenticated', 'public.app_feature_flags', 'UPDATE') then 'PASS' else 'FAIL' end, 'table UPDATE privilege');
    insert into pg_temp.goat_backend_verification values ('app_feature_flags:authenticated_no_delete', case when not pg_catalog.has_table_privilege('authenticated', 'public.app_feature_flags', 'DELETE') then 'PASS' else 'FAIL' end, 'table DELETE privilege');
  end if;

  -- Statistics RPCs: catalog-only inspection, no invocation.
  foreach table_name in array array['get_daily_summary(date)', 'get_weekly_summary(date)'] loop
    fn_oid := pg_catalog.to_regprocedure('public.' || table_name);
    if fn_oid is null then
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':exists', 'FAIL', 'function is missing');
    else
      select not p.prosecdef, not (pg_catalog.coalesce(p.proargnames, array[]::text[]) @> array['user_id']::text[])
        into acl_has_public, acl_has_anon from pg_catalog.pg_proc p where p.oid = fn_oid;
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':security_invoker', case when acl_has_public then 'PASS' else 'FAIL' end, 'prosecdef=' || (not acl_has_public)::text);
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':no_user_id_argument', case when acl_has_anon then 'PASS' else 'FAIL' end, 'argument names inspected');
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':authenticated_execute', case when pg_catalog.has_function_privilege('authenticated', fn_oid, 'EXECUTE') then 'PASS' else 'FAIL' end, 'authenticated EXECUTE');
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':anon_no_execute', case when not pg_catalog.has_function_privilege('anon', fn_oid, 'EXECUTE') then 'PASS' else 'FAIL' end, 'anon EXECUTE');
      select exists (select 1 from pg_catalog.aclexplode(pg_catalog.coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'),
             pg_catalog.has_function_privilege('authenticated', fn_oid, 'EXECUTE')
        into acl_has_public, acl_has_authenticated
      from pg_catalog.pg_proc p where p.oid = fn_oid;
      insert into pg_temp.goat_backend_verification values ('rpc:' || table_name || ':public_no_execute', case when not acl_has_public then 'PASS' else 'FAIL' end, 'PUBLIC EXECUTE ACL');
    end if;
  end loop;

  -- Account deletion readiness function privileges and hardening.
  fn_oid := pg_catalog.to_regprocedure('public.assert_account_deletion_ready()');
  if fn_oid is null then
    insert into pg_temp.goat_backend_verification values ('assert_account_deletion_ready:exists', 'FAIL', 'function is missing');
  else
    select p.prosecdef, pg_catalog.coalesce(p.proconfig, array[]::text[]) @> array['search_path=']::text[]
      into acl_has_public, acl_has_anon from pg_catalog.pg_proc p where p.oid = fn_oid;
    insert into pg_temp.goat_backend_verification values ('assert_account_deletion_ready:security_definer', case when acl_has_public then 'PASS' else 'FAIL' end, 'prosecdef=' || acl_has_public::text);
    insert into pg_temp.goat_backend_verification values ('assert_account_deletion_ready:empty_search_path', case when acl_has_anon then 'PASS' else 'FAIL' end, 'search_path=' || acl_has_anon::text);
    select exists (
      select 1 from pg_catalog.aclexplode(pg_catalog.coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))) acl_row
      where acl_row.grantee = 0 and acl_row.privilege_type = 'EXECUTE'
    ) into acl_has_public
    from pg_catalog.pg_proc p where p.oid = fn_oid;
    insert into pg_temp.goat_backend_verification values ('assert_account_deletion_ready:public_no_execute', case when not acl_has_public then 'PASS' else 'FAIL' end, 'PUBLIC EXECUTE ACL');
    insert into pg_temp.goat_backend_verification values ('assert_account_deletion_ready:service_role_only', case when pg_catalog.has_function_privilege('service_role', fn_oid, 'EXECUTE') and not acl_has_public and not pg_catalog.has_function_privilege('anon', fn_oid, 'EXECUTE') and not pg_catalog.has_function_privilege('authenticated', fn_oid, 'EXECUTE') then 'PASS' else 'FAIL' end, 'service_role only');
  end if;

  fn_oid := pg_catalog.to_regprocedure('public.delete_user()');
  if fn_oid is null then
    insert into pg_temp.goat_backend_verification values ('legacy_delete_user', 'PASS', 'function is absent');
  else
    select exists (
      select 1 from pg_catalog.aclexplode(pg_catalog.coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))) acl_row
      where acl_row.grantee = 0 and acl_row.privilege_type = 'EXECUTE'
    ) into acl_has_public
    from pg_catalog.pg_proc p where p.oid = fn_oid;
    insert into pg_temp.goat_backend_verification values ('legacy_delete_user', case when not acl_has_public and not pg_catalog.has_function_privilege('anon', fn_oid, 'EXECUTE') and not pg_catalog.has_function_privilege('authenticated', fn_oid, 'EXECUTE') then 'PASS' else 'FAIL' end, 'PUBLIC, anon, and authenticated cannot execute');
  end if;

  -- Expected user tables, baseline rows, orphan rows, and FK cascade behavior.
  foreach table_name in array expected loop
    rel_oid := pg_catalog.to_regclass(pg_catalog.format('public.%I', table_name));
    if rel_oid is null then
      insert into pg_temp.goat_backend_verification values ('table:' || table_name || ':exists', 'FAIL', 'table is missing');
    else
      insert into pg_temp.goat_backend_verification values ('table:' || table_name || ':exists', 'PASS', 'table exists');
      if table_name = 'user_profiles' then expected_column := 'id'; else expected_column := 'user_id'; end if;
      if table_name in ('user_profiles', 'daily_tracking', 'chat_history') then
        execute pg_catalog.format('select count(*) from public.%I', table_name) into row_count;
        insert into pg_temp.goat_backend_verification values ('baseline:' || table_name, case when (table_name = 'user_profiles' and row_count >= 1) or (table_name = 'daily_tracking' and row_count >= 2) or (table_name = 'chat_history' and row_count >= 1) then 'PASS' else 'FAIL' end, row_count::text || ' rows');
      end if;
      if table_name <> 'user_profiles' then
        execute pg_catalog.format('select count(*) from public.%I t left join auth.users u on u.id = t.%I where u.id is null', table_name, expected_column) into orphan_count;
        insert into pg_temp.goat_backend_verification values ('orphans:' || table_name, case when orphan_count = 0 then 'PASS' else 'FAIL' end, orphan_count::text || ' orphan user_id rows');
      end if;
      insert into pg_temp.goat_backend_verification values ('fk_cascade:' || table_name, case when exists (
        select 1 from pg_catalog.pg_constraint c
        join pg_catalog.pg_class child on child.oid = c.conrelid
        join pg_catalog.pg_namespace ns on ns.oid = child.relnamespace
        where c.contype = 'f' and ns.nspname = 'public' and child.relname = table_name
          and c.confrelid = pg_catalog.to_regclass('auth.users') and c.confdeltype = 'c'
          and exists (select 1 from pg_catalog.unnest(c.conkey) k(attnum) join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum and a.attname = expected_column)
          and exists (select 1 from pg_catalog.unnest(c.confkey) k(attnum) join pg_catalog.pg_attribute a on a.attrelid = c.confrelid and a.attnum = k.attnum and a.attname = 'id')
      ) then 'PASS' else 'FAIL' end, 'FK to auth.users.id ON DELETE CASCADE');
    end if;
  end loop;

  -- Each managed trigger is verified separately, including function schema.
  foreach table_name in array array['sync_diagnostics', 'app_feature_flags'] loop
    rel_oid := pg_catalog.to_regclass(pg_catalog.format('public.%I', table_name));
    if rel_oid is null then
      insert into pg_temp.goat_backend_verification values ('trigger:' || table_name || '_updated_at', 'FAIL', 'table is missing');
    else
      insert into pg_temp.goat_backend_verification values (
        'trigger:' || table_name || '_updated_at',
        case when exists (
          select 1
          from pg_catalog.pg_trigger trigger_row
          join pg_catalog.pg_proc function_row on function_row.oid = trigger_row.tgfoid
          join pg_catalog.pg_namespace function_schema on function_schema.oid = function_row.pronamespace
          where trigger_row.tgrelid = rel_oid
            and trigger_row.tgname = table_name || '_updated_at'
            and not trigger_row.tgisinternal
            and function_schema.nspname = 'public'
            and function_row.proname = 'goat_set_updated_at'
        ) then 'PASS' else 'FAIL' end,
        'expected public.goat_set_updated_at() trigger'
      );
    end if;
  end loop;
  if pg_catalog.to_regclass('public.app_feature_flags') is not null then
    execute 'select count(*) from public.app_feature_flags where key in (''daily_summary'',''weekly_summary'',''data_export'',''account_deletion'')' into row_count;
    insert into pg_temp.goat_backend_verification values ('feature_flags:initialized', case when row_count = 4 then 'PASS' else 'FAIL' end, row_count::text || ' initialized flags');
  else
    insert into pg_temp.goat_backend_verification values ('feature_flags:initialized', 'FAIL', 'table is missing');
  end if;
end;
$$;

select check_name, status, details
from pg_temp.goat_backend_verification
order by check_name;

commit;
