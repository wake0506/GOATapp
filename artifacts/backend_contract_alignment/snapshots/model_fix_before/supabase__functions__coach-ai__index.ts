import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MAX_BODY_BYTES = 64 * 1024;
const TIMEOUT_MS = 20_000;
const MAX_REQUEST_ID_LENGTH = 128;
const MAX_CONTEXT_ITEMS = 50;
const JSON_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TASK_TYPES = new Set([
  "nutrition_explanation",
  "progression_explanation",
  "rest_explanation",
  "coverage_explanation",
  "weekly_review",
  "memory_inference",
]);

const UNCERTAINTIES = new Set([
  "insufficientEvidence",
  "partialData",
  "missingUserContext",
  "needsConfirmation",
]);

export type CoachAiRequest = {
  taskType: string;
  structuredContext: Record<string, unknown>;
  retrievedKnowledge: unknown[];
  activeProfile: Record<string, unknown>;
  activeMemories: unknown[];
  requestId: string;
};

export type CoachAiResponse = {
  answer: string;
  summary: string;
  evidenceRefs: string[];
  knowledgeRefs: string[];
  suggestions: Record<string, unknown>[];
  uncertainties: string[];
  requestId: string;
  provider: string;
};

type EnvironmentReader = (name: string) => string | undefined;
type CoachClientFactory = typeof createClient;

export function parseDefaultKey(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Record<string, unknown>;
    return typeof parsed.default === "string" && parsed.default
      ? parsed.default
      : null;
  } catch {
    return null;
  }
}

function objectValue(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("INVALID_BODY");
  }
  return value as Record<string, unknown>;
}

function boundedArray(value: unknown, maximum: number): unknown[] {
  if (!Array.isArray(value) || value.length > maximum) {
    throw new Error("INVALID_BODY");
  }
  return value;
}

function stringArray(value: unknown, maximum: number): string[] {
  const items = boundedArray(value, maximum);
  if (items.some((item) => typeof item !== "string" || item.length > 256)) {
    throw new Error("INVALID_PROVIDER_RESPONSE");
  }
  return items as string[];
}

export function parseCoachRequest(value: unknown): CoachAiRequest {
  const body = objectValue(value);
  const taskType = typeof body.taskType === "string" ? body.taskType : "";
  const requestId = typeof body.requestId === "string"
    ? body.requestId.trim()
    : "";
  if (!TASK_TYPES.has(taskType)) throw new Error("INVALID_TASK_TYPE");
  if (!requestId || requestId.length > MAX_REQUEST_ID_LENGTH) {
    throw new Error("INVALID_REQUEST_ID");
  }
  return {
    taskType,
    structuredContext: objectValue(body.structuredContext),
    retrievedKnowledge: boundedArray(body.retrievedKnowledge ?? [], 20),
    activeProfile: objectValue(body.activeProfile ?? {}),
    activeMemories: boundedArray(body.activeMemories ?? [], MAX_CONTEXT_ITEMS),
    requestId,
  };
}

export function validateCoachResponse(
  value: unknown,
  requestId: string,
): CoachAiResponse {
  const body = objectValue(value);
  const answer = typeof body.answer === "string" ? body.answer.trim() : "";
  const summary = typeof body.summary === "string" ? body.summary.trim() : "";
  if (!answer || answer.length > 12_000 || summary.length > 2_000) {
    throw new Error("INVALID_PROVIDER_RESPONSE");
  }
  const suggestions = boundedArray(body.suggestions ?? [], 10).map((item) =>
    objectValue(item)
  );
  const uncertainties = stringArray(body.uncertainties ?? [], 10);
  if (uncertainties.some((item) => !UNCERTAINTIES.has(item))) {
    throw new Error("INVALID_PROVIDER_RESPONSE");
  }
  return {
    answer,
    summary,
    evidenceRefs: stringArray(body.evidenceRefs ?? [], 50),
    knowledgeRefs: stringArray(body.knowledgeRefs ?? [], 50),
    suggestions,
    uncertainties,
    requestId,
    provider: "deepseek",
  };
}

