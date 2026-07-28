const api = Deno.env.get('PROD_API_URL')!;
const anon = Deno.env.get('PROD_ANON_KEY')!;
const service = Deno.env.get('PROD_SERVICE_ROLE_KEY')!;
const headers = (token?: string, admin = false): HeadersInit => {
  const key = admin ? service : anon;
  return { apikey: key, Authorization: `Bearer ${token ?? key}`, 'Content-Type': 'application/json' };
};
async function req(path: string, init: RequestInit = {}, token?: string, admin = false) {
  const r = await fetch(`${api}${path}`, { ...init, headers: { ...headers(token, admin), ...(init.headers ?? {}) } });
  return { status: r.status, body: await r.text() };
}
const email = `contract-prod-coach-diag-${crypto.randomUUID()}@example.test`;
const password = `Prod-Dd8!-${crypto.randomUUID()}`;
let userId = '';
try {
  const created = await req('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, password, email_confirm: true }) }, undefined, true);
  const createdJson = JSON.parse(created.body);
  userId = String(createdJson.id);
  const login = await req('/auth/v1/token?grant_type=password', { method: 'POST', body: JSON.stringify({ email, password }) });
  const token = String(JSON.parse(login.body).access_token);
  const coach = await req('/functions/v1/coach-ai', { method: 'POST', body: JSON.stringify({
    requestId: `coach-diag-${crypto.randomUUID()}`, taskType: 'nutrition_explanation',
    structuredContext: { deterministic: { kcal: 520, protein: 30 } }, activeProfile: { goal: 'strength' },
    activeMemories: [{ category: 'goal', value: 'strength' }], evidenceRefs: ['daily_tracking:diag'], knowledgeRefs: ['local:contract'],
  }) }, token);
  console.log(`COACH_STATUS=${coach.status}`);
  try {
    const body = JSON.parse(coach.body);
    console.log(`COACH_RESPONSE_KEYS=${Object.keys(body).sort().join(',')}`);
    if (typeof body.code === 'string') console.log(`COACH_ERROR_CODE=${body.code}`);
  } catch { console.log('COACH_RESPONSE_KEYS=UNPARSEABLE'); }
} finally {
  if (userId) await req(`/auth/v1/admin/users/${userId}`, { method: 'DELETE' }, undefined, true);
}
