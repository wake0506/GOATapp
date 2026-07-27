-- GOAT production compatibility migration DRAFT (not in supabase/migrations).
-- Generated for the confirmed production schema drift. Do not execute until
-- qasz regression and explicit production approval are complete.
-- This file is additive: it preserves Stage 0 tables/data and does not reset,
-- truncate, delete, or copy test data.

begin;

do $compatibility_preflight$
declare
  required_table text;
  required_tables text[] := array[
    'user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs',
    'daily_tracking', 'water_intake_records', 'body_weight_logs',
    'training_sessions', 'client_operations', 'ai_usage_daily', 'chat_history'
  ];
begin
  if pg_catalog.to_regprocedure('public.goat_set_updated_at()') is null then
    raise exception 'REQUIRED_OBJECT_MISSING: public.goat_set_updated_at()';
  end if;
  foreach required_table in array required_tables loop
    if pg_catalog.to_regclass('public.' || required_table) is null then
      raise exception 'REQUIRED_TABLE_MISSING: public.%', required_table;
    end if;
  end loop;
  if not exists (
    select 1 from pg_catalog.pg_attribute
    where attrelid = pg_catalog.to_regclass('public.chat_history')
      and attname = 'user_id' and not attisdropped
  ) then
    raise exception 'REQUIRED_COLUMN_MISSING: public.chat_history.user_id';
  end if;
  if exists (
    select 1
    from public.chat_history h
    left join auth.users u on u.id = h.user_id
    where u.id is null
  ) then
    raise exception 'ORPHAN_DATA_BLOCKS_COMPATIBILITY: public.chat_history.user_id';
  end if;
end;
$compatibility_preflight$;

-- GOAT phase 3C: additive server-side data services. Do not edit prior migrations.

create table if not exists public.sync_diagnostics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(trim(device_id)) between 8 and 128),
  app_version text not null check (char_length(trim(app_version)) between 1 and 64),
  sync_enabled boolean not null,
  pending_operations integer not null default 0 check (pending_operations >= 0),
  last_success_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[A-Z0-9_]{1,64}$'),
  last_error_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create table if not exists public.app_feature_flags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,63}$'),
  enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  minimum_app_version text,
  updated_at timestamptz not null default now()
);

drop trigger if exists sync_diagnostics_updated_at on public.sync_diagnostics;
create trigger sync_diagnostics_updated_at before update on public.sync_diagnostics
for each row execute function public.goat_set_updated_at();
drop trigger if exists app_feature_flags_updated_at on public.app_feature_flags;
create trigger app_feature_flags_updated_at before update on public.app_feature_flags
for each row execute function public.goat_set_updated_at();

insert into public.app_feature_flags (key, enabled, config) values
  ('versioned_sync', false, '{}'::jsonb),
  ('nutrition_ai', true, '{}'::jsonb),
  ('training_ai_insights', false, '{}'::jsonb),
  ('voice_entry', true, '{}'::jsonb)
on conflict (key) do nothing;

do $$
declare
  chat_rel oid;
  user_id_attnum smallint;
  auth_id_attnum smallint;
  fk record;
  had_user_id_fk boolean := false;
  has_cascade_fk boolean := false;
