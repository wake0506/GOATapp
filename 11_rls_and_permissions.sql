-- Atomic RLS and privilege package. Run only after 10_schema.sql commits.
begin;

alter table public.sync_diagnostics enable row level security;
alter table public.app_feature_flags enable row level security;

do $$
declare
  policy_name pg_catalog.name;
begin
  for policy_name in
    select policy_row.polname
    from pg_catalog.pg_policy policy_row
    join pg_catalog.pg_class relation_row on relation_row.oid = policy_row.polrelid
    join pg_catalog.pg_namespace schema_row on schema_row.oid = relation_row.relnamespace
    where schema_row.nspname = 'public' and relation_row.relname = 'sync_diagnostics'
  loop
    execute pg_catalog.format('drop policy if exists %I on public.sync_diagnostics', policy_name);
  end loop;
  for policy_name in
    select policy_row.polname
    from pg_catalog.pg_policy policy_row
    join pg_catalog.pg_class relation_row on relation_row.oid = policy_row.polrelid
    join pg_catalog.pg_namespace schema_row on schema_row.oid = relation_row.relnamespace
    where schema_row.nspname = 'public' and relation_row.relname = 'app_feature_flags'
  loop
    execute pg_catalog.format('drop policy if exists %I on public.app_feature_flags', policy_name);
  end loop;
end;
$$;

create policy goat_sync_diagnostics_select_own on public.sync_diagnostics
  for select to authenticated using (auth.uid() = user_id);
create policy goat_sync_diagnostics_insert_own on public.sync_diagnostics
  for insert to authenticated with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_update_own on public.sync_diagnostics
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy goat_sync_diagnostics_delete_own on public.sync_diagnostics
  for delete to authenticated using (auth.uid() = user_id);

create policy goat_feature_flags_authenticated_read on public.app_feature_flags
  for select to authenticated using (auth.uid() is not null);

revoke all on table public.sync_diagnostics, public.app_feature_flags from public, anon, authenticated;
grant select, insert, update, delete on table public.sync_diagnostics to authenticated;
grant select on table public.app_feature_flags to authenticated;
revoke insert, update, delete on table public.app_feature_flags from authenticated;

commit;
