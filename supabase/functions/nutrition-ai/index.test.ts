import {
  createNutritionAiHandler,
  parseDefaultKey,
  parseRequestBody,
  validateCachedResponse,
  validateAiItems,
} from './index.ts';

Deno.test('default Supabase key is parsed from a dictionary', () => {
  if (parseDefaultKey('{"default":"test-key"}') !== 'test-key') {
    throw new Error('default key was not returned');
  }
});

Deno.test('invalid Supabase key dictionaries return null', () => {
  for (const value of [undefined, '', 'not-json', '[]', '{"default":123}', '{}']) {
    if (parseDefaultKey(value) !== null) {
      throw new Error('invalid key dictionary was accepted');
    }
  }
});

const validItem = {
  name: '鸡蛋',
  amount: 1,
  unit: '个',
  kcal: 70,
  protein: 6,
  carbs: 1,
  fat: 5,
  mealType: '早餐',
};

Deno.test('valid AI items pass schema validation', () => {
  const items = validateAiItems({ items: [validItem] });
  if (items[0].name !== '鸡蛋' || items[0].mealType !== '早餐') {
    throw new Error('validated item was changed');
  }
});

Deno.test('invalid meal type is rejected', () => {
  try {
    validateAiItems([{ ...validItem, mealType: '夜宵' }]);
    throw new Error('invalid meal type was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('negative nutrition is rejected', () => {
  try {
    validateAiItems([{ ...validItem, kcal: -1 }]);
    throw new Error('negative nutrition was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('request text and request id are validated', () => {
  const parsed = parseRequestBody({
    text: '一碗米饭',
    defaultMealType: '午餐',
    clientRequestId: 'request-1',
  });
  if (parsed.defaultMealType !== '午餐') throw new Error('meal type was not preserved');
});

Deno.test('invalid request meal type is rejected', () => {
  try {
    parseRequestBody({ text: '米饭', defaultMealType: '夜宵', clientRequestId: 'r' });
    throw new Error('invalid request was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_MEAL_TYPE') throw error;
  }
});

Deno.test('empty provider result is rejected', () => {
  try {
    validateAiItems([]);
    throw new Error('empty result was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('more than thirty provider items are rejected', () => {
  try {
    validateAiItems(Array.from({ length: 31 }, () => validItem));
    throw new Error('too many items were accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('non-object provider result is rejected', () => {
  try {
    validateAiItems('not-json-items');
    throw new Error('non-object result was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('empty request text is rejected', () => {
  try {
    parseRequestBody({ text: ' ', defaultMealType: '早餐', clientRequestId: 'r' });
    throw new Error('empty text was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_TEXT') throw error;
  }
});

Deno.test('oversized request id is rejected', () => {
  try {
    parseRequestBody({
      text: '米饭',
      defaultMealType: '早餐',
      clientRequestId: 'r'.repeat(129),
    });
    throw new Error('oversized request id was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_REQUEST_ID') {
      throw error;
    }
  }
});

Deno.test('cached response is validated before reuse', () => {
  const cached = validateCachedResponse({
    items: [validItem],
    requestId: 'request-1',
    provider: 'deepseek',
  });
  if (cached.items.length !== 1 || cached.requestId !== 'request-1') {
    throw new Error('cached response was not validated');
  }
});

Deno.test('malformed cached response is rejected', () => {
  try {
    validateCachedResponse({
      items: [{ ...validItem, kcal: -1 }],
      requestId: 'request-1',
      provider: 'deepseek',
    });
    throw new Error('malformed cached response was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_PROVIDER_RESPONSE') {
      throw error;
    }
  }
});

Deno.test('OPTIONS preflight has no response body', async () => {
  const response = await createNutritionAiHandler()(
    new Request('https://example.invalid/nutrition-ai', { method: 'OPTIONS' }),
  );
  if (response.status !== 204 || (await response.text()) !== '') {
    throw new Error('preflight must return an empty 204 response');
  }
});
