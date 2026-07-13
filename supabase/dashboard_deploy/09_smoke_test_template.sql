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

-- Idempotency example: the second insert should fail on the unique operation index.
-- insert into public.food_dictionary
--   (id, user_id, name, client_operation_id)
-- values ('smoke-food-1', 'TEST_USER_UUID', 'smoke', 'smoke-operation-1');
-- insert into public.food_dictionary
--   (id, user_id, name, client_operation_id)
-- values ('smoke-food-2', 'TEST_USER_UUID', 'smoke-duplicate', 'smoke-operation-1');

rollback;
