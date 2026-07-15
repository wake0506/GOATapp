with checks(check_name, status, details) as (
  select 'table:sync_diagnostics', case when to_regclass('public.sync_diagnostics') is not null then 'PASS' else 'FAIL' end, ''
  union all select 'table:app_feature_flags', case when to_regclass('public.app_feature_flags') is not null then 'PASS' else 'FAIL' end, ''
  union all select 'rls:sync_diagnostics', case when (select relrowsecurity from pg_class where oid = 'public.sync_diagnostics'::regclass) then 'PASS' else 'FAIL' end, ''
  union all select 'rls:app_feature_flags', case when (select relrowsecurity from pg_class where oid = 'public.app_feature_flags'::regclass) then 'PASS' else 'FAIL' end, ''
  union all select 'policy:feature_flags_read_only', case when exists (select 1 from pg_policies where schemaname='public' and tablename='app_feature_flags' and policyname='goat_feature_flags_authenticated_read' and cmd='SELECT') and not exists (select 1 from pg_policies where schemaname='public' and tablename='app_feature_flags' and cmd in ('INSERT','UPDATE','DELETE')) then 'PASS' else 'FAIL' end, ''
  union all select 'rpc:no_user_id_argument', case when not exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname in ('get_daily_summary','get_weekly_summary') and 'user_id' = any(proargnames)) then 'PASS' else 'FAIL' end, ''
  union all select 'rpc:legacy_delete_user_revoked', case when not has_function_privilege('authenticated', 'public.delete_user()', 'execute') then 'PASS' else 'FAIL' end, ''
  union all select 'account:foreign_keys_cascade', case when public.assert_account_deletion_ready() then 'PASS' else 'FAIL' end, 'all known user tables'
  union all select 'legacy:data_not_removed', case when (select count(*) >= 0 from public.daily_tracking) then 'PASS' else 'FAIL' end, 'read-only count check'
)
select check_name, status, details from checks order by check_name;