begin
  chat_rel := pg_catalog.to_regclass('public.chat_history');
  if chat_rel is null then
    return;
  end if;

  select attribute_row.attnum into user_id_attnum
  from pg_catalog.pg_attribute attribute_row
  where attribute_row.attrelid = chat_rel
    and attribute_row.attname = 'user_id'
    and attribute_row.attnum > 0
    and not attribute_row.attisdropped;
  if user_id_attnum is null then
    raise exception 'CHAT_HISTORY_USER_ID_MISSING';
  end if;

  if exists (
    select 1 from public.chat_history chat_row
    left join auth.users auth_user on auth_user.id = chat_row.user_id
    where chat_row.user_id is not null and auth_user.id is null
  ) then
    raise exception 'CHAT_HISTORY_ORPHAN_USER_ID';
  end if;

  select attribute_row.attnum into auth_id_attnum
  from pg_catalog.pg_attribute attribute_row
  where attribute_row.attrelid = pg_catalog.to_regclass('auth.users')
    and attribute_row.attname = 'id'
    and attribute_row.attnum > 0
    and not attribute_row.attisdropped;

  for fk in
    select constraint_row.conname, constraint_row.confdeltype
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.contype = 'f'
      and constraint_row.conrelid = chat_rel
      and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
      and constraint_row.conkey = array[user_id_attnum]::smallint[]
      and constraint_row.confkey = array[auth_id_attnum]::smallint[]
  loop
    had_user_id_fk := true;
    if fk.confdeltype = 'c' then
      has_cascade_fk := true;
    else
      execute pg_catalog.format('alter table public.chat_history drop constraint %I', fk.conname);
    end if;
  end loop;

  if not has_cascade_fk then
    if had_user_id_fk then
      alter table public.chat_history
        add constraint goat_chat_history_user_id_fkey
        foreign key (user_id) references auth.users(id) on delete cascade;
    else
      alter table public.chat_history
        add constraint goat_chat_history_user_id_fkey
        foreign key (user_id) references auth.users(id) on delete cascade not valid;
      alter table public.chat_history
        validate constraint goat_chat_history_user_id_fkey;
    end if;
  end if;
end;
$$;

alter table public.sync_diagnostics enable row level security;
alter table public.app_feature_flags enable row level security;
drop policy if exists goat_sync_diagnostics_select_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_insert_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_update_own on public.sync_diagnostics;
drop policy if exists goat_sync_diagnostics_delete_own on public.sync_diagnostics;
create policy goat_sync_diagnostics_select_own on public.sync_diagnostics for select to authenticated using (auth.uid() = user_id);
create policy goat_sync_diagnostics_insert_own on public.sync_diagnostics for insert to authenticated with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_update_own on public.sync_diagnostics for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_delete_own on public.sync_diagnostics for delete to authenticated using (auth.uid() = user_id);
drop policy if exists goat_feature_flags_authenticated_read on public.app_feature_flags;
create policy goat_feature_flags_authenticated_read on public.app_feature_flags for select to authenticated using (auth.uid() is not null);
revoke all on table public.sync_diagnostics, public.app_feature_flags from anon;
grant select, insert, update, delete on table public.sync_diagnostics to authenticated;
grant select on table public.app_feature_flags to authenticated;
revoke insert, update, delete on table public.app_feature_flags from authenticated;

create or replace function public.get_daily_summary(p_date date)
returns table (
  date date,
  calories_in numeric,
  calories_burned numeric,
  net_calories numeric,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  water_ml bigint,
  weight_kg numeric,
  exercise_count bigint,
  training_count bigint,
  training_volume_kg numeric,
  completed_sets bigint
)
language sql
security invoker
set search_path = public
stable
as $$
  with current_user_data as (select auth.uid() as id),
  diet as (
    select coalesce(sum(d.kcal), 0) as calories_in,
           coalesce(sum(d.p), 0) as protein_g,
           coalesce(sum(d.c), 0) as carbs_g,
           coalesce(sum(d.f), 0) as fat_g
    from public.diet_logs d join current_user_data u on d.user_id = u.id
    where d.date = p_date and d.deleted_at is null
  ), exercise as (
    select coalesce(sum(e.kcal), 0) as calories_burned, count(*) as exercise_count
    from public.exercise_logs e join current_user_data u on e.user_id = u.id
    where e.date = p_date and e.deleted_at is null
  ), water as (
    select coalesce(sum(w.amount_ml), 0)::bigint as water_ml
    from public.water_intake_records w join current_user_data u on w.user_id = u.id
    where w.date = p_date and w.deleted_at is null
  ), weight as (
    select coalesce(max(b.weight_kg), 0) as weight_kg
    from public.body_weight_logs b join current_user_data u on b.user_id = u.id
    where b.date = p_date and b.deleted_at is null
  ), training as (
    select count(*)::bigint as training_count,
           coalesce(sum(x.volume), 0) as training_volume_kg,
           coalesce(sum(x.completed_sets), 0)::bigint as completed_sets
    from public.training_sessions t
    join current_user_data u on t.user_id = u.id
    cross join lateral (
      select coalesce(sum(coalesce((s.value->>'weight')::numeric, 0) * coalesce((s.value->>'reps')::numeric, 0)), 0) as volume,
             count(s.value) filter (where coalesce((s.value->>'reps')::integer, 0) > 0) as completed_sets
      from jsonb_array_elements(coalesce(t.exercises, '[]'::jsonb)) e(value)
      cross join lateral jsonb_array_elements(coalesce(e.value->'sets', '[]'::jsonb)) s(value)
    ) x
    where t.date = p_date and t.deleted_at is null
  )
  select p_date, diet.calories_in, exercise.calories_burned,
         diet.calories_in - exercise.calories_burned,
         diet.protein_g, diet.carbs_g, diet.fat_g, water.water_ml, weight.weight_kg,
         exercise.exercise_count, training.training_count, training.training_volume_kg, training.completed_sets
  from diet cross join exercise cross join water cross join weight cross join training;
