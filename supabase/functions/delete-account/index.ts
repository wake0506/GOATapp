import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
function key(value: string | undefined): string | null { try { const v = JSON.parse(value ?? '{}') as Record<string, unknown>; return typeof v.default === 'string' ? v.default : null; } catch { return null; } }
function error(code: string, status: number, requestId: string) { return new Response(JSON.stringify({ code, requestId }), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } }); }
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS }); if (request.method !== 'POST') return error('METHOD_NOT_ALLOWED', 405, crypto.randomUUID());
  const requestId = crypto.randomUUID(); const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '').trim() ?? ''; if (!token) return error('UNAUTHORIZED', 401, requestId);
  let confirmation = ''; try { const body = await request.json() as Record<string, unknown>; confirmation = typeof body.confirmPhrase === 'string' ? body.confirmPhrase : ''; } catch { return error('INVALID_BODY', 400, requestId); }
  if (confirmation !== 'DELETE MY ACCOUNT') return error('CONFIRMATION_REQUIRED', 400, requestId);
  const url = Deno.env.get('SUPABASE_URL') ?? ''; const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? key(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')); const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? key(Deno.env.get('SUPABASE_SECRET_KEYS'));
  if (!url || !anon || !secret) return error('CONFIGURATION_ERROR', 500, requestId);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } }); const { data, error: authError } = await userClient.auth.getUser(token); const userId = data.user?.id; if (authError || !userId) return error('UNAUTHORIZED', 401, requestId);
  const admin = createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } }); const ready = await admin.rpc('assert_account_deletion_ready'); if (ready.error || ready.data !== true) { console.error(JSON.stringify({ requestId, result: 'CASCADE_CHECK_FAILED' })); return error('ACCOUNT_DELETION_UNAVAILABLE', 503, requestId); }
  const deleted = await admin.auth.admin.deleteUser(userId, false); if (deleted.error) { console.error(JSON.stringify({ requestId, result: 'DELETE_FAILED' })); return error('ACCOUNT_DELETION_FAILED', 503, requestId); }
  console.info(JSON.stringify({ requestId, result: 'DELETED' })); return new Response(null, { status: 204, headers: CORS });
});
