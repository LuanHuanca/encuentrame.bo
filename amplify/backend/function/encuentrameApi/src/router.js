/* eslint-disable */
const stalls = require('./handlers/stalls');
const { bad, options } = require('./util/http');

function pathParts(p) {
  return (p || '').split('?')[0].split('/').filter(Boolean);
}

function stripApiPrefix(parts) {
  const i = parts.indexOf('api');
  return i >= 0 ? parts.slice(i + 1) : parts;
}

function getCaller(event) {
  return (
    event.requestContext?.authorizer?.claims ||
    event.requestContext?.authorizer?.jwt?.claims ||
    event.requestContext?.authorizer ||
    null
  );
}

exports.route = async (event) => {
  const method = (event.httpMethod || '').toUpperCase();
  if (method === 'OPTIONS') return options();

  const caller = getCaller(event);
  const parts = stripApiPrefix(pathParts(event.path)); // ej: [ 'stalls', '123', 'current' ]

  // /stalls
  if (parts[0] === 'stalls' && parts.length === 1) {
    if (method === 'GET') return stalls.list({ caller });
    if (method === 'POST') return stalls.create({ event, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/my
  if (parts[0] === 'stalls' && parts[1] === 'my' && parts.length === 2) {
    if (method === 'GET') return stalls.getMy({ caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/open
  if (parts[0] === 'stalls' && parts[1] === 'open' && parts.length === 2) {
    if (method === 'POST') return stalls.open({ event, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}
  if (parts[0] === 'stalls' && parts[1] && parts.length === 2) {
    const stallId = parts[1];
    if (method === 'GET') return stalls.get({ stallId, caller });
    if (method === 'PUT') return stalls.update({ stallId, event, caller });
    if (method === 'DELETE') return stalls.remove({ stallId, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/current
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'current' && parts.length === 3) {
    if (method === 'GET') return stalls.getCurrent({ stallId: parts[1], caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/close
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'close' && parts.length === 3) {
    if (method === 'POST') return stalls.close({ stallId: parts[1], caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  // /stalls/{stallId}/openings
  if (parts[0] === 'stalls' && parts[1] && parts[2] === 'openings' && parts.length === 3) {
    if (method === 'GET') return stalls.listOpenings({ stallId: parts[1], event, caller });
    return bad(405, 'METHOD_NOT_ALLOWED', 'Método no permitido');
  }

  return bad(404, 'NOT_FOUND', 'Ruta no encontrada');
};