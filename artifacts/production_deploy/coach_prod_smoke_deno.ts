const api = Deno.env.get('PROD_API_URL')!;
const anon = Deno.env.get('PROD_ANON_KEY')!;
const service = Deno.env.get('PROD_SERVICE_ROLE_KEY')!;
const h = (token?: string, admin = false): HeadersInit => {
  const key = admin ? service : anon;
  return { apikey: key, Authorization: `Bearer ${token ?? key}`, 'Content-Type': 'application/json' };
};
async function req(path: string, init: RequestInit = {}, token?: string, admin = false) {
  const response = await fetch(`${api}${path}`, { ...init, headers: { ...h(token, admin), ...(init.headers ?? {}) } });
  return { status: response.status, body: await response.text() };
}
const email = `contract-prod-coach-final-${crypto.randomUUID()}@example.test`;
const password = `Prod-Ff6!-${crypto.randomUUID()}`;
let id = '';
try {
  const created = await req('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, password, email_confirm: true }) }, undefined, true);
  const createdJson = JSON.parse(created.body);
  id = String(createdJson.id);
  const login = await req('/auth/v1/token?grant_type=password', { method: 'POST', body: JSON.stringify({ email, password }) });
  const token = String(JSON.parse(login.body).access_token);
  const response = await req('/functions/v1/coach-ai', { method: 'POST', body: JSON.stringify({
    requestId: `coach-final-${crypto.randomUUID()}`, taskType: 'nutrition_explanation',
    structuredContext: { deterministic: { kcal: 520, protein: 30 } }, activeProfile: { goal: 'strength' },
    activeMemories: [{ category: 'goal', value: 'strength' }], evidenceRefs: ['daily_tracking:final'], knowledgeRefs: ['local:contract'],
  }) }, token);
  const body = JSON.parse(response.body);
  console.log(`COACH_STATUS=${response.status}`);
  console.log(`COACH_RESPONSE_KEYS=${Object.keys(body).sort().join(',')}`);
  const forbidden = /(access[_-]?token|refresh[_-]?token|service[_-]?role|claim[_-]?token|secret|api[_-]?key)/i;
  const contract = response.status === 200 && typeof body.answer === 'string' && typeof body.summary === 'string' &&
    Array.isArray(body.evidenceRefs) && Array.isArray(body.knowledgeRefs) && Array.isArray(body.suggestions) &&
    Array.isArray(body.uncertainties) && typeof body.requestId === 'string' && body.provider === 'deepseek';
  console.log(`COACH_CONTRACT_PASS=${contract}`);
  console.log(`COACH_NO_SECRET_LEAK_PASS=${!forbidden.test(response.body)}`);
  if (!contract || forbidden.test(response.body)) throw new Error('coach production smoke failed');
  console.log('COACH_PRODUCTION_SMOKE_PASS');
} finally {
  if (id) await req(`/auth/v1/admin/users/${id}`, { method: 'DELETE' }, undefined, true);
}
