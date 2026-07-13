/*
Purpose: Install fixed-limit AI quota and server-owned nutrition AI idempotency RPCs.
Read-only: No.
Data modification: Creates/replaces named SECURITY DEFINER functions only.
Expected time: Under 15 seconds.
Success: Only authenticated callers can execute these RPCs; auth.uid(), current_date
and the fixed limit are server-derived. Existing account-deletion functions are untouched.
Failure/retry: Safe to rerun after reviewing function signature conflicts.
*/

begin;

-- Retire execute access to the old client-parameterized overload without dropping
-- it. Keeping the old object avoids destructive schema changes; callers cannot use it.
do $$
begin
  if to_regprocedure('public.consume_ai_quota(uuid,date,integer)') is not null then
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from public';
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from anon';
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from authenticated';
  end if;
end $$;

create or replace function public.consume_ai_quota()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.ai_usage_daily (user_id, date, request_count)
  values (auth.uid(), current_date, 1)
  on conflict (user_id, date) do update
    set request_count = public.ai_usage_daily.request_count + 1
    where public.ai_usage_daily.request_count < 50;

  return found;
end;
$$;

revoke all on function public.consume_ai_quota() from public;
grant execute on function public.consume_ai_quota() to authenticated;

create or replace function public.nutrition_ai_get_cached_response(
  p_client_request_id text
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select response
  from public.client_operations
  where user_id = auth.uid()
    and entity_type = 'nutrition-ai'
    and operation_id = p_client_request_id
    and response is not null
  limit 1;
$$;

create or replace function public.nutrition_ai_claim_operation(
  p_client_request_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_client_request_id is null or length(trim(p_client_request_id)) = 0
     or length(p_client_request_id) > 128 then
    raise exception 'invalid_request_id';
  end if;

  insert into public.client_operations as existing (
    operation_id, user_id, entity_type, entity_id, action, payload, response
  ) values (
    p_client_request_id, auth.uid(), 'nutrition-ai', p_client_request_id,
    'upsert', '{}'::jsonb, null
  ) on conflict (user_id, operation_id) do update
    set claimed_at = now(),
        updated_at = now()
    where existing.entity_type = 'nutrition-ai'
      and existing.response is null
      and (existing.claimed_at is null
           or existing.claimed_at < now() - interval '2 minutes');

  return found;
end;
$$;

create or replace function public.nutrition_ai_save_response(
  p_client_request_id text,
  p_response jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_response is null or jsonb_typeof(p_response) <> 'object' then
    raise exception 'invalid_response';
  end if;

  update public.client_operations
  set response = p_response,
      claimed_at = now(),
      updated_at = now()
  where user_id = auth.uid()
    and entity_type = 'nutrition-ai'
    and operation_id = p_client_request_id
    and response is null;

  return found;
end;
$$;

create or replace function public.nutrition_ai_release_operation(
  p_client_request_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.client_operations
  where user_id = auth.uid()
    and entity_type = 'nutrition-ai'
    and operation_id = p_client_request_id
    and response is null;

  return found;
end;
$$;

revoke all on function public.nutrition_ai_get_cached_response(text) from public;
revoke all on function public.nutrition_ai_claim_operation(text) from public;
revoke all on function public.nutrition_ai_save_response(text, jsonb) from public;
revoke all on function public.nutrition_ai_release_operation(text) from public;

grant execute on function public.nutrition_ai_get_cached_response(text) to authenticated;
grant execute on function public.nutrition_ai_claim_operation(text) to authenticated;
grant execute on function public.nutrition_ai_save_response(text, jsonb) to authenticated;
grant execute on function public.nutrition_ai_release_operation(text) to authenticated;

commit;
