'use strict';

const { AppError } = require('../../shared/errors/app-error');

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function requireAuthenticated(currentUser) {
  if (!currentUser?.userId) {
    throw new AppError({
      code: 'UNAUTHORIZED',
      message: 'No autenticado',
      statusCode: 401,
    });
  }
}

function validateNearbyQuery(query = {}) {
  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);

  if (lat === null || lng === null) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'lat y lng son requeridos',
      statusCode: 400,
    });
  }

  return {
    lat,
    lng,
    radiusKm: clamp(toNumber(query.radiusKm) ?? 10, 0.1, 50),
    limit: clamp(toNumber(query.limit) ?? 100, 1, 300),
    includeProducts: String(query.includeProducts || '0') === '1',
    productsLimit: clamp(toNumber(query.productsLimit) ?? 6, 1, 20),
    category: String(query.category || '').trim(),
    q: String(query.q || '').trim(),
  };
}

function validateSearchProductsQuery(query = {}) {
  const parsed = validateNearbyQuery(query);
  const q = String(query.q || '').trim();

  if (!q) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'q es requerido',
      statusCode: 400,
    });
  }

  return {
    ...parsed,
    q,
  };
}

function validateStallId(stallId) {
  const value = String(stallId || '').trim();

  if (!value) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'stallId requerido',
      statusCode: 400,
    });
  }

  return value;
}

module.exports = {
  requireAuthenticated,
  validateNearbyQuery,
  validateSearchProductsQuery,
  validateStallId,
};