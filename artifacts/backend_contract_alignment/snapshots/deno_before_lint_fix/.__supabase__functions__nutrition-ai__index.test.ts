import {
  createNutritionAiHandler,
  type NutritionAiClientFactory,
  parseClaimState,
  parseDefaultKey,
  parseRequestBody,
  validateAiItems,
  validateCachedResponse,
} from "./index.ts";

Deno.test("default Supabase key is parsed from a dictionary", () => {
  if (parseDefaultKey('{"default":"test-key"}') !== "test-key") {
    throw new Error("default key was not returned");
  }
});

Deno.test("invalid Supabase key dictionaries return null", () => {
  for (
    const value of [undefined, "", "not-json", "[]", '{"default":123}', "{}"]
  ) {
    if (parseDefaultKey(value) !== null) {
      throw new Error("invalid key dictionary was accepted");
    }
  }
});

type MockRpcResponse = { data: unknown; error: unknown };

function makeEnvironment(values: Record<string, string | undefined>) {
  return (name: string) => values[name];
}

function makeClientFactory(options: {
  userId?: string | null;
  rpc?: (
    name: string,
    args: Record<string, unknown>,
  ) => Promise<MockRpcResponse>;
  keys?: string[];
}) {
  return ((_: string, key: string) => {
    options.keys?.push(key);
    return {
      auth: {
        getUser: async () => ({
          data: {
            user: options.userId === null
              ? null
              : { id: options.userId ?? "test-user" },
          },
          error: null,
        }),
      },
      rpc: async (name: string, args: Record<string, unknown>) =>
        options.rpc?.(name, args) ?? { data: null, error: null },
    };
  }) as unknown as NutritionAiClientFactory;
}

const testEnv = makeEnvironment({
  SUPABASE_URL: "https://example.invalid",
  SUPABASE_ANON_KEY: "anon-test-key",
  SUPABASE_SERVICE_ROLE_KEY: "service-test-key",
  DEEPSEEK_API_KEY: "provider-test-key",
});

function validRequestBody(clientRequestId = "request-1") {
  return JSON.stringify({
    text: "一碗米饭",
    defaultMealType: "早餐",
    clientRequestId,
  });
}

Deno.test("legacy Supabase keys are preferred", async () => {
  const keys: string[] = [];
  const handler = createNutritionAiHandler(
    fetch,
    makeClientFactory({
      keys,
      rpc: async () => ({ data: { status: "IN_PROGRESS" }, error: null }),
    }),
    testEnv,
  );
  await handler(
    new Request("https://example.invalid", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody(),
    }),
  );
  if (keys.join("|") !== "anon-test-key|service-test-key") {
    throw new Error("legacy Supabase keys were not preferred");
  }
});

Deno.test("JSON key dictionaries provide default values", async () => {
  const keys: string[] = [];
  const env = makeEnvironment({
    SUPABASE_URL: "https://example.invalid",
    SUPABASE_PUBLISHABLE_KEYS: '{"default":"publishable-test-key"}',
    SUPABASE_SECRET_KEYS: '{"default":"secret-test-key"}',
    DEEPSEEK_API_KEY: "provider-test-key",
  });
  const handler = createNutritionAiHandler(
    fetch,
    makeClientFactory({
      keys,
      rpc: async () => ({ data: { status: "IN_PROGRESS" }, error: null }),
    }),
    env,
  );
  await handler(
    new Request("https://example.invalid", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody(),
    }),
  );
  if (keys.join("|") !== "publishable-test-key|secret-test-key") {
    throw new Error("JSON key dictionaries were not used");
  }
});

Deno.test("missing or invalid configuration returns CONFIGURATION_ERROR", async () => {
  const handler = createNutritionAiHandler(
    fetch,
    makeClientFactory({}),
    makeEnvironment({
      SUPABASE_URL: "https://example.invalid",
      SUPABASE_PUBLISHABLE_KEYS: "not-json",
      SUPABASE_SECRET_KEYS: "{}",
    }),
  );
  const response = await handler(
    new Request("https://example.invalid", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody(),
    }),
  );
  const body = await response.json();
  if (response.status !== 500 || body.code !== "CONFIGURATION_ERROR") {
    throw new Error("configuration failure was not normalized");
  }
});

function makeFlowRpc(options: {
  claim?: unknown;
  cached?: unknown;
  quota?: unknown;
  save?: unknown;
}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const rpc = async (name: string, args: Record<string, unknown>) => {
    calls.push({ name, args });
    if (name === "nutrition_ai_get_cached_response") {
      return { data: options.cached ?? null, error: null };
    }
    if (name === "nutrition_ai_claim_operation") {
      return {
        data: options.claim ?? { status: "CLAIMED", claimToken: "claim-token" },
        error: null,
      };
    }
    if (name === "consume_ai_quota_for_user") {
      return { data: options.quota ?? true, error: null };
    }
    if (name === "nutrition_ai_save_response") {
      return { data: options.save ?? true, error: null };
    }
    return { data: false, error: null };
  };
  return { calls, rpc };
}

