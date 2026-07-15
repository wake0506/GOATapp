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
