\set ON_ERROR_STOP on
select object_name, pg_catalog.to_regclass(pg_catalog.format('public.%s', object_name)) is not null as remains
from (values ('training_templates'),('ai_memories'),('ai_suggestions'),('ai_suggestion_feedback')) as objects(object_name);
select pg_catalog.to_regprocedure('public.goat_protect_user_provided_memory()') is not null as protected_memory_function_remains;
select count(*)::integer as residual_contract_policy_count
from pg_catalog.pg_policies
where schemaname='public' and tablename in ('training_templates','ai_memories','ai_suggestions','ai_suggestion_feedback');
select count(*)::integer as residual_contract_trigger_count
from pg_catalog.pg_trigger t
join pg_catalog.pg_class c on c.oid=t.tgrelid
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and not t.tgisinternal
  and t.tgname in ('training_templates_updated_at','ai_memories_updated_at','ai_suggestions_updated_at','ai_suggestion_feedback_updated_at');
select pg_catalog.to_regprocedure('public.assert_account_deletion_ready()') is not null as deletion_readiness_remains;
