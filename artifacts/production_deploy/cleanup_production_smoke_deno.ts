const api = Deno.env.get('PROD_API_URL')!;
const service = Deno.env.get('PROD_SERVICE_ROLE_KEY')!;
const h = { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' };
const list = await fetch(`${api}/auth/v1/admin/users?page=1&per_page=1000`, { headers: h });
const data = await list.json() as { users?: Array<{ id: string; email?: string }> };
const candidates = (data.users ?? []).filter((u) => (u.email ?? '').startsWith('contract-prod-') && (u.email ?? '').endsWith('@example.test'));
console.log(`DISPOSABLE_USERS_FOUND=${candidates.length}`);
let deleted = 0;
for (const user of candidates) {
  const response = await fetch(`${api}/auth/v1/admin/users/${user.id}`, { method: 'DELETE', headers: h });
  if (response.status === 200 || response.status === 204 || response.status === 404) deleted++;
}
console.log(`DISPOSABLE_USERS_CLEANED=${deleted}`);
const verify = await fetch(`${api}/auth/v1/admin/users?page=1&per_page=1000`, { headers: h });
const after = await verify.json() as { users?: Array<{ email?: string }> };
const remaining = (after.users ?? []).filter((u) => (u.email ?? '').startsWith('contract-prod-') && (u.email ?? '').endsWith('@example.test')).length;
console.log(`DISPOSABLE_USERS_REMAINING=${remaining}`);
if (remaining !== 0) throw new Error('disposable account cleanup incomplete');
