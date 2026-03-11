'use strict';

const { AppError } = require('../errors/app-error');
const { env } = require('../config/env');

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Content-Type': 'application/json; charset=utf-8',
  };
}

function json(statusCode, payload) {
  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify(payload),
  };
}

function ok(payload = {}) {
  return json(200, payload);
}

function created(payload = {}) {
  return json(201, payload);
}

function options() {
  return {
    statusCode: 204,
    headers: corsHeaders(),
    body: '',
  };
}

function notFound() {
  return json(404, {
    error: {
      code: 'NOT_FOUND',
      message: 'Ruta no encontrada',
    },
  });
}

function methodNotAllowed() {
  return json(405, {
    error: {
      code: 'METHOD_NOT_ALLOWED',
      message: 'Método no permitido',
    },
  });
}

function parseJsonBody(event) {
  if (!event?.body) return {};

  try {
    const raw = event.isBase64Encoded
      ? Buffer.from(event.body, 'base64').toString('utf8')
      : event.body;

    return JSON.parse(raw);
  } catch (_) {
    return {};
  }
}

function toErrorResponse(error) {
  const appError =
    error instanceof AppError
      ? error
      : new AppError({
          code: 'INTERNAL',
          message: 'Error interno',
          statusCode: 500,
          details:
            env.ENV === 'dev'
              ? String(error?.message || 'Unknown error')
              : undefined,
        });

  return json(appError.statusCode, {
    error: {
      code: appError.code,
      message: appError.message,
      ...(appError.details !== undefined ? { details: appError.details } : {}),
    },
  });
}

module.exports = {
  corsHeaders,
  json,
  ok,
  created,
  options,
  notFound,
  methodNotAllowed,
  parseJsonBody,
  toErrorResponse,
};