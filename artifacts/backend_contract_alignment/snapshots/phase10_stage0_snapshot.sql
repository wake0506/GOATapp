\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
select pg_catalog.md5(pg_catalog.concat_ws(
  '|',
  (select pg_catalog.count(*)::text from public.user_profiles),
  (select pg_catalog.count(*)::text from public.food_dictionary),
  (select pg_catalog.count(*)::text from public.diet_logs),
  (select pg_catalog.count(*)::text from public.exercise_logs),
  (select pg_catalog.count(*)::text from public.daily_tracking),
  (select pg_catalog.count(*)::text from public.water_intake_records),
  (select pg_catalog.count(*)::text from public.body_weight_logs),
  (select pg_catalog.count(*)::text from public.training_sessions),
  (select pg_catalog.count(*)::text from public.sync_tombstones),
  (select pg_catalog.count(*)::text from public.client_operations),
  (select pg_catalog.count(*)::text from public.ai_usage_daily),
  (select pg_catalog.count(*)::text from public.sync_diagnostics)
));