function response(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function errorResponse(code: string, status: number, requestId = ""): Response {
  return response({ code, ...(requestId ? { requestId } : {}) }, status);
}

function stripFence(value: string): string {
  const match = value.trim().match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return match?.[1]?.trim() ?? value.trim();
}

function systemPrompt(): string {
  return [
    "You are GOAT AI Coach. Explain only the structured facts supplied by the app.",
    "Never recalculate effective sets, trend weight, progression recommendations,",
    "coverage level, exercise recommendations, or rest prescriptions.",
    "Never claim that a suggestion has been applied. Return suggestions as proposals only.",
    "USER_PROVIDED profile and memory values are authoritative and must not be overwritten.",
    "Return one JSON object with answer, summary, evidenceRefs, knowledgeRefs,",
    "suggestions, and uncertainties. Do not include markdown fences.",
  ].join(" ");
}

export function createCoachAiHandler(
  fetchImpl: typeof fetch = fetch,
  clientFactory: CoachClientFactory = createClient,
  readEnv: EnvironmentReader = (name) => Deno.env.get(name),
): (request: Request) => Promise<Response> {
  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", 405);
    }

    const serverRequestId = crypto.randomUUID();
    const contentType = request.headers.get("content-type")
      ?.split(";", 1)[0]
      .trim()
      .toLowerCase();
    if (contentType !== "application/json") {
      return errorResponse("INVALID_CONTENT_TYPE", 415, serverRequestId);
    }
    const authHeader = request.headers.get("authorization") ?? "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice("Bearer ".length).trim()
      : "";
    if (!token) return errorResponse("UNAUTHORIZED", 401, serverRequestId);

    let body: CoachAiRequest;
    try {
      const rawBody = await request.text();
      if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
        return errorResponse("REQUEST_TOO_LARGE", 413, serverRequestId);
      }
      body = parseCoachRequest(JSON.parse(rawBody));
    } catch (error) {
      const code = error instanceof Error ? error.message : "INVALID_BODY";
      const allowed = new Set([
        "INVALID_BODY",
        "INVALID_TASK_TYPE",
        "INVALID_REQUEST_ID",
      ]);
      return errorResponse(
        allowed.has(code) ? code : "INVALID_BODY",
        400,
        serverRequestId,
      );
    }

    const supabaseUrl = readEnv("SUPABASE_URL") ?? "";
    const publishableKey = readEnv("SUPABASE_ANON_KEY") ??
      parseDefaultKey(readEnv("SUPABASE_PUBLISHABLE_KEYS"));
    if (!supabaseUrl || !publishableKey) {
      return errorResponse("CONFIGURATION_ERROR", 500, serverRequestId);
    }
    const userClient = clientFactory(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(
      token,
    );
    if (authError || !authData.user?.id) {
      return errorResponse("UNAUTHORIZED", 401, serverRequestId);
    }

    const providerKey = readEnv("DEEPSEEK_API_KEY");
    if (!providerKey) {
      return errorResponse("AI_NOT_CONFIGURED", 503, serverRequestId);
    }

    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), TIMEOUT_MS);
    try {
      const providerResponse = await fetchImpl(
        "https://api.deepseek.com/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${providerKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "deepseek-chat",
            response_format: { type: "json_object" },
            temperature: 0.2,
            messages: [
              { role: "system", content: systemPrompt() },
              {
                role: "user",
                content: JSON.stringify({
                  taskType: body.taskType,
                  structuredContext: body.structuredContext,
                  retrievedKnowledge: body.retrievedKnowledge,
                  activeProfile: body.activeProfile,
                  activeMemories: body.activeMemories,
                }),
              },
            ],
          }),
          signal: abortController.signal,
        },
      );
      if (!providerResponse.ok) {
        console.error(JSON.stringify({
          requestId: serverRequestId,
          result: "PROVIDER_FAILED",
          status: providerResponse.status,
        }));
        return errorResponse("AI_UPSTREAM_ERROR", 502, serverRequestId);
      }
      const envelope = await providerResponse.json() as Record<string, unknown>;
      const choices = envelope.choices;
      const firstChoice = Array.isArray(choices) ? choices[0] : null;
      const message = firstChoice &&
          typeof firstChoice === "object" &&
          !Array.isArray(firstChoice)
        ? (firstChoice as Record<string, unknown>).message
        : null;
      const content = message &&
          typeof message === "object" &&
          !Array.isArray(message)
        ? (message as Record<string, unknown>).content
        : null;
      if (typeof content !== "string") {
        throw new Error("INVALID_PROVIDER_RESPONSE");
      }
      const validated = validateCoachResponse(
        JSON.parse(stripFence(content)),
        body.requestId,
      );
      console.info(JSON.stringify({
        requestId: serverRequestId,
        taskType: body.taskType,
        result: "COMPLETED",
      }));
      return response(validated, 200);
    } catch (error) {
      const code = error instanceof DOMException && error.name === "AbortError"
        ? "AI_TIMEOUT"
        : "INVALID_PROVIDER_RESPONSE";
      console.error(JSON.stringify({
        requestId: serverRequestId,
        taskType: body.taskType,
        result: code,
      }));
      return errorResponse(
        code,
        code === "AI_TIMEOUT" ? 504 : 502,
        serverRequestId,
      );
    } finally {
      clearTimeout(timeout);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createCoachAiHandler());
}
