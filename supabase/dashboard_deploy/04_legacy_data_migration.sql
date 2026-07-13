/*
Purpose: Preserve legacy daily water and weight values as additive detail rows.
Read-only: No.
Data modification: Inserts only valid, stable legacy rows; never deletes or rewrites old values.
Expected time: Under 30 seconds for normal daily_tracking sizes.
Success: Notices show before/after counts and totals; daily_tracking remains unchanged.
Failure/retry: Safe to rerun because stable IDs and conflict handling prevent duplicates.
*/

begin;

do $$
declare
  water_rows_before bigint := 0;
  water_total_before bigint := 0;
  water_rows_after bigint := 0;
  water_total_after bigint := 0;
  weight_rows_before bigint := 0;
  weight_rows_after bigint := 0;
  invalid_water bigint := 0;
  invalid_weight bigint := 0;
begin
  if to_regclass('public.daily_tracking') is null then
    raise notice 'REVIEW: daily_tracking is absent; no legacy migration performed';
    return;
  end if;

  select count(*), coalesce(sum(water_ml), 0)
    into water_rows_before, water_total_before
  from public.daily_tracking
  where water_ml > 0;

  select count(*) into invalid_water
  from public.daily_tracking
  where water_ml < 0;

  select count(*) into weight_rows_before
  from public.daily_tracking
  where weight_kg >= 20 and weight_kg <= 300;

  select count(*) into invalid_weight
  from public.daily_tracking
  where weight_kg <> 0 and (weight_kg < 20 or weight_kg > 300);

  insert into public.water_intake_records (
    id, user_id, date, recorded_at, amount_ml, is_legacy_aggregate
  )
  select
    'legacy_water_' || user_id::text || '_' || to_char(date::date, 'YYYY-MM-DD'),
    user_id,
    date::date,
    date::date::timestamptz,
    water_ml,
    true
  from public.daily_tracking
  where water_ml > 0
  on conflict (id) do nothing;

  insert into public.body_weight_logs (id, user_id, date, weight_kg)
  select
    'legacy_weight_' || user_id::text || '_' || to_char(date::date, 'YYYY-MM-DD'),
    user_id,
    date::date,
    weight_kg
  from public.daily_tracking
  where weight_kg >= 20 and weight_kg <= 300
  on conflict (user_id, date) do nothing;

  select count(*), coalesce(sum(amount_ml), 0)
    into water_rows_after, water_total_after
  from public.water_intake_records
  where is_legacy_aggregate = true;

  select count(*) into weight_rows_after
  from public.body_weight_logs
  where id like 'legacy_weight_%';

  raise notice 'LEGACY WATER: daily rows before=% total before=%; legacy rows after=% total after=%',
    water_rows_before, water_total_before, water_rows_after, water_total_after;
  raise notice 'LEGACY WEIGHT: valid daily rows before=%; legacy rows after=%',
    weight_rows_before, weight_rows_after;
  raise notice 'REVIEW ONLY: negative water rows=%; out-of-range weight rows=%',
    invalid_water, invalid_weight;
end $$;

commit;

select 'DAILY_WATER_COMPATIBILITY_TOTAL' as check_name,
       coalesce(sum(water_ml), 0) as total_ml
from public.daily_tracking
where water_ml > 0;

select 'LEGACY_WATER_DETAIL_TOTAL' as check_name,
       coalesce(sum(amount_ml), 0) as total_ml
from public.water_intake_records
where is_legacy_aggregate = true;

select 'LEGACY_WEIGHT_DETAIL_COUNT' as check_name,
       count(*) as row_count
from public.body_weight_logs
where id like 'legacy_weight_%';