function makeHandler(
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => Promise<MockRpcResponse>,
  fetchImpl: typeof fetch = fetch,
  env = testEnv,
) {
  return createNutritionAiHandler(fetchImpl, makeClientFactory({ rpc }), env);
}

function providerResponse(content: unknown, status = 200) {
  return new Response(
    JSON.stringify({
      choices: [{ message: { content: JSON.stringify(content) } }],
    }),
    { status, headers: { "content-type": "application/json" } },
  );
}

Deno.test("OPTIONS returns 204 with an empty body", async () => {
  const response = await createNutritionAiHandler()(
    new Request("https://example.invalid/nutrition-ai", { method: "OPTIONS" }),
  );
  if (response.status !== 204 || (await response.text()) !== "") {
    throw new Error("OPTIONS response was not an empty 204");
  }
});

Deno.test("missing JWT returns 401", async () => {
  const response = await createNutritionAiHandler()(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      body: validRequestBody(),
    }),
  );
  if (response.status !== 401) throw new Error("missing JWT was not rejected");
});

Deno.test("UTF-8 oversized and invalid JSON requests are rejected", async () => {
  const rpc = makeFlowRpc({}).rpc;
  const handler = makeHandler(rpc);
  const oversized = await handler(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: JSON.stringify({
        text: "汉".repeat(40_000),
        defaultMealType: "早餐",
        clientRequestId: "large-request",
      }),
    }),
  );
  if (oversized.status !== 413) {
    throw new Error("UTF-8 oversized body was accepted");
  }

  const invalid = await handler(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: "{invalid-json",
    }),
  );
  if (invalid.status !== 400) throw new Error("invalid JSON was accepted");
});

Deno.test("CLAIMED, IN_PROGRESS and CACHED states are handled", async () => {
  const claimed = parseClaimState({ status: "CLAIMED", claimToken: "token" });
  const inProgress = parseClaimState({
    status: "IN_PROGRESS",
    claimToken: null,
  });
  const cached = parseClaimState({
    status: "CACHED",
    claimToken: null,
    response: {
      items: [validItem],
      requestId: "cached-1",
      provider: "deepseek",
    },
  });
  if (
    claimed.status !== "CLAIMED" || inProgress.status !== "IN_PROGRESS" ||
    cached.status !== "CACHED"
  ) {
    throw new Error("claim states were not parsed");
  }

  const inProgressResponse = await makeHandler(
    makeFlowRpc({ claim: { status: "IN_PROGRESS", claimToken: null } }).rpc,
  )(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody("in-progress"),
    }),
  );
  if (inProgressResponse.status !== 409) {
    throw new Error("IN_PROGRESS was not returned as 409");
  }

  const cachedResponse = {
    items: [validItem],
    requestId: "cached-2",
    provider: "deepseek",
  };
  const cachedResult = await makeHandler(
    makeFlowRpc({
      claim: { status: "CACHED", claimToken: null, response: cachedResponse },
    }).rpc,
  )(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody("cached"),
    }),
  );
  if (cachedResult.status !== 200) {
    throw new Error("CACHED was not returned as 200");
  }
});

Deno.test("cached response is schema-validated before reuse", async () => {
  const response = await makeHandler(
    makeFlowRpc({
      cached: {
        items: [{ ...validItem, kcal: -1 }],
        requestId: "forged-cache",
        provider: "deepseek",
      },
    }).rpc,
  )(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody("forged-cache"),
    }),
  );
  if (response.status !== 503) {
    throw new Error("invalid cached schema was reused");
  }
});

Deno.test("provider timeout releases the matching claim token", async () => {
  const flow = makeFlowRpc({});
  const response = await makeHandler(
    flow.rpc,
    async () => {
      throw new DOMException("mock timeout", "AbortError");
    },
  )(
    new Request("https://example.invalid/nutrition-ai", {
      method: "POST",
      headers: { authorization: "Bearer test-jwt" },
      body: validRequestBody("timeout"),
    }),
  );
  const release = flow.calls.find((call) =>
    call.name === "nutrition_ai_release_operation"
  );
  const responseBody = await response.json();
  if (
    response.status !== 502 ||
    responseBody.code !== "AI_TIMEOUT" ||
    release?.args.p_claim_token !== "claim-token"
  ) {
    throw new Error("timeout did not release the matching claim token");
  }
});

