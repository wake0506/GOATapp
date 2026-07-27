\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

select 'table_count=' || count(*)
from pg_catalog.pg_class class_row
join pg_catalog.pg_namespace namespace_row
  on namespace_row.oid = class_row.relnamespace
where namespace_row.nspname = 'public'
  and class_row.relkind in ('r', 'p');

select 'policy_count=' || count(*)
from pg_catalog.pg_policies
where schemaname = 'public';

select 'function_count=' || count(*)
from pg_catalog.pg_proc procedure_row
join pg_catalog.pg_namespace namespace_row
  on namespace_row.oid = procedure_row.pronamespace
where namespace_row.nspname = 'public';

select 'trigger_count=' || count(*)
from pg_catalog.pg_trigger trigger_row
join pg_catalog.pg_class class_row
  on class_row.oid = trigger_row.tgrelid
join pg_catalog.pg_namespace namespace_row
  on namespace_row.oid = class_row.relnamespace
where namespace_row.nspname = 'public'
  and not trigger_row.tgisinternal;

select 'flag_count=' || count(*)
from public.app_feature_flags;

select 'versioned_sync=' || enabled
from public.app_feature_flags
where key = 'versioned_sync';

select 'training_templates_count=' || count(*)
from public.training_templates;

select 'ai_memories_count=' || count(*)
from public.ai_memories;

select 'ai_suggestions_count=' || count(*)
from public.ai_suggestions;

select 'ai_suggestion_feedback_count=' || count(*)
from public.ai_suggestion_feedback;

select 'schema_checksum=' || pg_catalog.md5(
  pg_catalog.string_agg(definition, E'\n' order by definition)
)
from (
  select pg_catalog.format(
    'table:%I.%I:rls=%s:acl=%s',
    namespace_row.nspname,
    class_row.relname,
    class_row.relrowsecurity,
    coalesce(class_row.relacl::text, '')
  ) as definition
  from pg_catalog.pg_class class_row
  join pg_catalog.pg_namespace namespace_row
    on namespace_row.oid = class_row.relnamespace
  where namespace_row.nspname = 'public'
    and class_row.relkind in ('r', 'p')
  union all
  select pg_catalog.format(
    'policy:%I.%I:%I:%s:%s:%s:%s',
    schemaname,
    tablename,
    policyname,
    cmd,
    roles::text,
    coalesce(qual, ''),
    coalesce(with_check, '')
  )
  from pg_catalog.pg_policies
  where schemaname = 'public'
  union all
  select pg_catalog.format(
    'function:%I.%I(%s):%s:%s:%s',
    namespace_row.nspname,
    procedure_row.proname,
    pg_catalog.pg_get_function_identity_arguments(procedure_row.oid),
    pg_catalog.pg_get_function_result(procedure_row.oid),
    procedure_row.prosecdef,
    coalesce(procedure_row.proconfig::text, '')
  )
  from pg_catalog.pg_proc procedure_row
  join pg_catalog.pg_namespace namespace_row
    on namespace_row.oid = procedure_row.pronamespace
  where namespace_row.nspname = 'public'
  union all
  select pg_catalog.format(
    'trigger:%I.%I:%I:%s',
    namespace_row.nspname,
    class_row.relname,
    trigger_row.tgname,
    pg_catalog.pg_get_triggerdef(trigger_row.oid, true)
  )
  from pg_catalog.pg_trigger trigger_row
  join pg_catalog.pg_class class_row
    on class_row.oid = trigger_row.tgrelid
  join pg_catalog.pg_namespace namespace_row
    on namespace_row.oid = class_row.relnamespace
  where namespace_row.nspname = 'public'
    and not trigger_row.tgisinternal
) definitions;