$$;

create or replace function public.get_weekly_summary(p_start_date date)
returns table (
  start_date date,
  end_date date,
  days jsonb,
  average_calories_in numeric,
  average_calories_burned numeric,
  average_water_ml numeric,
  average_training_volume_kg numeric,
  training_count bigint,
  weight_start_kg numeric,
  weight_end_kg numeric,
  weight_change_kg numeric,
  average_macro_goal_completion_pct numeric
)
language sql
security invoker
set search_path = public
stable
as $$
  with current_user_data as (select auth.uid() as id),
  day_rows as (
    select * from generate_series(p_start_date, p_start_date + 6, interval '1 day') d(day)
  ), daily as (
    select s.* from day_rows r cross join lateral public.get_daily_summary(r.day::date) s
  ), profile as (
    select target_p, target_c, target_f from public.user_profiles p join current_user_data u on p.id = u.id
  ), macros as (
    select avg(case when profile.target_p > 0 then d.protein_g / profile.target_p else null end) +
           avg(case when profile.target_c > 0 then d.carbs_g / profile.target_c else null end) +
           avg(case when profile.target_f > 0 then d.fat_g / profile.target_f else null end) as three_macro_average
    from daily d cross join profile
  ), weights as (
    select weight_kg, date from daily where weight_kg > 0 order by date
  )
  select p_start_date, p_start_date + 6,
         jsonb_agg(jsonb_build_object('date', date, 'calories_in', calories_in,
           'calories_burned', calories_burned, 'water_ml', water_ml,
           'weight_kg', nullif(weight_kg, 0), 'training_volume_kg', training_volume_kg) order by date),
         avg(calories_in), avg(calories_burned), avg(water_ml), avg(training_volume_kg), sum(training_count),
         (select weight_kg from weights limit 1),
         (select weight_kg from weights offset greatest((select count(*) from weights) - 1, 0) limit 1),
         (select (select weight_kg from weights offset greatest((select count(*) from weights) - 1, 0) limit 1) - (select weight_kg from weights limit 1)),
         coalesce((select three_macro_average from macros) * 100 / 3, 0)
  from daily;
$$;

create or replace function public.assert_account_deletion_ready()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  table_name text;
  column_name text;
begin
  foreach table_name in array array['user_profiles', 'food_dictionary', 'diet_logs', 'exercise_logs', 'daily_tracking', 'water_intake_records', 'body_weight_logs', 'training_sessions', 'sync_tombstones', 'client_operations', 'ai_usage_daily', 'sync_diagnostics'] loop
    column_name := case when table_name = 'user_profiles' then 'id' else 'user_id' end;
    if not exists (
      select 1 from pg_constraint c join pg_class r on r.oid = c.conrelid
      join pg_namespace n on n.oid = r.relnamespace
      join pg_attribute a on a.attrelid = r.oid and a.attnum = any(c.conkey)
      where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c'
        and n.nspname = 'public' and r.relname = table_name and a.attname = column_name
    ) then
      raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%', table_name using errcode = 'check_violation';
    end if;
  end loop;
  if to_regclass('public.chat_history') is not null and not exists (
    select 1 from pg_constraint c join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    join pg_attribute a on a.attrelid = r.oid and a.attnum = any(c.conkey)
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c'
      and n.nspname = 'public' and r.relname = 'chat_history' and a.attname = 'user_id'
  ) then
    raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history' using errcode = 'check_violation';
  end if;
  return true;
