import { createDeleteAccountHandler } from "./index.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

function assert(
  condition: unknown,
  message = "assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function environment(name: string): string | undefined {
  return {
    SUPABASE_URL: "https://example.invalid",
    SUPABASE_ANON_KEY: "anon-value",
    SUPABASE_SERVICE_ROLE_KEY: "service-value",
  }[name];
}

function clientFactory(options: {
  ready?: boolean;
  readyError?: boolean;
  deleteError?: boolean;
}) {
  let calls = 0;
  return ((..._arguments: unknown[]) => {
    calls++;
    if (calls === 1) {
      return {
        auth: {
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-0000-0000-000000000001" } },
              error: null,
            }),
        },
      };
    }
    return {
      rpc: () =>
        Promise.resolve({
          data: options.ready ?? true,
          error: options.readyError ? { code: "FAILED" } : null,
        }),
      auth: {
        admin: {
          deleteUser: () =>
            Promise.resolve({
              error: options.deleteError ? { code: "FAILED" } : null,
            }),
        },
      },
    };
  }) as unknown as typeof createClient;
}

function request(confirmPhrase: string): Request {
  return new Request("https://example.invalid/delete-account", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ confirmPhrase }),
  });
}

Deno.test("wrong confirmation phrase is rejected before remote calls", async () => {
  const handler = createDeleteAccountHandler(clientFactory({}), environment);
  const response = await handler(request("delete"));
  assert(response.status === 400);
});

Deno.test("cascade readiness failure preserves the auth user", async () => {
  const handler = createDeleteAccountHandler(
    clientFactory({ ready: false }),
    environment,
  );
  const response = await handler(request("DELETE MY ACCOUNT"));
  assert(response.status === 503);
  const body = await response.json();
  assert(body.code === "ACCOUNT_DELETION_UNAVAILABLE");
});

Deno.test("remote auth deletion failure returns a redacted error", async () => {
  const handler = createDeleteAccountHandler(
    clientFactory({ deleteError: true }),
    environment,
  );
  const response = await handler(request("DELETE MY ACCOUNT"));
  assert(response.status === 503);
  const body = await response.json();
  assert(body.code === "ACCOUNT_DELETION_FAILED");
  assert(!JSON.stringify(body).includes("service-value"));
});

Deno.test("successful readiness and auth deletion returns 204", async () => {
  const handler = createDeleteAccountHandler(clientFactory({}), environment);
  const response = await handler(request("DELETE MY ACCOUNT"));
  assert(response.status === 204);
  assert((await response.text()) === "");
});
