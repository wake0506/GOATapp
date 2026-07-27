-- GOAT backend/frontend contract alignment.
-- Additive only. This migration does not deploy Edge Functions and does not
-- enable versioned_sync.

begin;

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
