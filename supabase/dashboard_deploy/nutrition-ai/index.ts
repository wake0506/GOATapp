import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const MAX_BODY_BYTES = 64 * 1024;
const MAX_TEXT_LENGTH = 8_000;
const TIMEOUT_MS = 20_000;
const LEASE_RETRY_SECONDS = 120;
const MEAL_TYPES = new Set(['早餐', '午餐', '晚餐', '加餐']);
const JSON_HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export type ValidatedAiItem = {
  name: string;
  amount: number;
  unit: string;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  mealType: string;
};

export function parseRequestBody(value: unknown): {
  text: string;
  defaultMealType: string;
  clientRequestId: string;
} {
  if (!value || typeof value !== 'object') throw new Error('INVALID_BODY');
  const body = value as Record<string, unknown>;
  const text = typeof body.text === 'string' ? body.text.trim() : '';
  const defaultMealType =
    typeof body.defaultMealType === 'string' ? body.defaultMealType : '加餐';
  const clientRequestId =
    typeof body.clientRequestId === 'string' ? body.clientRequestId.trim() : '';
  if (!text || text.length > MAX_TEXT_LENGTH) throw new Error('INVALID_TEXT');
  if (!MEAL_TYPES.has(defaultMealType)) throw new Error('INVALID_MEAL_TYPE');
  if (!clientRequestId || clientRequestId.length > 128) {
    throw new Error('INVALID_REQUEST_ID');
  }
  return { text, defaultMealType, clientRequestId };
}

export function validateAiItems(value: unknown): ValidatedAiItem[] {
  const rawItems = Array.isArray(value)
    ? value
    : value && typeof value === 'object' && Array.isArray((value as any).items)
    ? (value as any).items
    : null;
  if (!rawItems || rawItems.length === 0 || rawItems.length > 30) {
    throw new Error('INVALID_PROVIDER_RESPONSE');
  }

  return rawItems.map((raw: unknown) => {
    if (!raw || typeof raw !== 'object') throw new Error('INVALID_PROVIDER_RESPONSE');
    const item = raw as Record<string, unknown>;
    const name = typeof item.name === 'string' ? item.name.trim() : '';
    const unit = typeof item.unit === 'string' ? item.unit.trim() : '';
    const mealType = typeof item.mealType === 'string' ? item.mealType : '';
    const amount = Number(item.amount);
    const kcal = Number(item.kcal);
    const protein = Number(item.protein);
    const carbs = Number(item.carbs);
    const fat = Number(item.fat);
    if (
      !name ||
      !unit ||
      !MEAL_TYPES.has(mealType) ||
      !Number.isFinite(amount) ||
      amount <= 0 ||
      !Number.isFinite(kcal) ||
      kcal < 0 ||
      !Number.isFinite(protein) ||
      protein < 0 ||
      !Number.isFinite(carbs) ||
      carbs < 0 ||
      !Number.isFinite(fat) ||
      fat < 0
    ) {
      throw new Error('INVALID_PROVIDER_RESPONSE');
    }
    return { name, amount, unit, kcal, protein, carbs, fat, mealType };
  });
}

