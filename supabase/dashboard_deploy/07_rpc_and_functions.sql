/*
Purpose: Install the authenticated, user-scoped RPCs used by quota control and account deletion.
Read-only: No.
Data modification: Creates/replaces only named functions and grants execute to authenticated.
Expected time: Under 10 seconds.
Success: RPCs exist with auth.uid checks and no public execute permission.
Failure/retry: Safe to rerun after reviewing function signature conflicts.
*/

begin;

create or replace function public.consume_ai_quota(
  p_user_id uuid,
  p_date date,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not_authorized';
  end if;

  insert into public.ai_usage_daily (user_id, date, request_count)
  values (p_user_id, p_date, 1)
  on conflict (user_id, date) do update
  set request_count = public.ai_usage_daily.request_count + 1
  where public.ai_usage_daily.request_count < p_limit;

  return found;
end;
$$;

revoke all on function public.consume_ai_quota(uuid, date, integer) from public;
grant execute on function public.consume_ai_quota(uuid, date, integer) to authenticated;

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;

commit;
