/*
Purpose: Add timestamp triggers, indexes, range checks and operation constraints.
Read-only: No.
Data modification: Changes metadata and validates new writes; does not delete rows.
Expected time: Under 60 seconds, depending on index size.
Success: Updated timestamps are automatic and required checks/indexes exist.
Failure/retry: Safe to rerun. Existing rows are not removed; NOT VALID checks need later review.
*/

begin;

create or replace function public.goat_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.goat_add_check_if_missing(
  table_name text,
  constraint_name text,
  expression text
)
returns void
language plpgsql
as $$
begin
  if to_regclass('public.' || table_name) is null then
    return;
  end if;
  if not exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = table_name
      and c.conname = constraint_name
  ) then
    execute format(
      'alter table public.%I add constraint %I check (%s) not valid',
      table_name, constraint_name, expression
    );
  end if;
end;
$$;

create unique index if not exists food_dictionary_client_operation_idx
  on public.food_dictionary (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists diet_logs_client_operation_idx
  on public.diet_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists exercise_logs_client_operation_idx
  on public.exercise_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists water_intake_records_client_operation_idx
  on public.water_intake_records (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists body_weight_logs_client_operation_idx
  on public.body_weight_logs (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists training_sessions_client_operation_idx
  on public.training_sessions (user_id, client_operation_id)
  where client_operation_id is not null;

create index if not exists food_dictionary_updated_idx on public.food_dictionary (user_id, updated_at);
create index if not exists diet_logs_updated_idx on public.diet_logs (user_id, updated_at);
create index if not exists exercise_logs_updated_idx on public.exercise_logs (user_id, updated_at);
create index if not exists daily_tracking_updated_idx on public.daily_tracking (user_id, updated_at);
create index if not exists water_intake_records_updated_idx on public.water_intake_records (user_id, updated_at);
create index if not exists body_weight_logs_updated_idx on public.body_weight_logs (user_id, updated_at);
create index if not exists training_sessions_updated_idx on public.training_sessions (user_id, updated_at);
create index if not exists sync_tombstones_updated_idx on public.sync_tombstones (user_id, updated_at);

select public.goat_add_check_if_missing('user_profiles', 'user_profiles_weight_range',
  'current_weight >= 20 and current_weight <= 300');
select public.goat_add_check_if_missing('food_dictionary', 'food_dictionary_nutrition_nonnegative',
  'protein >= 0 and carbs >= 0 and fat >= 0 and calories >= 0');
select public.goat_add_check_if_missing('diet_logs', 'diet_logs_nutrition_nonnegative',
  'p >= 0 and c >= 0 and f >= 0 and kcal >= 0 and amount >= 0');
select public.goat_add_check_if_missing('diet_logs', 'diet_logs_meal_type_valid',
  'meal_type in (''早餐'', ''午餐'', ''晚餐'', ''加餐'')');
select public.goat_add_check_if_missing('exercise_logs', 'exercise_logs_kcal_nonnegative',
  'kcal >= 0');
select public.goat_add_check_if_missing('daily_tracking', 'daily_tracking_water_nonnegative',
  'water_ml >= 0');
select public.goat_add_check_if_missing('daily_tracking', 'daily_tracking_weight_range',
  'weight_kg = 0 or (weight_kg >= 20 and weight_kg <= 300)');
select public.goat_add_check_if_missing('water_intake_records', 'water_intake_amount_range',
  'amount_ml > 0 and amount_ml <= 10000');
select public.goat_add_check_if_missing('body_weight_logs', 'body_weight_range',
  'weight_kg >= 20 and weight_kg <= 300');
select public.goat_add_check_if_missing('ai_usage_daily', 'ai_usage_nonnegative',
  'request_count >= 0');
select public.goat_add_check_if_missing('client_operations', 'client_operations_action_valid',
  'action in (''upsert'', ''delete'')');

do $$
declare
  table_name text;
  trigger_name text;
begin
  foreach table_name in array array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      trigger_name := table_name || '_updated_at';
      if not exists (
        select 1 from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        join pg_namespace n on n.oid = c.relnamespace
        where t.tgname = trigger_name and c.relname = table_name
          and n.nspname = 'public' and not t.tgisinternal
      ) then
        execute format(
          'create trigger %I before update on public.%I for each row execute function public.goat_set_updated_at()',
          trigger_name, table_name
        );
      end if;
    end if;
  end loop;
end $$;

commit;
