begin;

select no_plan();

select has_table('public', 'training_templates', 'training_templates exists');
select has_table('public', 'ai_memories', 'ai_memories exists');
select has_table('public', 'ai_suggestions', 'ai_suggestions exists');
select has_table('public', 'ai_suggestion_feedback', 'ai_suggestion_feedback exists');

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-0000000000ca',
    'authenticated',
    'authenticated',
    'contract-a@example.test',
    '',
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-0000000000cb',
    'authenticated',
    'authenticated',
    'contract-b@example.test',
    '',
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  )
on conflict (id) do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000ca","role":"authenticated"}',
  true
);

select lives_ok($sql$
  insert into public.training_sessions (
    id, user_id, name, date, exercises, client_operation_id
  )
  values (
    'contract-session-a',
    '00000000-0000-0000-0000-0000000000ca',
    '完整契约训练',
    current_date,
    '[
      {
        "exerciseId":"bench",
        "exerciseName":"卧推",
        "bodyPart":"胸部",
        "orderIndex":0,
        "status":"completed",
        "substitutedFromExerciseId":null,
        "supersetGroupId":"superset-a",
        "progressionTarget":{
          "targetSets":3,
          "targetRepMin":8,
          "targetRepMax":12,
          "weightStepKg":2.5
        },
        "restPrescription":{"mode":"fixed","fixedSeconds":180},
        "unknownOptional":{"preserved":true},
        "sets":[
          {
            "id":"set-a",
            "weight":80,
            "reps":8,
            "type":"正常",
            "restSeconds":90,
            "durationSec":45,
            "setType":"working",
            "rir":2,
            "rpe":8.0,
            "reachedFailure":false,
            "completedAt":"2026-07-25T10:00:00.000Z",
            "replacementPlaceholder":false,
            "recommendedRestSeconds":150,
            "plannedRestSeconds":180,
            "actualRestSeconds":132,
            "restPolicyVersion":2,
            "restSource":"sessionExerciseOverride"
          }
        ]
      }
    ]'::jsonb,
    'contract-session-op-a'
  )
$sql$, 'user A can save a completed training session with all current fields');

select is(
  (
    select exercises
    from public.training_sessions
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'contract-session-a'
  ),
  '[
    {
      "exerciseId":"bench",
      "exerciseName":"卧推",
      "bodyPart":"胸部",
      "orderIndex":0,
      "status":"completed",
      "substitutedFromExerciseId":null,
      "supersetGroupId":"superset-a",
      "progressionTarget":{
        "targetSets":3,
        "targetRepMin":8,
        "targetRepMax":12,
        "weightStepKg":2.5
      },
      "restPrescription":{"mode":"fixed","fixedSeconds":180},
      "unknownOptional":{"preserved":true},
      "sets":[
        {
          "id":"set-a",
          "weight":80,
          "reps":8,
          "type":"正常",
          "restSeconds":90,
          "durationSec":45,
          "setType":"working",
          "rir":2,
          "rpe":8.0,
          "reachedFailure":false,
          "completedAt":"2026-07-25T10:00:00.000Z",
          "replacementPlaceholder":false,
          "recommendedRestSeconds":150,
          "plannedRestSeconds":180,
          "actualRestSeconds":132,
          "restPolicyVersion":2,
          "restSource":"sessionExerciseOverride"
        }
      ]
    }
  ]'::jsonb,
  'training JSON round-trips without field loss or array reordering'
);

select lives_ok($sql$
  insert into public.training_sessions (
    id, user_id, name, date, exercises
  )
  values (
    'contract-session-legacy-a',
    '00000000-0000-0000-0000-0000000000ca',
    '旧训练',
    current_date - 1,
    '[{"exerciseName":"旧动作","bodyPart":"全身","sets":[{"weight":0,"reps":0}]}]'::jsonb
  )
$sql$, 'legacy training JSON remains valid');

select throws_ok(
  $sql$
    insert into public.training_sessions (
      id, user_id, name, date, exercises
    )
    values (
      'contract-session-invalid-a',
      '00000000-0000-0000-0000-0000000000ca',
      '非法训练',
      current_date,
      '{}'::jsonb
    )
  $sql$,
  '23514',
  null,
  'non-array training exercises are rejected'
);

