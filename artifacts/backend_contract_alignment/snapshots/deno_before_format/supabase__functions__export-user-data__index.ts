import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const MAX_BODY_BYTES = 8 * 1024;
const MAX_EXPORT_BYTES = 5 * 1024 * 1024;
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function defaultKey(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Record<string, unknown>;
    return typeof parsed.default === 'string' && parsed.default ? parsed.default : null;
  } catch {
    return null;
  }
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function isMissingTable(error: { code?: string } | null) {
  return error?.code === '42P01' || error?.code === 'PGRST205';
}

function exportRows(value: unknown): unknown[] {
  if (!Array.isArray(value)) return [];
  return value.map((row) => {
    if (!row || typeof row !== 'object' || Array.isArray(row)) return row;
    const safe = { ...(row as Record<string, unknown>) };
    if ('deleted_at' in safe) {
      safe.deletedAt = safe.deleted_at;
      delete safe.deleted_at;
    }
    delete safe.version;
    delete safe.client_operation_id;
    delete safe.user_id;
    return safe;
  });
}

function exportProfile(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return exportRows([value])[0] as Record<string, unknown>;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (request.method !== 'POST') return json({ code: 'METHOD_NOT_ALLOWED' }, 405);
  const requestId = crypto.randomUUID();
  const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '').trim() ?? '';
  if (!token) return json({ code: 'UNAUTHORIZED', requestId }, 401);
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json({ code: 'REQUEST_TOO_LARGE', requestId }, 413);

  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? defaultKey(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'));
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? defaultKey(Deno.env.get('SUPABASE_SECRET_KEYS'));
  if (!url || !anon || !secret) return json({ code: 'CONFIGURATION_ERROR', requestId }, 500);

  const userClient = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  const userId = authData.user?.id;
  if (authError || !userId) return json({ code: 'UNAUTHORIZED', requestId }, 401);

  const admin = createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
  const rows = await Promise.all([
    admin.from('user_profiles').select('id,gender,birth_year,birth_month,birth_day,height,current_weight,target_kcal,target_p,target_c,target_f,training_data,deleted_at,created_at,updated_at').eq('id', userId).maybeSingle(),
    admin.from('food_dictionary').select('id,name,protein,carbs,fat,calories,category,unit,weight_per_unit,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('diet_logs').select('id,food_name,p,c,f,kcal,meal_type,date,amount,unit,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('exercise_logs').select('id,type,kcal,start_time,end_time,date,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('daily_tracking').select('date,water_ml,weight_kg,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('water_intake_records').select('id,date,recorded_at,amount_ml,is_legacy_aggregate,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('body_weight_logs').select('id,date,weight_kg,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('training_sessions').select('id,name,date,exercises,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('training_templates').select('id,name,exercise_ids,progression_targets,rest_prescriptions,superset_groups,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('ai_memories').select('id,stable_key,category,value,structured_value,source_type,status,source_refs,confidence_level,user_confirmed,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('ai_suggestions').select('id,type,title,summary,reason_codes,evidence_refs,knowledge_refs,proposed_action,data_quality,status,failure_message,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('ai_suggestion_feedback').select('id,suggestion_id,decision,modified_action,reason_code,feedback_type,deleted_at,created_at,updated_at').eq('user_id', userId),
    admin.from('chat_history').select('user_id,messages').eq('user_id', userId),
  ]);
  if (rows.some((result) => result.error && !isMissingTable(result.error))) {
    console.error(JSON.stringify({ requestId, result: 'EXPORT_QUERY_FAILED' }));
    return json({ code: 'EXPORT_UNAVAILABLE', requestId }, 503);
  }

  const profile = exportProfile(rows[0].data);
  const data = {
    exportedAt: new Date().toISOString(),
    profile,
    foodDictionary: exportRows(rows[1].data),
    dietLogs: exportRows(rows[2].data),
    exerciseLogs: exportRows(rows[3].data),
    dailyTracking: exportRows(rows[4].data),
    waterRecords: exportRows(rows[5].data),
    weightLogs: exportRows(rows[6].data),
    trainingSessions: exportRows(rows[7].data),
    trainingTemplates: exportRows(rows[8].data),
    aiProfile: exportRows(rows[9].data).filter((row) =>
      row && typeof row === 'object' && (row as Record<string, unknown>).source_type === 'userProvided'
    ),
    aiMemories: exportRows(rows[9].data),
    aiSuggestions: exportRows(rows[10].data),
    aiFeedback: exportRows(rows[11].data),
    chatHistory: exportRows(rows[12].data),
    settings: profile ? { targetKcal: profile.target_kcal, targetP: profile.target_p, targetC: profile.target_c, targetF: profile.target_f } : {},
  };
  const encoded = new TextEncoder().encode(JSON.stringify(data));
  if (encoded.byteLength > MAX_EXPORT_BYTES) return json({ code: 'EXPORT_TOO_LARGE', requestId }, 413);
  console.info(JSON.stringify({ requestId, result: 'EXPORTED', bytes: encoded.byteLength }));
  return new Response(encoded, {
    status: 200,
    headers: {
      ...CORS,
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Disposition': `attachment; filename="goat-data-${new Date().toISOString().slice(0, 10)}.json"`,
      'Cache-Control': 'no-store',
    },
  });
});
