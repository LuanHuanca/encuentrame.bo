'use strict';

const stalls = require('./routes/stalls');
const users = require('./routes/users');
const products = require('./routes/products');
const market = require('./routes/market');
const { bad, options, ok } = require('./util/http');
const { getCaller } = require('./util/auth');

function pathParts(path) {
  return (path || '')
    .split('?')[0]
    .split('/')
    .filter(Boolean);
}

function stripApiPrefix(parts) {
  const apiIndex = parts.indexOf('api');
  return apiIndex >= 0 ? parts.slice(apiIndex + 1) : parts;
}

async function route(event) {
  const method = (event.httpMethod || '').toUpperCase();
  if (method === 'OPTIONS') return options();

  const caller = getCaller(event);
  const parts = stripApiPrefix(pathParts(event.path));

  if (parts[0] === 'health' && parts.length === 1) {
    if (method === 'GET') {
      return ok({ ok: true, env: process.env.ENV || 'dev' });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'users' && parts[1] === 'me' && parts.length === 2) {
    if (method === 'GET') return users.me({ caller, event });
    if (method === 'PUT') return users.updateMe({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'market' && parts[1] === 'categories' && parts.length === 2) {
    if (method === 'GET') return market.listCategories({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'open-stalls' &&
    parts.length === 2
  ) {
    if (method === 'GET') return market.listOpenStallsNear({ event, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'market' && parts[1] === 'stalls' && parts[2] && parts.length === 3) {
    if (method === 'GET') {
      return market.getStallPublicDetail({
        stallId: parts[2],
        event,
        caller,
      });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'products' &&
    parts[2] === 'search' &&
    parts.length === 3
  ) {
    if (method === 'GET') return market.searchProductsNear({ event, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'stalls' &&
    parts[2] &&
    parts[3] === 'products' &&
    parts.length === 4
  ) {
    if (method === 'GET') {
      return market.listStallProductsPublic({
        stallId: parts[2],
        event,
        caller,
      });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'stalls' && parts.length === 1) {
    if (method === 'GET') return stalls.list({ caller, event });
    if (method === 'POST') return stalls.create({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'stalls' && parts[1] === 'my' && parts.length === 2) {
    if (method === 'GET') return stalls.getMy({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'stalls' && parts[1] === 'open' && parts.length === 2) {
    if (method === 'POST') return stalls.open({ caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'products' &&
    parts.length === 3
  ) {
    if (method === 'GET') return products.list({ stallId: parts[1], caller, event });
    if (method === 'POST') return products.create({ stallId: parts[1], caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'products' &&
    parts[3] &&
    parts.length === 4
  ) {
    if (method === 'PUT') {
      return products.update({
        stallId: parts[1],
        productId: parts[3],
        caller,
        event,
      });
    }

    if (method === 'DELETE') {
      return products.remove({
        stallId: parts[1],
        productId: parts[3],
        caller,
      });
    }

    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (parts[0] === 'stalls' && parts[1] && parts.length === 2) {
    const stallId = parts[1];
    if (method === 'GET') return stalls.get({ stallId, caller, event });
    if (method === 'PUT') return stalls.update({ stallId, caller, event });
    if (method === 'DELETE') return stalls.remove({ stallId, caller, event });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'current' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return stalls.getCurrent({ stallId: parts[1], caller, event });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'close' &&
    parts.length === 3
  ) {
    if (method === 'POST') {
      return stalls.close({ stallId: parts[1], caller, event });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'openings' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return stalls.listOpenings({ stallId: parts[1], caller, event });
    }
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  return bad(404, 'NOT_FOUND', 'Ruta no encontrada');
}

module.exports = { route };