/* eslint-disable */
const stalls = require('./routes/stalls');
const users = require('./routes/users');
const products = require('./routes/products');
const { ok, bad, options } = require('./util/http');

function pathParts(p) {
  return (p || '').split('?')[0].split('/').filter(Boolean);
}

function stripApiPrefix(parts) {
  const i = parts.indexOf('api');
  return i >= 0 ? parts.slice(i + 1) : parts;
}

// Soporta Cognito User Pools (claims) y AWS_IAM (identity)
function getCaller(event) {
  const claims =
    event.requestContext?.authorizer?.claims ||
    event.requestContext?.authorizer?.jwt?.claims ||
    null;

  const identity = event.requestContext?.identity || null;

  if (claims) return { ...claims, _identity: identity };
  if (event.requestContext?.authorizer) return { ...event.requestContext.authorizer, _identity: identity };
  if (identity) return identity;

  return null;
}

async function route(event) {
  const method = (event.httpMethod || '').toUpperCase();
  if (method === 'OPTIONS') return options();

  const caller = getCaller(event);
  const parts = stripApiPrefix(pathParts(event.path));

  // /health
  if (parts[0] === 'health' && parts.length === 1) {
    if (method === 'GET') return ok({ ok: true, env: process.env.ENV || 'dev' });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /users/me
  if (parts[0] === 'users' && parts[1] === 'me' && parts.length === 2) {
    if (method === 'GET') return users.me({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls
  if (parts[0] === 'stalls' && parts.length === 1) {
    if (method === 'GET') return stalls.list({ caller, event });
    if (method === 'POST') return stalls.create({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/my
  if (parts[0] === 'stalls' && parts[1] === 'my' && parts.length === 2) {
    if (method === 'GET') return stalls.getMy({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/open
  if (parts[0] === 'stalls' && parts[1] === 'open' && parts.length === 2) {
    if (method === 'POST') return stalls.open({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/products
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'products' && parts.length === 3) {
    if (method === 'GET') return products.list({ stallId: parts[1], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/products/{productId}
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'products' && parts[3] && parts.length === 4) {
    if (method === 'PUT') return products.update({ stallId: parts[1], productId: parts[3], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}
  if (parts[0] === 'stalls' && parts[1] && parts.length === 2) {
    const stallId = parts[1];
    if (method === 'GET') return stalls.get({ stallId, caller, event });
    if (method === 'PUT') return stalls.update({ stallId, caller, event });
    if (method === 'DELETE') return stalls.remove({ stallId, caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/current
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'current' && parts.length === 3) {
    if (method === 'GET') return stalls.getCurrent({ stallId: parts[1], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/close
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'close' && parts.length === 3) {
    if (method === 'POST') return stalls.close({ stallId: parts[1], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/openings
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'openings' && parts.length === 3) {
    if (method === 'GET') return stalls.listOpenings({ stallId: parts[1], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  return bad(404, 'NOT_FOUND', 'Ruta no encontrada');
}

module.exports = { route };