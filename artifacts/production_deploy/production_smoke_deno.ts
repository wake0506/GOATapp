const api = Deno.env.get('PROD_API_URL')!;
const anon = Deno.env.get('PROD_ANON_KEY')!;
const service = Deno.env.get('PROD_SERVICE_ROLE_KEY')!;
if (!api || !anon || !service) throw new Error('missing production API configuration');

const suffix = crypto.randomUUID();
const users: string[] = [];
const credentials: Array<{ email: string; password: string }> = [];

function headers(token?: string, admin = false): HeadersInit {
  const key = admin ? service : anon;
  return {
    apikey: key,
    Authorization: `Bearer ${token ?? key}`,
    'Content-Type': 'application/json',
  };
}

async function request(path: string, init: RequestInit = {}, token?: string, admin = false) {
  const response = await fetch(`${api}${path}`, {
    ...init,
    headers: { ...headers(token, admin), ...(init.headers ?? {}) },
  });
  const body = await response.text();
  return { status: response.status, body, headers: response.headers };
}

function json(value: unknown) {
  return JSON.stringify(value);
}

function check(name: string, value: boolean) {
  if (!value) throw new Error(`FAIL: ${name}`);
  console.log(`PASS: ${name}`);
}

function parsed(body: string): any {
  try { return JSON.parse(body); } catch { return null; }
}

async function createUser(label: string) {
  const email = `contract-prod-${label}-${suffix}@example.test`;
  const password = `Prod-Aa9!-${crypto.randomUUID()}`;
  credentials.push({ email, password });
  const response = await request('/auth/v1/admin/users', {
    method: 'POST',
    body: json({ email, password, email_confirm: true }),
  }, undefined, true);
  check(`create disposable ${label} account`, response.status === 200 || response.status === 201);
  const user = parsed(response.body);
  check(`created ${label} account has id`, Boolean(user?.id));
  users.push(String(user.id));
  return { id: String(user.id), email, password };
}

async function login(user: { email: string; password: string }) {
  const response = await request('/auth/v1/token?grant_type=password', {
    method: 'POST',
    body: json({ email: user.email, password: user.password }),
  });
  check('disposable account login succeeds', response.status === 200);
  const token = parsed(response.body)?.access_token;
  check('login returns JWT', Boolean(token));
  return String(token);
}

async function rest(path: string, method: string, token: string, body?: unknown) {
  return request(`/rest/v1/${path}`, {
    method,
    headers: { Prefer: 'return=representation' },
    body: body === undefined ? undefined : json(body),
  }, token);
}

