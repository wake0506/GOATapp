import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const MAX_BODY_BYTES = 8 * 1024;
const MAX_EXPORT_BYTES = 5 * 1024 * 1024;
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
function defaultKey(value: string | undefined): string | null { if (!value) return null; try { const parsed = JSON.parse(value) as Record<string, unknown>; return typeof parsed.default === 'string' && parsed.default ? parsed.default : null; } catch { return null; } }
function json(body: Record<string, unknown>, status: number) { return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } }); }
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (request.method !== 'POST') return json({ code: 'METHOD_NOT_ALLOWED' }, 405);
  const requestId = crypto.randomUUID(); const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '').trim() ?? '';
  if (!token) return json({ code: 'UNAUTHORIZED', requestId }, 401);
  const raw = await request.text(); if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json({ code: 'REQUEST_TOO_LARGE', requestId }, 413);
  const url = Deno.env.get('SUPABASE_URL') ?? ''; const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? defaultKey(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')); const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? defaultKey(Deno.env.get('SUPABASE_SECRET_KEYS'));
  if (!url || !anon || !secret) return json({ code: 'CONFIGURATION_ERROR', requestId }, 500);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } }); const { data: authData, error: authError } = await userClient.auth.getUser(token); const userId = authData.user?.id;
  if (authError || !userId) return json({ code: 'UNAUTHORIZED', requestId }, 401);
  const admin = createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
  const rows = await Promise.all([admin.from('user_profiles').select('*').eq('id', userId).maybeSingle(),admin.from('diet_logs').select('*').eq('user_id', userId),admin.from('exercise_logs').select('*').eq('user_id', userId),admin.from('daily_tracking').select('*').eq('user_id', userId),admin.from('water_intake_records').select('*').eq('user_id', userId),admin.from('body_weight_logs').select('*').eq('user_id', userId),admin.from('training_sessions').select('*').eq('user_id', userId),admin.from('chat_history').select('*').eq('user_id', userId)]);
  if (rows.some((result) => result.error && result.error.code !== '42P01')) { console.error(JSON.stringify({ requestId, result: 'EXPORT_QUERY_FAILED' })); return json({ code: 'EXPORT_UNAVAILABLE', requestId }, 503); }
  const data = { exportedAt: new Date().toISOString(), profile: rows[0].data, dietLogs: rows[1].data ?? [], exerciseLogs: rows[2].data ?? [], dailyTracking: rows[3].data ?? [], waterRecords: rows[4].data ?? [], weightLogs: rows[5].data ?? [], trainingSessions: rows[6].data ?? [], chatHistory: rows[7].data ?? [], settings: rows[0].data ? { targetKcal: rows[0].data.target_kcal, targetP: rows[0].data.target_p, targetC: rows[0].data.target_c, targetF: rows[0].data.target_f } : {} };
  const encoded = new TextEncoder().encode(JSON.stringify(data)); if (encoded.byteLength > MAX_EXPORT_BYTES) return json({ code: 'EXPORT_TOO_LARGE', requestId }, 413);
  console.info(JSON.stringify({ requestId, result: 'EXPORTED', bytes: encoded.byteLength })); return new Response(encoded, { status: 200, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8', 'Content-Disposition': `attachment; filename="goat-data-${new Date().toISOString().slice(0, 10)}.json"`, 'Cache-Control': 'no-store' } });
});
