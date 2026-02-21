/* eslint-disable */
const { corsHeaders, ok, bad } = require('./util/http');
const { getCaller } = require('./util/auth');

const users = require('./routes/users');

async function route(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders(), body: '' };
  }

  const method = event.httpMethod;
  let path = event.path || '/';
  if (path.startsWith('/api/')) path = path.substring(4);
  if (path === '/api') path = '/';
  const caller = getCaller(event);

  if (method === 'GET' && path === '/health') return ok({ ok: true });

  // Users profile + role
  if (path === '/users/me' && method === 'GET') return users.getMe({ caller });
  if (path === '/users/me' && method === 'PUT') return users.putMe({ event, caller });

  return bad(404, 'NOT_FOUND', `Ruta no existe: ${method} ${path}`);
}

module.exports = { route };