/*
Purpose: Human-controlled, rollback-safe smoke test template.
Read-only: No, but all active test statements are intentionally commented.
Data modification: None unless an operator replaces the UUID and explicitly uncomments statements.
Expected time: Under 10 seconds when enabled.
Success: The enabled statements pass and the final ROLLBACK is reached.
Failure/retry: Rerun only after reviewing the error; never run against production without approval.

IMPORTANT: Replace TEST_USER_UUID with a non-production test user UUID first.
Do not run this file unchanged and do not use a real user's data.
*/

begin;

-- Replace the placeholder before enabling any statement below.
-- \set TEST_USER_UUID '00000000-0000-0000-0000-000000000000'
-- set local role authenticated;
-- select set_config('request.jwt.claims',
--   '{"sub":"TEST_USER_UUID","role":"authenticated"}', true);

-- RLS own-row insert/update/delete example:
-- insert into public.water_intake_records
--   (id, user_id, date, recorded_at, amount_ml)
-- values ('smoke-water-1', 'TEST_USER_UUID', current_date, now(), 250);
-- update public.water_intake_records set amount_ml = 300
--   where id = 'smoke-water-1' and user_id = 'TEST_USER_UUID';
-- delete from public.water_intake_records
--   where id = 'smoke-water-1' and user_id = 'TEST_USER_UUID';

-- Constraint example; this should fail when deliberately enabled:
-- insert into public.water_intake_records
--   (id, user_id, date, recorded_at, amount_ml)
-- values ('smoke-water-invalid', 'TEST_USER_UUID', current_date, now(), -1);

-- v4 AI lease tests. These require service_role and must remain inside this
-- transaction. Do not run them with an application JWT.
-- set local role service_role;
-- select public.nutrition_ai_claim_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-1'
-- ) as first_claim; -- expect CLAIMED with a non-null claimToken.
-- select public.nutrition_ai_claim_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-1'
-- ) as second_claim; -- expect IN_PROGRESS with a null claimToken.
-- select public.nutrition_ai_save_response(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-1',
--   'CLAIM_TOKEN_FROM_FIRST_RESULT'::uuid,
--   '{"items":[],"requestId":"smoke-response","provider":"test"}'::jsonb
-- ); -- replace the token; expect true.
-- select public.nutrition_ai_save_response(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-1',
--   'OLD_OR_WRONG_TOKEN'::uuid,
--   '{"items":[],"requestId":"forged","provider":"test"}'::jsonb
-- ); -- expect false; a stale worker cannot overwrite the response.
-- select public.nutrition_ai_release_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-1',
--   'OLD_OR_WRONG_TOKEN'::uuid
-- ); -- expect false.

-- Expired-lease test: first create a pending claim with a distinct request,
-- then age only that test row and claim again; the second result must be
-- CLAIMED with a different token.
-- select public.nutrition_ai_claim_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-expired'
-- );
-- update public.client_operations
-- set claimed_at = now() - interval '3 minutes'
-- where user_id = 'TEST_USER_UUID'::uuid
--   and operation_id = 'smoke-claim-expired'
--   and entity_type = 'nutrition-ai';
-- select public.nutrition_ai_claim_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-claim-expired'
-- ); -- expect CLAIMED with a new token.

-- Client privilege checks: both calls must fail with permission denied.
-- set local role authenticated;
-- select public.nutrition_ai_claim_operation(
--   'TEST_USER_UUID'::uuid, 'smoke-auth-denied'
-- );
-- select public.consume_ai_quota_for_user('TEST_USER_UUID'::uuid);

-- Idempotency example: the second insert should fail on the unique operation index.
-- insert into public.food_dictionary
--   (id, user_id, name, client_operation_id)
-- values ('smoke-food-1', 'TEST_USER_UUID', 'smoke', 'smoke-operation-1');
-- insert into public.food_dictionary
--   (id, user_id, name, client_operation_id)
-- values ('smoke-food-2', 'TEST_USER_UUID', 'smoke-duplicate', 'smoke-operation-1');

rollback;