Deno.test("invalid provider response is not saved and logs stay redacted", async () => {
  const flow = makeFlowRpc({});
  const logs: string[] = [];
  const originalError = console.error;
  console.error = (...args: unknown[]) => logs.push(args.join(" "));
  let response: Response | null = null;
  try {
    response = await makeHandler(
      flow.rpc,
      async () => providerResponse("not-json"),
    )(
      new Request("https://example.invalid/nutrition-ai", {
        method: "POST",
        headers: { authorization: "Bearer sensitive-jwt" },
        body: JSON.stringify({
          text: "sensitive meal text",
          defaultMealType: "早餐",
          clientRequestId: "invalid-provider",
        }),
      }),
    );
  } finally {
    console.error = originalError;
  }
  const saved = flow.calls.some((call) =>
    call.name === "nutrition_ai_save_response"
  );
  const logText = logs.join("\n");
  if (
    response?.status !== 502 || saved ||
    logText.includes("sensitive meal text") ||
    logText.includes("sensitive-jwt") || logText.includes("provider-test-key")
  ) {
    throw new Error(
      "invalid provider response was saved or sensitive data was logged",
    );
  }
});

const validItem = {
  name: "鸡蛋",
  amount: 1,
  unit: "个",
  kcal: 70,
  protein: 6,
  carbs: 1,
  fat: 5,
  mealType: "早餐",
};

Deno.test("valid AI items pass schema validation", () => {
  const items = validateAiItems({ items: [validItem] });
  if (items[0].name !== "鸡蛋" || items[0].mealType !== "早餐") {
    throw new Error("validated item was changed");
  }
});

Deno.test("invalid meal type is rejected", () => {
  try {
    validateAiItems([{ ...validItem, mealType: "夜宵" }]);
    throw new Error("invalid meal type was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("negative nutrition is rejected", () => {
  try {
    validateAiItems([{ ...validItem, kcal: -1 }]);
    throw new Error("negative nutrition was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("request text and request id are validated", () => {
  const parsed = parseRequestBody({
    text: "一碗米饭",
    defaultMealType: "午餐",
    clientRequestId: "request-1",
  });
  if (parsed.defaultMealType !== "午餐") {
    throw new Error("meal type was not preserved");
  }
});

Deno.test("invalid request meal type is rejected", () => {
  try {
    parseRequestBody({
      text: "米饭",
      defaultMealType: "夜宵",
      clientRequestId: "r",
    });
    throw new Error("invalid request was accepted");
  } catch (error) {
    if (!(error instanceof Error) || error.message !== "INVALID_MEAL_TYPE") {
      throw error;
    }
  }
});

Deno.test("empty provider result is rejected", () => {
  try {
    validateAiItems([]);
    throw new Error("empty result was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("more than thirty provider items are rejected", () => {
  try {
    validateAiItems(Array.from({ length: 31 }, () => validItem));
    throw new Error("too many items were accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("non-object provider result is rejected", () => {
  try {
    validateAiItems("not-json-items");
    throw new Error("non-object result was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("empty request text is rejected", () => {
  try {
    parseRequestBody({
      text: " ",
      defaultMealType: "早餐",
      clientRequestId: "r",
    });
    throw new Error("empty text was accepted");
  } catch (error) {
    if (!(error instanceof Error) || error.message !== "INVALID_TEXT") {
      throw error;
    }
  }
});

Deno.test("oversized request id is rejected", () => {
  try {
    parseRequestBody({
      text: "米饭",
      defaultMealType: "早餐",
      clientRequestId: "r".repeat(129),
    });
    throw new Error("oversized request id was accepted");
  } catch (error) {
    if (!(error instanceof Error) || error.message !== "INVALID_REQUEST_ID") {
      throw error;
    }
  }
});

Deno.test("cached response is validated before reuse", () => {
  const cached = validateCachedResponse({
    items: [validItem],
    requestId: "request-1",
    provider: "deepseek",
  });
  if (cached.items.length !== 1 || cached.requestId !== "request-1") {
    throw new Error("cached response was not validated");
  }
});

Deno.test("malformed cached response is rejected", () => {
  try {
    validateCachedResponse({
      items: [{ ...validItem, kcal: -1 }],
      requestId: "request-1",
      provider: "deepseek",
    });
    throw new Error("malformed cached response was accepted");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_PROVIDER_RESPONSE"
    ) {
      throw error;
    }
  }
});

Deno.test("OPTIONS preflight has no response body", async () => {
  const response = await createNutritionAiHandler()(
    new Request("https://example.invalid/nutrition-ai", { method: "OPTIONS" }),
  );
  if (response.status !== 204 || (await response.text()) !== "") {
    throw new Error("preflight must return an empty 204 response");
  }
});