end;
$$;

revoke all on function public.assert_account_deletion_ready() from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready() to service_role;
do $$
begin
  if pg_catalog.to_regprocedure('public.delete_user()') is not null then
    execute 'revoke all on function public.delete_user() from public';
    execute 'revoke all on function public.delete_user() from anon';
    execute 'revoke all on function public.delete_user() from authenticated';
  end if;
end;
$$;
revoke all on function public.get_daily_summary(date), public.get_weekly_summary(date) from public, anon;
grant execute on function public.get_daily_summary(date), public.get_weekly_summary(date) to authenticated;

-- Production currently has a PUBLIC/ALL chat policy. Remove only client-wide
-- policies and replace them with authenticated own-row CRUD policies.
do $chat_history_policy_hardening$
declare
  policy_name text;
begin
  if pg_catalog.to_regclass('public.chat_history') is not null then
    alter table public.chat_history enable row level security;
    for policy_name in
      select p.policyname
      from pg_catalog.pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'chat_history'
        and ('public' = any(p.roles) or 'anon' = any(p.roles))
    loop
      execute pg_catalog.format('drop policy if exists %I on public.chat_history', policy_name);
    end loop;
    drop policy if exists goat_chat_history_select_own on public.chat_history;
    drop policy if exists goat_chat_history_insert_own on public.chat_history;
    drop policy if exists goat_chat_history_update_own on public.chat_history;
    drop policy if exists goat_chat_history_delete_own on public.chat_history;
    create policy goat_chat_history_select_own on public.chat_history
      for select to authenticated using (auth.uid() = user_id);
    create policy goat_chat_history_insert_own on public.chat_history
      for insert to authenticated with check (auth.uid() = user_id);
    create policy goat_chat_history_update_own on public.chat_history
      for update to authenticated using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
    create policy goat_chat_history_delete_own on public.chat_history
      for delete to authenticated using (auth.uid() = user_id);
  end if;
end;
$chat_history_policy_hardening$;

-- Contract alignment objects are applied in the same transaction.
-- GOAT backend/frontend contract alignment.
-- Additive only. This migration does not deploy Edge Functions and does not
-- enable versioned_sync.

do $preflight$
begin
  if pg_catalog.to_regprocedure('public.goat_set_updated_at()') is null then
    raise exception 'REQUIRED_OBJECT_MISSING: public.goat_set_updated_at()';
  end if;
  if pg_catalog.to_regclass('public.training_sessions') is null then
    raise exception 'REQUIRED_TABLE_MISSING: public.training_sessions';
  end if;
  if pg_catalog.to_regclass('public.client_operations') is null then
    raise exception 'REQUIRED_TABLE_MISSING: public.client_operations';
  end if;
end;
$preflight$;

-- Completed sessions remain one JSON contract. PostgreSQL stores and returns
-- the object without projecting or rewriting optional frontend fields.
do $training_contract$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.conrelid = 'public.training_sessions'::pg_catalog.regclass
      and constraint_row.conname = 'training_sessions_exercises_array'
  ) then
    alter table public.training_sessions
      add constraint training_sessions_exercises_array
      check (pg_catalog.jsonb_typeof(exercises) = 'array')
      not valid;
  end if;
end;
$training_contract$;

alter table public.training_sessions
  validate constraint training_sessions_exercises_array;

