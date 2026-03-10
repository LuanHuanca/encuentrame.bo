'use strict';

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Content-Type': 'application/json; charset=utf-8',
  };
}

function response(statusCode, payload) {
  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify(payload),
  };
}

function ok(payload = {}) {
  return response(200, payload);
}

function created(payload = {}) {
  return response(201, payload);
}

function bad(statusCode, code, message, details = undefined) {
  return response(statusCode, {
    error: {
      code,
      message,
      ...(details !== undefined ? { details } : {}),
    },
  });
}

function options() {
  return {
    statusCode: 204,
    headers: corsHeaders(),
    body: '',
  };
}

function parseJsonBody(event) {
  if (!event?.body) return {};

  try {
    if (event.isBase64Encoded) {
      const decoded = Buffer.from(event.body, 'base64').toString('utf8');
      return JSON.parse(decoded);
    }

    return JSON.parse(event.body);
  } catch {
    return {};
  }
}

module.exports = {
  corsHeaders,
  response,
  ok,
  created,
  bad,
  options,
  parseJsonBody,
};