select lives_ok($sql$
  insert into public.training_templates (
    user_id,
    id,
    name,
    exercise_ids,
    progression_targets,
    rest_prescriptions,
    superset_groups,
    client_operation_id
  )
  values (
    '00000000-0000-0000-0000-0000000000ca',
    'template-a',
    '推拉模板',
    '["bench","row"]'::jsonb,
    '{"bench":{"targetSets":3,"targetRepMin":8,"targetRepMax":12,"weightStepKg":2.5}}'::jsonb,
    '{"bench":{"mode":"fixed","fixedSeconds":180},"row":{"mode":"recommended"}}'::jsonb,
    '{"bench":"superset-a","row":"superset-a"}'::jsonb,
    'template-operation-a'
  )
$sql$, 'user A can create a complete training template');

select is(
  (
    select exercise_ids
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'
  ),
  '["bench","row"]'::jsonb,
  'template exercise order round-trips'
);

select is(
  (
    select progression_targets -> 'bench'
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'
  ),
  '{"targetSets":3,"targetRepMin":8,"targetRepMax":12,"weightStepKg":2.5}'::jsonb,
  'ProgressionTarget round-trips without default synthesis'
);

select is(
  (
    select rest_prescriptions -> 'bench'
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'
  ),
  '{"mode":"fixed","fixedSeconds":180}'::jsonb,
  'RestPrescription V2 contract round-trips'
);

select lives_ok(
  $$update public.training_templates
    set name = '推拉模板已更新'
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'$$,
  'user A can update an owned template'
);

select is(
  (
    select name
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'
  ),
  '推拉模板已更新',
  'user A reads the owned template update'
);

select lives_ok($sql$
  insert into public.training_templates (
    user_id, id, name, exercise_ids
  )
  values (
    '00000000-0000-0000-0000-0000000000ca',
    'template-delete-a',
    '待删除模板',
    '[]'::jsonb
  )
$sql$, 'user A can create a disposable owned template');

select lives_ok($sql$
  delete from public.training_templates
  where user_id = '00000000-0000-0000-0000-0000000000ca'
    and id = 'template-delete-a'
$sql$, 'user A can delete an owned template');

select is(
  (
    select count(*)::integer
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-delete-a'
  ),
  0,
  'user A owned template deletion persists'
);

select lives_ok($sql$
  insert into public.ai_memories (
    user_id,
    id,
    stable_key,
    category,
    value,
    structured_value,
    source_type,
    status,
    source_refs,
    confidence_level,
    user_confirmed,
    client_operation_id
  )
  values (
    '00000000-0000-0000-0000-0000000000ca',
    'user_profile_trainingGoal',
    'user_profile_trainingGoal',
    'trainingGoal',
    '增肌',
    '{"goal":"hypertrophy"}'::jsonb,
    'userProvided',
    'active',
    '[{"type":"user_input","id":"profile_account_center","label":"用户主动填写"}]'::jsonb,
    'high',
    true,
    'memory-operation-a'
  )
$sql$, 'user-provided profile memory can be persisted');

select throws_ok(
  $sql$
    update public.ai_memories
    set source_type = 'aiInferred'
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'user_profile_trainingGoal'
  $sql$,
  '23514',
  null,
  'AI cannot reclassify USER_PROVIDED memory identity'
);

select throws_ok(
  $sql$
    insert into public.ai_memories (
      user_id, id, category, value, source_type, status, user_confirmed
    )
    values (
      '00000000-0000-0000-0000-0000000000ca',
      'unconfirmed-active-inference',
      'trainingHabit',
      '推断',
      'aiInferred',
      'active',
      false
    )
  $sql$,
  '23514',
  null,
  'unconfirmed AI inference cannot become active'
);

select lives_ok($sql$
  insert into public.ai_suggestions (
    user_id,
    id,
    type,
    title,
    summary,
    reason_codes,
    evidence_refs,
    knowledge_refs,
    proposed_action,
    data_quality,
    status,
    client_operation_id
  )
  values (
    '00000000-0000-0000-0000-0000000000ca',
    'suggestion-a',
    'rest',
    '延长休息',
    '根据结构化推荐解释',
    '["heavy_compound"]'::jsonb,
    '["session:contract-session-a"]'::jsonb,
    '["kb:rest-v2"]'::jsonb,
    '{"type":"updateRestPrescription","payload":{"exerciseId":"bench","fixedSeconds":180}}'::jsonb,
    'high',
    'proposed',
    'suggestion-operation-a'
  )
$sql$, 'AI suggestion can be persisted');

select lives_ok($sql$
  insert into public.ai_suggestion_feedback (
    user_id,
    suggestion_id,
    decision,
    modified_action,
    feedback_type,
    client_operation_id
  )
  values (
    '00000000-0000-0000-0000-0000000000ca',
    'suggestion-a',
    'modified',
    '{"type":"updateRestPrescription","payload":{"exerciseId":"bench","fixedSeconds":150}}'::jsonb,
    'helpful',
    'feedback-operation-a'
  )
$sql$, 'suggestion feedback can be persisted');

