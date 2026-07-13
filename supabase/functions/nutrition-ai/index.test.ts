import {
  parseRequestBody,
  validateAiItems,
} from './index.ts';

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
