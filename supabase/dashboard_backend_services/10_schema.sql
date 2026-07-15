-- GOAT Phase 3C Dashboard schema and RPC package.
-- Run as one transaction in the Supabase SQL Editor.
begin;

do $$
begin
  if pg_catalog.to_regprocedure('public.goat_set_updated_at()') is null then
    raise exception 'REQUIRED_OBJECT_MISSING: public.goat_set_updated_at()';
  end if;
end;
$$;

create table if not exists public.sync_diagnostics (
  id pg_catalog.uuid primary key default pg_catalog.gen_random_uuid(),
  user_id pg_catalog.uuid not null references auth.users(id) on delete cascade,
  device_id pg_catalog.text not null check (pg_catalog.char_length(pg_catalog.btrim(device_id)) between 8 and 128),
  app_version pg_catalog.text not null check (pg_catalog.char_length(pg_catalog.btrim(app_version)) between 1 and 64),
  sync_enabled pg_catalog.boolean not null,
  pending_operations pg_catalog.integer not null default 0 check (pending_operations >= 0),
  last_success_at pg_catalog.timestamptz,
  last_error_code pg_catalog.text check (last_error_code is null or last_error_code ~ '^[A-Z0-9_]{1,64}$'),
  last_error_at pg_catalog.timestamptz,
  updated_at pg_catalog.timestamptz not null default pg_catalog.now(),
  unique (user_id, device_id)
);
alter table public.sync_diagnostics enable row level security;

create table if not exists public.app_feature_flags (
  key pg_catalog.text primary key check (key ~ '^[a-z][a-z0-9_]{1,63}$'),
  enabled pg_catalog.boolean not null default false,
  config pg_catalog.jsonb not null default '{}'::pg_catalog.jsonb check (pg_catalog.jsonb_typeof(config) = 'object'),
  minimum_app_version pg_catalog.text,
  updated_at pg_catalog.timestamptz not null default pg_catalog.now()
);
alter table public.app_feature_flags enable row level security;

drop trigger if exists sync_diagnostics_updated_at on public.sync_diagnostics;
create trigger sync_diagnostics_updated_at before update on public.sync_diagnostics
for each row execute function public.goat_set_updated_at();
drop trigger if exists app_feature_flags_updated_at on public.app_feature_flags;
create trigger app_feature_flags_updated_at before update on public.app_feature_flags
for each row execute function public.goat_set_updated_at();

insert into public.app_feature_flags (key, enabled, config) values
  ('versioned_sync', false, '{}'::pg_catalog.jsonb),
  ('nutrition_ai', true, '{}'::pg_catalog.jsonb),
  ('training_ai_insights', false, '{}'::pg_catalog.jsonb),
  ('voice_entry', true, '{}'::pg_catalog.jsonb)
on conflict (key) do nothing;