select throws_ok(
  $sql$
    insert into public.training_templates (
      user_id, id, name, exercise_ids, client_operation_id
    )
    values (
      '00000000-0000-0000-0000-0000000000ca',
      'template-retry-a',
      '重复请求',
      '["bench"]'::jsonb,
      'template-operation-a'
    )
  $sql$,
  '23505',
  null,
  'template network retry reuses the existing client-operation idempotency contract'
);

select throws_ok(
  $sql$
    insert into public.ai_suggestion_feedback (
      user_id, suggestion_id, decision, client_operation_id
    )
    values (
      '00000000-0000-0000-0000-0000000000ca',
      'suggestion-a',
      'accepted',
      'feedback-operation-a'
    )
  $sql$,
  '23505',
  null,
  'feedback network retry reuses the existing client-operation idempotency contract'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000cb","role":"authenticated"}',
  true
);

select is(
  (
    select count(*)::integer
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
  ),
  0,
  'user B cannot read user A templates'
);

select is(
  (
    select count(*)::integer
    from public.ai_memories
    where user_id = '00000000-0000-0000-0000-0000000000ca'
  ),
  0,
  'user B cannot read user A memories'
);

select is(
  (
    select count(*)::integer
    from public.ai_suggestions
    where user_id = '00000000-0000-0000-0000-0000000000ca'
  ),
  0,
  'user B cannot read user A suggestions'
);

select is(
  (
    select count(*)::integer
    from public.ai_suggestion_feedback
    where user_id = '00000000-0000-0000-0000-0000000000ca'
  ),
  0,
  'user B cannot read user A feedback'
);

select lives_ok(
  $$update public.ai_suggestions
    set title = '越权修改'
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'suggestion-a'$$,
  'user B update is safely filtered by RLS'
);

select lives_ok(
  $$delete from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'$$,
  'user B delete is safely filtered by RLS'
);

select lives_ok(
  $$delete from public.ai_suggestion_feedback
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and suggestion_id = 'suggestion-a'$$,
  'user B feedback delete is safely filtered by RLS'
);

select throws_ok(
  $sql$
    insert into public.ai_memories (
      user_id, id, category, value, source_type, status
    )
    values (
      '00000000-0000-0000-0000-0000000000ca',
      'forged-memory',
      'trainingGoal',
      '伪造',
      'userProvided',
      'active'
    )
  $sql$,
  '42501',
  null,
  'user B cannot forge user ownership'
);

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(
  (select count(*)::integer from public.training_templates),
  0,
  'anonymous user cannot read templates'
);
select is(
  (select count(*)::integer from public.ai_suggestions),
  0,
  'anonymous user cannot read AI suggestions'
);

set local role service_role;
select is(
  (
    select count(*)::integer
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
  ),
  1,
  'service role can read user-owned rows for server operations'
);

select is(
  (
    select title
    from public.ai_suggestions
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'suggestion-a'
  ),
  '延长休息',
  'cross-user update did not change user A suggestion'
);

select is(
  (
    select count(*)::integer
    from public.ai_suggestion_feedback
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and suggestion_id = 'suggestion-a'
  ),
  1,
  'cross-user delete did not remove user A feedback'
);

reset role;
select is(
  (
    select count(*)::integer
    from public.training_templates
    where user_id = '00000000-0000-0000-0000-0000000000ca'
      and id = 'template-a'
  ),
  1,
  'cross-user delete did not affect user A'
);

select lives_ok(
  $$delete from auth.users
    where id = '00000000-0000-0000-0000-0000000000ca'$$,
  'deleting the test auth user cascades through all new entities'
);

select is(
  (
    select
      (select count(*) from public.training_templates where user_id = '00000000-0000-0000-0000-0000000000ca')
      + (select count(*) from public.ai_memories where user_id = '00000000-0000-0000-0000-0000000000ca')
      + (select count(*) from public.ai_suggestions where user_id = '00000000-0000-0000-0000-0000000000ca')
      + (select count(*) from public.ai_suggestion_feedback where user_id = '00000000-0000-0000-0000-0000000000ca')
  )::integer,
  0,
  'account deletion leaves no new-entity orphan rows'
);

select is(
  (select count(*)::integer from auth.users where id = '00000000-0000-0000-0000-0000000000cb'),
  1,
  'deleting user A does not affect user B'
);

select * from finish();
rollback;