try {
  const user1 = await createUser('primary');
  const user2 = await createUser('delete');
  const token1 = await login(user1);
  const token2 = await login(user2);

  const profile = await rest('user_profiles', 'POST', token1, {
    id: user1.id, gender: 'male', birth_year: 2000, birth_month: 1,
    birth_day: 2, height: 178, current_weight: 72, target_kcal: 2200,
    target_p: 160, target_c: 240, target_f: 65, training_data: [],
    client_operation_id: `prod-profile-${suffix}`,
  });
  check('authenticated profile write succeeds', profile.status === 201);

  const sessionId = `prod-session-${suffix}`;
  const training = await rest('training_sessions', 'POST', token1, {
    user_id: user1.id, id: sessionId, name: 'Production smoke session',
    date: new Date().toISOString().slice(0, 10), exercises: [{ id: 'bench', sets: [
      { weight: '82.5', reps: '6', completed: true, rpe: 8 },
      { weight: 'bad-history', reps: '', completed: false },
    ] }], client_operation_id: `prod-training-${suffix}`,
  });
  check('authenticated training write succeeds', training.status === 201);

  const own = await rest(`training_sessions?user_id=eq.${user1.id}&id=eq.${sessionId}`, 'GET', token1);
  check('user can read own training data', own.status === 200 && (parsed(own.body) ?? []).length === 1);
  const cross = await rest(`training_sessions?user_id=eq.${user1.id}&id=eq.${sessionId}`, 'GET', token2);
  check('cross-user training read is isolated', cross.status === 200 && (parsed(cross.body) ?? []).length === 0);

  const exportNoJwt = await request('/functions/v1/export-user-data', { method: 'POST', body: '{}' });
  check('export rejects missing JWT', exportNoJwt.status === 401);
  const exportResponse = await request('/functions/v1/export-user-data', { method: 'POST', body: '{}' }, token1);
  const exportBody = exportResponse.body;
  check('authenticated export succeeds', exportResponse.status === 200);
  check('export is no-store', (exportResponse.headers.get('cache-control') ?? '').toLowerCase().includes('no-store'));
  check('export contains current user id', exportBody.includes(user1.id));
  check('export excludes forbidden secrets and internals', !/(access[_-]?token|refresh[_-]?token|service[_-]?role|claim[_-]?token|client_operation_id|secret|api[_-]?key|"version")/i.test(exportBody));
  check('export excludes other user id', !exportBody.includes(user2.id));

  const nutritionOptions = await request('/functions/v1/nutrition-ai', { method: 'OPTIONS' });
  check('nutrition OPTIONS succeeds', nutritionOptions.status === 204);
  const nutrition = await request('/functions/v1/nutrition-ai', {
    method: 'POST',
    body: json({ text: 'rice and eggs', defaultMealType: '早餐', clientRequestId: `prod-nutrition-${suffix}` }),
  }, token1);
  const nutritionJson = parsed(nutrition.body);
  check('nutrition-ai valid request returns HTTP 200', nutrition.status === 200 && Array.isArray(nutritionJson?.items));

  const coach = await request('/functions/v1/coach-ai', {
    method: 'POST',
    body: json({ requestId: `prod-coach-${suffix}`, taskType: 'nutrition_explanation',
      structuredContext: { deterministic: { kcal: 520, protein: 30 } },
      activeProfile: { goal: 'strength' }, activeMemories: [{ category: 'goal', value: 'strength' }],
      evidenceRefs: ['daily_tracking:production-smoke'], knowledgeRefs: ['local:contract'] }),
  }, token1);
  const coachJson = parsed(coach.body);
  console.log(`COACH_STATUS=${coach.status}`);
  if (coachJson && typeof coachJson === 'object') {
    console.log(`COACH_RESPONSE_KEYS=${Object.keys(coachJson).sort().join(',')}`);
    if (typeof coachJson.code === 'string') console.log(`COACH_ERROR_CODE=${coachJson.code}`);
  }
  check('coach-ai valid request returns HTTP 200', coach.status === 200 && typeof coachJson?.answer === 'string');

  const deleted = await request('/functions/v1/delete-account', {
    method: 'POST', body: json({ confirmPhrase: 'DELETE MY ACCOUNT' }),
  }, token2);
  check('delete-account removes disposable account', deleted.status === 204);
  users.splice(users.indexOf(user2.id), 1);
  const deletedLogin = await request('/auth/v1/token?grant_type=password', {
    method: 'POST', body: json({ email: user2.email, password: user2.password }),
  });
  check('deleted account cannot log in', deletedLogin.status === 400 || deletedLogin.status === 401);
  const cascade = await request(`/rest/v1/training_sessions?user_id=eq.${user2.id}`, { method: 'GET' }, undefined, true);
  check('deleted account has no remaining training rows', cascade.status === 200 && (parsed(cascade.body) ?? []).length === 0);
  const primaryLogin = await login(user1);
  check('unrelated disposable account remains valid', Boolean(primaryLogin));
  console.log('PRODUCTION_SMOKE_PASS');
} finally {
  for (const userId of users) {
    await request(`/auth/v1/admin/users/${userId}`, { method: 'DELETE' }, undefined, true);
  }
}
