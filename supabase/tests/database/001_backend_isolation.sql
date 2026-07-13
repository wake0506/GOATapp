begin;

select plan(10);

-- These deterministic users exist only inside the local test transaction.
insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated',
   'goat-a@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated',
   'goat-b@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}',
  true
);

select lives_ok($sql$
  insert into public.diet_logs (
    id, user_id, food_name, p, c, f, kcal, meal_type, date, amount, unit
  ) values (
    'rls-diet-a', '00000000-0000-0000-0000-00000000000a',
    '本地测试食物', 10, 20, 3, 150, '早餐', current_date, 100, 'g'
  )
$sql$, 'user A can insert own diet data');

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}',
  true
);
select is(
  (select count(*) from public.diet_logs where id = 'rls-diet-a')::integer,
  0,
  'user B cannot read user A data'
);
select lives_ok(
  $$update public.diet_logs set food_name = '越权修改' where id = 'rls-diet-a'$$,
  'user B cannot update user A data'
);
select lives_ok(
  $$delete from public.diet_logs where id = 'rls-diet-a'$$,
  'user B cannot delete user A data'
);
select throws_ok(
  $sql$
    insert into public.diet_logs (
      id, user_id, food_name, meal_type, date
    ) values (
      'rls-forged-user', '00000000-0000-0000-0000-00000000000a',
      '伪造', '早餐', current_date
    )
  $sql$,
  '42501',
  null,
  'user B cannot forge user_id on insert'
);

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(
  (select count(*) from public.diet_logs)::integer,
  0,
  'anonymous request cannot access personal data'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}',
  true
);
select throws_ok(
  $$insert into public.water_intake_records (id, user_id, date, recorded_at, amount_ml)
    values ('bad-water', '00000000-0000-0000-0000-00000000000a', current_date, now(), -1)$$,
  '23514', null, 'negative water is rejected'
);
select throws_ok(
  $$insert into public.body_weight_logs (id, user_id, date, weight_kg)
    values ('bad-weight', '00000000-0000-0000-0000-00000000000a', current_date, 301)$$,
  '23514', null, 'out of range weight is rejected'
);
select lives_ok($sql$
  insert into public.food_dictionary (
    id, user_id, name, protein, carbs, fat, calories, client_operation_id
  ) values (
    'idempotent-food', '00000000-0000-0000-0000-00000000000a',
    '幂等食物', 1, 2, 3, 30, 'operation-1'
  )
$sql$, 'first client operation is accepted');
select throws_ok(
  $$insert into public.food_dictionary (
    id, user_id, name, client_operation_id
  ) values (
    'idempotent-food-2', '00000000-0000-0000-0000-00000000000a',
    '重复提交', 'operation-1'
  )$$,
  '23505', null, 'duplicate client operation is rejected'
);
select * from finish();
rollback;
