\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select pg_catalog.md5(pg_catalog.concat_ws(
  '|',
  (select count(*)::text from public.user_profiles),
  (select count(*)::text from public.food_dictionary),
  (select count(*)::text from public.diet_logs),
  (select count(*)::text from public.exercise_logs),
  (select count(*)::text from public.daily_tracking),
  (select count(*)::text from public.water_intake_records),
  (select count(*)::text from public.body_weight_logs),
  (select count(*)::text from public.training_sessions),
  (select count(*)::text from public.sync_tombstones),
  (select count(*)::text from public.client_operations),
  (select count(*)::text from public.ai_usage_daily),
  (select count(*)::text from public.sync_diagnostics),
  (select count(*)::text from public.app_feature_flags),
  (select coalesce((select enabled::text from public.app_feature_flags where key='versioned_sync'),'missing'))
));
