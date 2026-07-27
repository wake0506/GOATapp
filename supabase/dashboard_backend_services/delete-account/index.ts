import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MAX_BODY_BYTES = 8 * 1024;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type DeleteClientFactory = typeof createClient;
type EnvironmentReader = (name: string) => string | undefined;

export function key(value: string | undefined): string | null {
  try {
    const parsed = JSON.parse(value ?? "{}") as Record<string, unknown>;
    return typeof parsed.default === "string" && parsed.default
      ? parsed.default
      : null;
  } catch {
    return null;
  }
}

function error(code: string, status: number, requestId: string) {
  return new Response(JSON.stringify({ code, requestId }), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

export function createDeleteAccountHandler(
  clientFactory: DeleteClientFactory = createClient,
  readEnv: EnvironmentReader = (name) => Deno.env.get(name),
): (request: Request) => Promise<Response> {
  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }
    const requestId = crypto.randomUUID();
    if (request.method !== "POST") {
      return error("METHOD_NOT_ALLOWED", 405, requestId);
    }

    const contentType = request.headers.get("content-type")?.split(";", 1)[0]
      .trim().toLowerCase();
    if (contentType !== "application/json") {
      return error("INVALID_CONTENT_TYPE", 415, requestId);
    }
    const token =
      request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim() ??
        "";
    if (!token) return error("UNAUTHORIZED", 401, requestId);

    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
      return error("REQUEST_TOO_LARGE", 413, requestId);
    }
    let body: Record<string, unknown>;
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        return error("INVALID_BODY", 400, requestId);
      }
      body = parsed as Record<string, unknown>;
    } catch {
      return error("INVALID_BODY", 400, requestId);
    }
    if (body.confirmPhrase !== "DELETE MY ACCOUNT") {
      return error("CONFIRMATION_REQUIRED", 400, requestId);
    }

    const url = readEnv("SUPABASE_URL") ?? "";
    const anon = readEnv("SUPABASE_ANON_KEY") ??
      key(readEnv("SUPABASE_PUBLISHABLE_KEYS"));
    const secret = readEnv("SUPABASE_SERVICE_ROLE_KEY") ??
      key(readEnv("SUPABASE_SECRET_KEYS"));
    if (!url || !anon || !secret) {
      return error("CONFIGURATION_ERROR", 500, requestId);
    }

    const userClient = clientFactory(url, anon, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data, error: authError } = await userClient.auth.getUser(token);
    const userId = data.user?.id;
    if (authError || !userId) return error("UNAUTHORIZED", 401, requestId);

    const admin = clientFactory(url, secret, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const ready = await admin.rpc("assert_account_deletion_ready");
    if (ready.error || ready.data !== true) {
      console.error(
        JSON.stringify({ requestId, result: "CASCADE_CHECK_FAILED" }),
      );
      return error("ACCOUNT_DELETION_UNAVAILABLE", 503, requestId);
    }
    const deleted = await admin.auth.admin.deleteUser(userId, false);
    if (deleted.error) {
      console.error(JSON.stringify({ requestId, result: "DELETE_FAILED" }));
      return error("ACCOUNT_DELETION_FAILED", 503, requestId);
    }
    console.info(JSON.stringify({ requestId, result: "DELETED" }));
    return new Response(null, { status: 204, headers: CORS });
  };
}

if (import.meta.main) {
  Deno.serve(createDeleteAccountHandler());
}