create table if not exists public.training_templates (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  name text not null,
  exercise_ids jsonb not null default '[]'::jsonb,
  progression_targets jsonb not null default '{}'::jsonb,
  rest_prescriptions jsonb not null default '{}'::jsonb,
  superset_groups jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint training_templates_name_not_blank
    check (pg_catalog.btrim(name) <> ''),
  constraint training_templates_exercise_ids_array
    check (pg_catalog.jsonb_typeof(exercise_ids) = 'array'),
  constraint training_templates_progression_targets_object
    check (pg_catalog.jsonb_typeof(progression_targets) = 'object'),
  constraint training_templates_rest_prescriptions_object
    check (pg_catalog.jsonb_typeof(rest_prescriptions) = 'object'),
  constraint training_templates_superset_groups_object
    check (pg_catalog.jsonb_typeof(superset_groups) = 'object')
);
alter table public.training_templates enable row level security;

create table if not exists public.ai_memories (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  stable_key text,
  category text not null,
  value text not null,
  structured_value jsonb not null default '{}'::jsonb,
  source_type text not null,
  status text not null,
  source_refs jsonb not null default '[]'::jsonb,
  confidence_level text,
  user_confirmed boolean not null default false,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint ai_memories_structured_value_object
    check (pg_catalog.jsonb_typeof(structured_value) = 'object'),
  constraint ai_memories_source_refs_array
    check (pg_catalog.jsonb_typeof(source_refs) = 'array'),
  constraint ai_memories_source_type_valid
    check (source_type in ('userProvided', 'behaviorDerived', 'aiInferred')),
  constraint ai_memories_status_valid
    check (status in ('active', 'pendingConfirmation', 'rejected', 'incorrect', 'archived')),
  constraint ai_memories_confidence_valid
    check (confidence_level is null or confidence_level in ('high', 'medium', 'low')),
  constraint ai_memories_inferred_confirmation_safe
    check (
      source_type <> 'aiInferred'
      or status <> 'active'
      or user_confirmed
    )
);
alter table public.ai_memories enable row level security;

create table if not exists public.ai_suggestions (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  type text not null,
  title text not null,
  summary text not null,
  reason_codes jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  knowledge_refs jsonb not null default '[]'::jsonb,
  proposed_action jsonb,
  data_quality text not null,
  status text not null,
  failure_message text,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint ai_suggestions_reason_codes_array
    check (pg_catalog.jsonb_typeof(reason_codes) = 'array'),
  constraint ai_suggestions_evidence_refs_array
    check (pg_catalog.jsonb_typeof(evidence_refs) = 'array'),
  constraint ai_suggestions_knowledge_refs_array
    check (pg_catalog.jsonb_typeof(knowledge_refs) = 'array'),
  constraint ai_suggestions_proposed_action_object
    check (proposed_action is null or pg_catalog.jsonb_typeof(proposed_action) = 'object'),
  constraint ai_suggestions_data_quality_valid
    check (data_quality in ('high', 'medium', 'low', 'insufficient')),
  constraint ai_suggestions_status_valid
    check (status in ('proposed', 'accepted', 'modified', 'rejected', 'dismissed', 'applied', 'applyFailed'))
);
alter table public.ai_suggestions enable row level security;

create table if not exists public.ai_suggestion_feedback (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null default pg_catalog.gen_random_uuid(),
  suggestion_id text not null,
  decision text not null,
  modified_action jsonb,
  reason_code text,
  feedback_type text,
  version integer not null default 1,
  deleted_at timestamptz,
  client_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint ai_suggestion_feedback_suggestion_fk
    foreign key (user_id, suggestion_id)
    references public.ai_suggestions(user_id, id)
    on delete cascade,
  constraint ai_suggestion_feedback_decision_valid
    check (decision in ('accepted', 'modified', 'rejected', 'dismissed')),
  constraint ai_suggestion_feedback_modified_action_object
    check (modified_action is null or pg_catalog.jsonb_typeof(modified_action) = 'object'),
  constraint ai_suggestion_feedback_reason_valid
    check (reason_code is null or reason_code in ('notSuitable', 'inaccurateData', 'dislikeSuggestion', 'other')),
  constraint ai_suggestion_feedback_type_valid
    check (feedback_type is null or feedback_type in ('helpful', 'notForMe', 'inaccurateData', 'disliked', 'dismissed'))
);
alter table public.ai_suggestion_feedback enable row level security;