function responseBody(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function errorResponse(
  code: string,
  message: string,
  status: number,
  requestId = '',
  details: Record<string, unknown> = {},
) {
  return responseBody({ code, message, ...details, ...(requestId ? { requestId } : {}) }, status);
}

function stripFence(value: string): string {
  const match = value.trim().match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return match?.[1]?.trim() ?? value.trim();
}

export function createNutritionAiHandler(
  fetchImpl: typeof fetch = fetch,
): (request: Request) => Promise<Response> {
  return async (request: Request) => {
    if (request.method === 'OPTIONS') return responseBody({}, 204);
    if (request.method !== 'POST') {
      return errorResponse('METHOD_NOT_ALLOWED', '仅支持 POST 请求', 405);
    }

    const requestId = crypto.randomUUID();
    const contentLength = Number(request.headers.get('content-length') ?? 0);
    if (contentLength > MAX_BODY_BYTES) {
      return errorResponse('REQUEST_TOO_LARGE', '请求内容过大', 413, requestId);
    }

    const authHeader = request.headers.get('authorization') ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice('Bearer '.length).trim()
      : '';
    if (!token) return errorResponse('UNAUTHORIZED', '请先登录', 401, requestId);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    );
    const { data: authData, error: authError } = await supabase.auth.getUser(token);
    const userId = authData.user?.id;
    if (authError || !userId) return errorResponse('UNAUTHORIZED', '登录状态无效', 401, requestId);

    let body: { text: string; defaultMealType: string; clientRequestId: string };
    try {
      const raw = await request.json();
      if (new TextEncoder().encode(JSON.stringify(raw)).byteLength > MAX_BODY_BYTES) {
        return errorResponse('REQUEST_TOO_LARGE', '请求内容过大', 413, requestId);
      }
      body = parseRequestBody(raw);
    } catch (error) {
      const rawCode = error instanceof Error ? error.message : 'INVALID_BODY';
      const code = new Set([
        'INVALID_BODY',
        'INVALID_TEXT',
        'INVALID_MEAL_TYPE',
        'INVALID_REQUEST_ID',
      ]).has(rawCode)
        ? rawCode
        : 'INVALID_BODY';
      return errorResponse(code, '请求参数无效', 400, requestId);
    }

    const cached = await supabase.rpc('nutrition_ai_get_cached_response', {
      p_client_request_id: body.clientRequestId,
    });
    if (cached.error) {
      console.error(JSON.stringify({ code: 'CACHE_READ_FAILED', requestId }));
      return errorResponse('SERVICE_UNAVAILABLE', 'AI 服务暂不可用', 503, requestId);
    }
    if (cached.data && typeof cached.data === 'object') {
      return responseBody(cached.data as Record<string, unknown>, 200);
    }

    const providerKey = Deno.env.get('DEEPSEEK_API_KEY');
    if (!providerKey) return errorResponse('AI_NOT_CONFIGURED', 'AI 服务暂未配置', 503, requestId);

    const claim = await supabase.rpc('nutrition_ai_claim_operation', {
      p_client_request_id: body.clientRequestId,
    });
    if (claim.error) {
      console.error(JSON.stringify({ code: 'IDEMPOTENCY_CLAIM_FAILED', requestId }));
      return errorResponse('SERVICE_UNAVAILABLE', 'AI 服务暂不可用', 503, requestId);
    }
    if (claim.data !== true) {
      const concurrent = await supabase.rpc('nutrition_ai_get_cached_response', {
        p_client_request_id: body.clientRequestId,
      });
      if (concurrent.error) {
        console.error(JSON.stringify({ code: 'CACHE_RECHECK_FAILED', requestId }));
        return errorResponse('SERVICE_UNAVAILABLE', 'AI 服务暂不可用', 503, requestId);
      }
      if (concurrent.data && typeof concurrent.data === 'object') {
        return responseBody(concurrent.data as Record<string, unknown>, 200);
      }
      return errorResponse(
        'REQUEST_IN_PROGRESS',
        '请求正在处理中',
        409,
        requestId,
        { retryAfterSeconds: LEASE_RETRY_SECONDS },
      );
    }

    const releaseOperation = async () => {
      const released = await supabase.rpc('nutrition_ai_release_operation', {
        p_client_request_id: body.clientRequestId,
      });
      if (released.error) {
        console.error(JSON.stringify({ code: 'IDEMPOTENCY_RELEASE_FAILED', requestId }));
      }
    };

    const quota = await supabase.rpc('consume_ai_quota');
    if (quota.error) {
      await releaseOperation();
      console.error(JSON.stringify({ code: 'QUOTA_CHECK_FAILED', requestId }));
      return errorResponse('SERVICE_UNAVAILABLE', 'AI 服务暂不可用', 503, requestId);
    }
    if (quota.data !== true) {
      await releaseOperation();
      return errorResponse('RATE_LIMITED', '今日 AI 解析次数已用完', 429, requestId);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const providerResponse = await fetchImpl('https://api.deepseek.com/v1/chat/completions', {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${providerKey}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          temperature: 0.1,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: '你是严格的营养记录 JSON 解析器，只返回 {"items":[]}。' },
            {
              role: 'user',
              content: `将以下饮食描述解析为 JSON。每项必须包含 name, amount, unit, kcal, protein, carbs, fat, mealType；mealType 只能是早餐、午餐、晚餐、加餐；未识别餐次使用${body.defaultMealType}。用户描述：${body.text}`,
            },
          ],
        }),
      });
      if (!providerResponse.ok) {
        await releaseOperation();
        console.error(JSON.stringify({ code: 'PROVIDER_HTTP_ERROR', status: providerResponse.status, requestId }));
        return errorResponse('AI_PROVIDER_ERROR', 'AI 解析暂时失败，请稍后重试', 502, requestId);
      }
      const providerJson = await providerResponse.json();
      const content = providerJson?.choices?.[0]?.message?.content;
      if (typeof content !== 'string') throw new Error('INVALID_PROVIDER_RESPONSE');
      const items = validateAiItems(JSON.parse(stripFence(content)));
      const result = { items, requestId, provider: 'deepseek' };
      const saved = await supabase.rpc('nutrition_ai_save_response', {
        p_client_request_id: body.clientRequestId,
        p_response: result,
      });
      if (saved.error || saved.data !== true) {
        await releaseOperation();
        console.error(JSON.stringify({ code: 'IDEMPOTENCY_SAVE_FAILED', requestId }));
        return errorResponse('SERVICE_UNAVAILABLE', 'AI 服务暂不可用', 503, requestId);
      }
      return responseBody(result, 200);
    } catch (error) {
      await releaseOperation();
      const isTimeout = error instanceof DOMException && error.name === 'AbortError';
      console.error(JSON.stringify({ code: isTimeout ? 'PROVIDER_TIMEOUT' : 'INVALID_PROVIDER_RESPONSE', requestId }));
      return errorResponse(
        isTimeout ? 'AI_TIMEOUT' : 'INVALID_PROVIDER_RESPONSE',
        isTimeout ? 'AI 请求超时，请稍后重试' : 'AI 返回内容无效，请稍后重试',
        502,
        requestId,
      );
    } finally {
      clearTimeout(timeout);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createNutritionAiHandler());
}