create or replace function public.get_daily_summary(p_date pg_catalog.date)
returns table (
  date pg_catalog.date,
  calories_in pg_catalog.numeric,
  calories_burned pg_catalog.numeric,
  net_calories pg_catalog.numeric,
  protein_g pg_catalog.numeric,
  carbs_g pg_catalog.numeric,
  fat_g pg_catalog.numeric,
  water_ml pg_catalog.bigint,
  weight_kg pg_catalog.numeric,
  exercise_count pg_catalog.bigint,
  training_count pg_catalog.bigint,
  training_volume_kg pg_catalog.numeric,
  completed_sets pg_catalog.bigint
)
language sql
security invoker
stable
as $$
  with current_user_row as (select auth.uid() as id),
  diet as (
    select
      coalesce(sum(d.kcal), 0)::pg_catalog.numeric as calories_in,
      coalesce(sum(d.p), 0)::pg_catalog.numeric as protein_g,
      coalesce(sum(d.c), 0)::pg_catalog.numeric as carbs_g,
      coalesce(sum(d.f), 0)::pg_catalog.numeric as fat_g
    from public.diet_logs d
    join current_user_row u on u.id = d.user_id
    where d.date = p_date and d.deleted_at is null
  ),
  exercise as (
    select
      coalesce(sum(e.kcal), 0)::pg_catalog.numeric as calories_burned,
      count(*)::pg_catalog.bigint as exercise_count
    from public.exercise_logs e
    join current_user_row u on u.id = e.user_id
    where e.date = p_date and e.deleted_at is null
  ),
  water as (
    select coalesce(sum(w.amount_ml), 0)::pg_catalog.bigint as water_ml
    from public.water_intake_records w
    join current_user_row u on u.id = w.user_id
    where w.date = p_date and w.deleted_at is null
  ),
  weight as (
    select max(b.weight_kg)::pg_catalog.numeric as weight_kg
    from public.body_weight_logs b
    join current_user_row u on u.id = b.user_id
    where b.date = p_date and b.deleted_at is null
  ),
  training as (
    select
      count(*)::pg_catalog.bigint as training_count,
      coalesce(sum(metrics.training_volume), 0)::pg_catalog.numeric as training_volume_kg,
      coalesce(sum(metrics.completed_sets), 0)::pg_catalog.bigint as completed_sets
    from public.training_sessions t
    join current_user_row u on u.id = t.user_id
    left join lateral (
      select
        coalesce(sum(
          case when pg_catalog.jsonb_typeof(s.value->'weight') = 'number'
            then coalesce((s.value->>'weight')::pg_catalog.numeric, 0) else 0 end *
          case when pg_catalog.jsonb_typeof(s.value->'reps') = 'number'
            and (s.value->>'reps') ~ '^[0-9]+$'
            then coalesce((s.value->>'reps')::pg_catalog.numeric, 0) else 0 end
        ), 0)::pg_catalog.numeric as training_volume,
        count(*) filter (
          where pg_catalog.jsonb_typeof(s.value->'reps') = 'number'
            and (s.value->>'reps') ~ '^[1-9][0-9]*$'
        )::pg_catalog.bigint as completed_sets
      from pg_catalog.jsonb_array_elements(
        case when pg_catalog.jsonb_typeof(t.exercises) = 'array' then t.exercises else '[]'::pg_catalog.jsonb end
      ) exercise_item(value)
      cross join lateral pg_catalog.jsonb_array_elements(
        case when pg_catalog.jsonb_typeof(exercise_item.value->'sets') = 'array'
          then exercise_item.value->'sets' else '[]'::pg_catalog.jsonb end
      ) s(value)
    ) metrics on true
    where t.date = p_date and t.deleted_at is null
  )
  select
    p_date,
    diet.calories_in,
    exercise.calories_burned,
    diet.calories_in - exercise.calories_burned,
    diet.protein_g,
    diet.carbs_g,
    diet.fat_g,
    water.water_ml,
    weight.weight_kg,
    exercise.exercise_count,
    training.training_count,
    training.training_volume_kg,
    training.completed_sets
  from diet cross join exercise cross join water cross join weight cross join training;
$$;

create or replace function public.get_weekly_summary(p_start_date pg_catalog.date)
returns table (
  start_date pg_catalog.date,
  end_date pg_catalog.date,
  days pg_catalog.jsonb,
  average_calories_in pg_catalog.numeric,
  average_calories_burned pg_catalog.numeric,
  average_water_ml pg_catalog.numeric,
  average_training_volume_kg pg_catalog.numeric,
  training_count pg_catalog.bigint,
  weight_start_kg pg_catalog.numeric,
  weight_end_kg pg_catalog.numeric,
  weight_change_kg pg_catalog.numeric,
  average_macro_goal_completion_pct pg_catalog.numeric
)
language sql
security invoker
stable
as $$
  with daily as (
    select summary.*
    from pg_catalog.generate_series(p_start_date, p_start_date + 6, interval '1 day') day_value(day)
    cross join lateral public.get_daily_summary(day_value.day::pg_catalog.date) summary
  ),
  profile as (
    select p.target_p, p.target_c, p.target_f
    from public.user_profiles p
    where p.id = auth.uid()
  ),
  goal_values as (
    select
      case when profile.target_p > 0 then daily.protein_g / profile.target_p end as protein_ratio,
      case when profile.target_c > 0 then daily.carbs_g / profile.target_c end as carbs_ratio,
      case when profile.target_f > 0 then daily.fat_g / profile.target_f end as fat_ratio
    from daily
    left join profile on true
  ),
  weights as (
    select nullif(daily.weight_kg, 0) as weight_kg, daily.date
    from daily
    where daily.weight_kg is not null
    order by daily.date
  ),
  weight_bounds as (
    select
      (pg_catalog.array_agg(weights.weight_kg order by weights.date))[1] as weight_start_kg,
      (pg_catalog.array_agg(weights.weight_kg order by weights.date))[pg_catalog.count(*)::pg_catalog.integer] as weight_end_kg
    from weights
  ),
  macro_totals as (
    select
      coalesce(sum(goal.protein_ratio) filter (where goal.protein_ratio is not null), 0) +
      coalesce(sum(goal.carbs_ratio) filter (where goal.carbs_ratio is not null), 0) +
      coalesce(sum(goal.fat_ratio) filter (where goal.fat_ratio is not null), 0) as ratio_sum,
      count(goal.protein_ratio) + count(goal.carbs_ratio) + count(goal.fat_ratio) as ratio_count
    from goal_values goal
  )
  select
    p_start_date,
    p_start_date + 6,
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date', daily.date,
      'calories_in', daily.calories_in,
      'calories_burned', daily.calories_burned,
      'water_ml', daily.water_ml,
      'weight_kg', daily.weight_kg,
      'training_volume_kg', daily.training_volume_kg
    ) order by daily.date),
    coalesce(avg(daily.calories_in), 0),
    coalesce(avg(daily.calories_burned), 0),
    coalesce(avg(daily.water_ml), 0),
    coalesce(avg(daily.training_volume_kg), 0),
    coalesce(sum(daily.training_count), 0)::pg_catalog.bigint,
    weight_bounds.weight_start_kg,
    weight_bounds.weight_end_kg,
    weight_bounds.weight_end_kg - weight_bounds.weight_start_kg,
    coalesce(macro_totals.ratio_sum / nullif(macro_totals.ratio_count, 0) * 100, 0)
  from daily
  cross join weight_bounds
  cross join macro_totals
  group by weight_bounds.weight_start_kg, weight_bounds.weight_end_kg,
    macro_totals.ratio_sum, macro_totals.ratio_count;
