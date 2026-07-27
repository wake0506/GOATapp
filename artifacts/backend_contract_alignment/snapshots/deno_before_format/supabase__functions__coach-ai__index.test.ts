import {
  createCoachAiHandler,
  parseCoachRequest,
  parseDefaultKey,
  validateCoachResponse,
} from './index.ts';

function assert(condition: unknown, message = 'assertion failed'): asserts condition {
  if (!condition) throw new Error(message);
}

function assertThrows(fn: () => unknown, code: string) {
  try {
    fn();
  } catch (error) {
    assert(error instanceof Error && error.message === code, `expected ${code}`);
    return;
  }
  throw new Error(`expected ${code}`);
}

Deno.test('coach request accepts every supported task contract', () => {
  for (const taskType of [
    'nutrition_explanation',
    'progression_explanation',
    'rest_explanation',
    'coverage_explanation',
    'weekly_review',
    'memory_inference',
  ]) {
    const parsed = parseCoachRequest({
      taskType,
      structuredContext: { deterministicFacts: { value: 1 } },
      retrievedKnowledge: [],
      activeProfile: {},
      activeMemories: [],
      requestId: `request-${taskType}`,
    });
    assert(parsed.taskType === taskType);
  }
});

Deno.test('unknown task and missing request id are rejected', () => {
  assertThrows(() => parseCoachRequest({
    taskType: 'exercise_recalculation',
    structuredContext: {},
    requestId: 'request-1',
  }), 'INVALID_TASK_TYPE');
  assertThrows(() => parseCoachRequest({
    taskType: 'weekly_review',
    structuredContext: {},
    requestId: '',
  }), 'INVALID_REQUEST_ID');
});

Deno.test('context arrays are bounded', () => {
  assertThrows(() => parseCoachRequest({
    taskType: 'memory_inference',
    structuredContext: {},
    activeMemories: Array.from({ length: 51 }, () => ({})),
    requestId: 'request-1',
  }), 'INVALID_BODY');
});

Deno.test('provider response contract is strict', () => {
  const parsed = validateCoachResponse({
    answer: '解释',
    summary: '摘要',
    evidenceRefs: ['session:1'],
    knowledgeRefs: ['kb:1'],
    suggestions: [{ type: 'rest' }],
    uncertainties: ['partialData'],
  }, 'request-1');
  assert(parsed.requestId === 'request-1');
  assert(parsed.provider === 'deepseek');
});

Deno.test('unknown uncertainty is rejected', () => {
  assertThrows(() => validateCoachResponse({
    answer: '解释',
    summary: '',
    evidenceRefs: [],
    knowledgeRefs: [],
    suggestions: [],
    uncertainties: ['madeUp'],
  }, 'request-1'), 'INVALID_PROVIDER_RESPONSE');
});

Deno.test('missing JWT returns 401 before configuration or provider access', async () => {
  const handler = createCoachAiHandler();
  const response = await handler(new Request('https://example.invalid/coach-ai', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  }));
  assert(response.status === 401);
});

Deno.test('invalid content type returns 415', async () => {
  const handler = createCoachAiHandler();
  const response = await handler(new Request('https://example.invalid/coach-ai', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer test-token',
      'Content-Type': 'text/plain',
    },
    body: '{}',
  }));
  assert(response.status === 415);
});

Deno.test('Supabase key dictionaries are parsed without exposing values', () => {
  assert(parseDefaultKey('{"default":"publishable-value"}') === 'publishable-value');
  assert(parseDefaultKey('invalid') === null);
});