create unique index if not exists training_templates_client_operation_idx
  on public.training_templates (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists ai_memories_client_operation_idx
  on public.ai_memories (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists ai_suggestions_client_operation_idx
  on public.ai_suggestions (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists ai_suggestion_feedback_client_operation_idx
  on public.ai_suggestion_feedback (user_id, client_operation_id)
  where client_operation_id is not null;
create unique index if not exists ai_memories_stable_source_idx
  on public.ai_memories (user_id, stable_key, source_type)
  where stable_key is not null and deleted_at is null;

create index if not exists training_templates_updated_idx
  on public.training_templates (user_id, updated_at);
create index if not exists ai_memories_updated_idx
  on public.ai_memories (user_id, updated_at);
create index if not exists ai_suggestions_updated_idx
  on public.ai_suggestions (user_id, updated_at);
create index if not exists ai_suggestion_feedback_updated_idx
  on public.ai_suggestion_feedback (user_id, updated_at);

create or replace function public.goat_protect_user_provided_memory()
returns trigger
language plpgsql
set search_path = ''
as $protect_user_memory$
begin
  if old.source_type = 'userProvided'
     and (
       new.source_type is distinct from old.source_type
       or new.stable_key is distinct from old.stable_key
       or new.category is distinct from old.category
     ) then
    raise exception 'USER_PROVIDED_MEMORY_IDENTITY_IMMUTABLE'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$protect_user_memory$;

revoke all on function public.goat_protect_user_provided_memory()
  from public, anon, authenticated;

drop trigger if exists ai_memories_protect_user_provided
  on public.ai_memories;
create trigger ai_memories_protect_user_provided
before update on public.ai_memories
for each row execute function public.goat_protect_user_provided_memory();

do $updated_at_triggers$
declare
  expected_table text;
begin
  foreach expected_table in array array[
    'training_templates',
    'ai_memories',
    'ai_suggestions',
    'ai_suggestion_feedback'
  ] loop
    execute pg_catalog.format(
      'drop trigger if exists %I on public.%I',
      expected_table || '_updated_at',
      expected_table
    );
    execute pg_catalog.format(
      'create trigger %I before update on public.%I for each row execute function public.goat_set_updated_at()',
      expected_table || '_updated_at',
      expected_table
    );
  end loop;
end;
$updated_at_triggers$;

do $rls_policies$
declare
  expected_table text;
begin
  foreach expected_table in array array[
    'training_templates',
    'ai_memories',
    'ai_suggestions',
    'ai_suggestion_feedback'
  ] loop
    execute pg_catalog.format(
      'drop policy if exists goat_select_own on public.%I',
      expected_table
    );
    execute pg_catalog.format(
      'drop policy if exists goat_insert_own on public.%I',
      expected_table
    );
    execute pg_catalog.format(
      'drop policy if exists goat_update_own on public.%I',
      expected_table
    );
    execute pg_catalog.format(
      'drop policy if exists goat_delete_own on public.%I',
      expected_table
    );
    execute pg_catalog.format(
      'create policy goat_select_own on public.%I for select to authenticated using (auth.uid() = user_id)',
      expected_table
    );
    execute pg_catalog.format(
      'create policy goat_insert_own on public.%I for insert to authenticated with check (auth.uid() = user_id)',
      expected_table
    );
    execute pg_catalog.format(
      'create policy goat_update_own on public.%I for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      expected_table
    );
    execute pg_catalog.format(
      'create policy goat_delete_own on public.%I for delete to authenticated using (auth.uid() = user_id)',
      expected_table
    );
    execute pg_catalog.format(
      'revoke all on table public.%I from public, anon',
      expected_table
    );
    execute pg_catalog.format(
      'grant select, insert, update, delete on table public.%I to authenticated',
      expected_table
    );
  end loop;
end;
$rls_policies$;

-- Migrations run as postgres in local and test-project rebuilds. Its default
-- table ACL grants do not include client DML, so make the RLS-backed contract
-- explicit instead of relying on project-specific historical ACLs.
do $user_table_grants$
declare
  expected_table text;
begin
  foreach expected_table in array array[
    'user_profiles',
    'food_dictionary',
    'diet_logs',
    'exercise_logs',
    'daily_tracking',
    'water_intake_records',
    'body_weight_logs',
    'training_sessions',
    'training_templates',
    'sync_tombstones',
    'client_operations',
    'ai_usage_daily',
    'sync_diagnostics',
    'ai_memories',
    'ai_suggestions',
    'ai_suggestion_feedback'
  ] loop
    execute pg_catalog.format(
      'revoke all on table public.%I from public, anon',
      expected_table
    );
    execute pg_catalog.format(
      'grant select, insert, update, delete on table public.%I to authenticated, service_role',
      expected_table
    );
  end loop;

  if pg_catalog.to_regclass('public.chat_history') is not null then
    revoke all on table public.chat_history from public, anon;
    grant select, insert, update, delete
      on table public.chat_history
      to authenticated, service_role;
  end if;

  revoke all on table public.app_feature_flags from public, anon;
  grant select on table public.app_feature_flags
    to authenticated, service_role;
  revoke insert, update, delete on table public.app_feature_flags
    from authenticated;
end;
$user_table_grants$;

create or replace function public.assert_account_deletion_ready()
returns boolean
language plpgsql
security definer
set search_path = ''
as $deletion_ready$
declare
  expected_table text;
  expected_column text;
begin
  foreach expected_table in array array[
    'user_profiles',
    'food_dictionary',
    'diet_logs',
    'exercise_logs',
    'daily_tracking',
    'water_intake_records',
    'body_weight_logs',
    'training_sessions',
    'training_templates',
    'sync_tombstones',
    'client_operations',
    'ai_usage_daily',
    'sync_diagnostics',
    'ai_memories',
    'ai_suggestions',
    'ai_suggestion_feedback'
  ] loop
    expected_column := case
      when expected_table = 'user_profiles' then 'id'
      else 'user_id'
    end;

    if pg_catalog.to_regclass(pg_catalog.format('public.%I', expected_table)) is null then
      raise exception 'ACCOUNT_DELETION_TABLE_MISSING:%', expected_table
        using errcode = 'check_violation';
    end if;

    if not exists (
      select 1
      from pg_catalog.pg_constraint constraint_row
      join pg_catalog.pg_class source_table
        on source_table.oid = constraint_row.conrelid
      join pg_catalog.pg_namespace source_schema
        on source_schema.oid = source_table.relnamespace
      join pg_catalog.pg_attribute source_column
        on source_column.attrelid = source_table.oid
       and source_column.attnum = any(constraint_row.conkey)
      where constraint_row.contype = 'f'
        and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
        and constraint_row.confdeltype = 'c'
        and source_schema.nspname = 'public'
        and source_table.relname = expected_table
        and source_column.attname = expected_column
    ) then
      raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%', expected_table
        using errcode = 'check_violation';
    end if;
  end loop;

  if pg_catalog.to_regclass('public.chat_history') is not null
     and not exists (
       select 1
       from pg_catalog.pg_constraint constraint_row
       join pg_catalog.pg_class source_table
         on source_table.oid = constraint_row.conrelid
       join pg_catalog.pg_namespace source_schema
         on source_schema.oid = source_table.relnamespace
       join pg_catalog.pg_attribute source_column
         on source_column.attrelid = source_table.oid
        and source_column.attnum = any(constraint_row.conkey)
       where constraint_row.contype = 'f'
         and constraint_row.confrelid = pg_catalog.to_regclass('auth.users')
         and constraint_row.confdeltype = 'c'
         and source_schema.nspname = 'public'
         and source_table.relname = 'chat_history'
         and source_column.attname = 'user_id'
     ) then
    raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history'
      using errcode = 'check_violation';
  end if;

  return true;
end;
$deletion_ready$;

revoke all on function public.assert_account_deletion_ready()
  from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready()
  to service_role;

commit;

-- End of draft.
