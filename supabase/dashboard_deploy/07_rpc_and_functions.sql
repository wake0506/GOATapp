/*
Purpose: Install service-role-only AI quota and idempotency RPCs.
Read-only: No.
Data modification: Creates/replaces only the named service RPCs and revokes old client RPC grants.
Expected time: Under 15 seconds.
Success: PUBLIC, anon and authenticated cannot execute AI RPCs; only service_role can.
Failure/retry: Safe to rerun after reviewing function signature conflicts.
*/

begin;

-- Retire client-facing quota overloads without dropping old database objects.
do $$
begin
  if to_regprocedure('public.consume_ai_quota()') is not null then
    execute 'revoke all on function public.consume_ai_quota() from public';
    execute 'revoke all on function public.consume_ai_quota() from anon';
    execute 'revoke all on function public.consume_ai_quota() from authenticated';
  end if;
  if to_regprocedure('public.consume_ai_quota(uuid,date,integer)') is not null then
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from public';
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from anon';
    execute 'revoke all on function public.consume_ai_quota(uuid, date, integer) from authenticated';
  end if;
end $$;

create or replace function public.consume_ai_quota_for_user(
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    raise exception 'invalid_user_id';
  end if;

  insert into public.ai_usage_daily (user_id, date, request_count)
  values (p_user_id, current_date, 1)
  on conflict (user_id, date) do update
    set request_count = public.ai_usage_daily.request_count + 1
    where public.ai_usage_daily.request_count < 50;

  return found;
end;
$$;

create or replace function public.nutrition_ai_get_cached_response(
  p_user_id uuid,
  p_request_id text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select c.response
  from public.client_operations as c
  where c.user_id = p_user_id
    and c.entity_type = 'nutrition-ai'
    and c.operation_id = p_request_id
    and c.response is not null
  limit 1;
$$;

create or replace function public.nutrition_ai_claim_operation(
  p_user_id uuid,
  p_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_response jsonb;
  existing_claimed_at timestamptz;
  existing_entity_type text;
  new_claim_token uuid;
  inserted boolean;
begin
  if p_user_id is null or p_request_id is null
     or length(trim(p_request_id)) = 0 or length(p_request_id) > 128 then
    raise exception 'invalid_claim_arguments';
  end if;

  new_claim_token := public.gen_random_uuid();
  insert into public.client_operations (
    operation_id, user_id, entity_type, entity_id, action, payload,
    response, claimed_at, claim_token
  ) values (
    p_request_id, p_user_id, 'nutrition-ai', p_request_id, 'upsert',
    '{}'::jsonb, null, now(), new_claim_token
  ) on conflict (user_id, operation_id) do nothing;
  inserted := found;

  if inserted then
    return jsonb_build_object(
      'status', 'CLAIMED',
      'claimToken', new_claim_token,
      'response', null::jsonb
    );
  end if;

  select c.response, c.claimed_at, c.entity_type
    into existing_response, existing_claimed_at, existing_entity_type
  from public.client_operations as c
  where c.user_id = p_user_id
    and c.operation_id = p_request_id
  for update;

  if existing_entity_type <> 'nutrition-ai' then
    raise exception 'operation_id_conflict';
  end if;

  if existing_response is not null then
    return jsonb_build_object(
      'status', 'CACHED',
      'claimToken', null::uuid,
      'response', existing_response
    );
  end if;

  if existing_claimed_at is not null
     and existing_claimed_at >= now() - interval '2 minutes' then
    return jsonb_build_object(
      'status', 'IN_PROGRESS',
      'claimToken', null::uuid,
      'response', null::jsonb
    );
  end if;

  new_claim_token := public.gen_random_uuid();
  update public.client_operations as c
  set claimed_at = now(),
      claim_token = new_claim_token,
      updated_at = now()
  where c.user_id = p_user_id
    and c.operation_id = p_request_id
    and c.entity_type = 'nutrition-ai'
    and c.response is null;

  return jsonb_build_object(
    'status', 'CLAIMED',
    'claimToken', new_claim_token,
    'response', null::jsonb
  );
end;
$$;

create or replace function public.nutrition_ai_save_response(
  p_user_id uuid,
  p_request_id text,
  p_claim_token uuid,
  p_response jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_request_id is null or p_claim_token is null
     or p_response is null or jsonb_typeof(p_response) <> 'object' then
    raise exception 'invalid_save_arguments';
  end if;

  update public.client_operations as c
  set response = p_response,
      claimed_at = now(),
      updated_at = now()
  where c.user_id = p_user_id
    and c.operation_id = p_request_id
    and c.entity_type = 'nutrition-ai'
    and c.claim_token = p_claim_token
    and c.response is null;

  return found;
end;
$$;

create or replace function public.nutrition_ai_release_operation(
  p_user_id uuid,
  p_request_id text,
  p_claim_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_request_id is null or p_claim_token is null then
    return false;
  end if;

  delete from public.client_operations as c
  where c.user_id = p_user_id
    and c.operation_id = p_request_id
    and c.entity_type = 'nutrition-ai'
    and c.claim_token = p_claim_token
    and c.response is null;

  return found;
end;
$$;

-- AI RPCs are service-role-only. No client role receives execute permission.
revoke all on function public.consume_ai_quota_for_user(uuid) from public;
revoke all on function public.consume_ai_quota_for_user(uuid) from anon;
revoke all on function public.consume_ai_quota_for_user(uuid) from authenticated;
grant execute on function public.consume_ai_quota_for_user(uuid) to service_role;

revoke all on function public.nutrition_ai_get_cached_response(uuid, text) from public;
revoke all on function public.nutrition_ai_get_cached_response(uuid, text) from anon;
revoke all on function public.nutrition_ai_get_cached_response(uuid, text) from authenticated;
grant execute on function public.nutrition_ai_get_cached_response(uuid, text) to service_role;

revoke all on function public.nutrition_ai_claim_operation(uuid, text) from public;
revoke all on function public.nutrition_ai_claim_operation(uuid, text) from anon;
revoke all on function public.nutrition_ai_claim_operation(uuid, text) from authenticated;
grant execute on function public.nutrition_ai_claim_operation(uuid, text) to service_role;

revoke all on function public.nutrition_ai_save_response(uuid, text, uuid, jsonb) from public;
revoke all on function public.nutrition_ai_save_response(uuid, text, uuid, jsonb) from anon;
revoke all on function public.nutrition_ai_save_response(uuid, text, uuid, jsonb) from authenticated;
grant execute on function public.nutrition_ai_save_response(uuid, text, uuid, jsonb) to service_role;

revoke all on function public.nutrition_ai_release_operation(uuid, text, uuid) from public;
revoke all on function public.nutrition_ai_release_operation(uuid, text, uuid) from anon;
revoke all on function public.nutrition_ai_release_operation(uuid, text, uuid) from authenticated;
grant execute on function public.nutrition_ai_release_operation(uuid, text, uuid) to service_role;

commit;