$$;

create or replace function public.assert_account_deletion_ready()
returns pg_catalog.boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  table_name pg_catalog.text;
  column_name pg_catalog.text;
  expected_tables pg_catalog.text[] := pg_catalog.array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'sync_tombstones', 'client_operations',
    'ai_usage_daily', 'sync_diagnostics'
  ];
begin
  foreach table_name in array expected_tables loop
    column_name := case when table_name = 'user_profiles' then 'id' else 'user_id' end;
    if pg_catalog.to_regclass(pg_catalog.format('public.%I', table_name)) is null then
      raise exception 'ACCOUNT_DELETION_TABLE_MISSING:%', table_name using errcode = 'check_violation';
    end if;
    if not exists (
      select 1
      from pg_catalog.pg_constraint constraint_row
      join pg_catalog.pg_class source_table on source_table.oid = constraint_row.conrelid
      join pg_catalog.pg_namespace source_schema on source_schema.oid = source_table.relnamespace
      join pg_catalog.pg_attribute source_column
        on source_column.attrelid = source_table.oid
       and source_column.attnum = any(constraint_row.conkey)
      join pg_catalog.pg_attribute target_column
        on target_column.attrelid = constraint_row.confrelid
       and target_column.attnum = any(constraint_row.confkey)
      where constraint_row.contype = 'f'
        and constraint_row.confrelid = 'auth.users'::pg_catalog.regclass
        and constraint_row.confdeltype = 'c'
        and source_schema.nspname = 'public'
        and source_table.relname = table_name
        and source_column.attname = column_name
        and target_column.attname = 'id'
        and pg_catalog.cardinality(constraint_row.conkey) = 1
        and pg_catalog.cardinality(constraint_row.confkey) = 1
    ) then
      raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%', table_name using errcode = 'check_violation';
    end if;
  end loop;

  if pg_catalog.to_regclass('public.chat_history') is not null and not exists (
    select 1
    from pg_catalog.pg_constraint constraint_row
    join pg_catalog.pg_class source_table on source_table.oid = constraint_row.conrelid
    join pg_catalog.pg_namespace source_schema on source_schema.oid = source_table.relnamespace
    join pg_catalog.pg_attribute source_column
      on source_column.attrelid = source_table.oid
     and source_column.attnum = any(constraint_row.conkey)
    join pg_catalog.pg_attribute target_column
      on target_column.attrelid = constraint_row.confrelid
     and target_column.attnum = any(constraint_row.confkey)
    where constraint_row.contype = 'f'
      and constraint_row.confrelid = 'auth.users'::pg_catalog.regclass
      and constraint_row.confdeltype = 'c'
      and source_schema.nspname = 'public'
      and source_table.relname = 'chat_history'
      and source_column.attname = 'user_id'
      and target_column.attname = 'id'
      and pg_catalog.cardinality(constraint_row.conkey) = 1
      and pg_catalog.cardinality(constraint_row.confkey) = 1
  ) then
    raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history' using errcode = 'check_violation';
  end if;
  return true;
end;
$$;

revoke all on function public.get_daily_summary(pg_catalog.date), public.get_weekly_summary(pg_catalog.date)
  from public, anon, authenticated;
grant execute on function public.get_daily_summary(pg_catalog.date), public.get_weekly_summary(pg_catalog.date)
  to authenticated;
revoke all on function public.assert_account_deletion_ready() from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready() to service_role;

do $$
begin
  if pg_catalog.to_regprocedure('public.delete_user()') is not null then
    execute 'revoke all on function public.delete_user() from public, anon, authenticated';
  end if;
end;
$$;

commit;
