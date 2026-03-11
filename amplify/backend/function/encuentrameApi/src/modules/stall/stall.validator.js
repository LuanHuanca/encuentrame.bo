'use strict';

const { AppError } = require('../../shared/errors/app-error');

function requireAuthenticated(currentUser) {
  if (!currentUser?.userId) {
    throw new AppError({
      code: 'UNAUTHORIZED',
      message: 'No autenticado',
      statusCode: 401,
    });
  }
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

function validateCreateStallInput(payload = {}) {
  const name = String(payload.name || '').trim();
  const category = String(payload.category || '').trim();
  const description = String(payload.description || '').trim();
  const coverPhotoKey = String(payload.coverPhotoKey || '').trim();

  if (!name) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Nombre requerido',
      statusCode: 400,
    });
  }

  if (name.length < 2) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Nombre no válido',
      statusCode: 400,
    });
  }

  if (name.length > 60) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Máximo 60 caracteres',
      statusCode: 400,
    });
  }

  if (category.length > 40) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Categoría demasiado larga',
      statusCode: 400,
    });
  }

  if (description.length > 240) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Descripción demasiado larga',
      statusCode: 400,
    });
  }

  return {
    name,
    category,
    description,
    coverPhotoKey,
  };
}

function validateUpdateStallInput(payload = {}) {
  return validateCreateStallInput(payload);
}

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function validateOpenStallInput(payload = {}) {
  const stallId = validateStallId(payload.stallId);
  const lat = toNumber(payload.lat);
  const lng = toNumber(payload.lng);
  const accuracy = toNumber(payload.accuracy || 0) ?? 0;

  const stallPhotoKey = String(payload.stallPhotoKey || '').trim();
  const productsPhotoKey = String(payload.productsPhotoKey || '').trim();
  const inventoryText = String(payload.inventoryText || '').trim();
  const stallName = String(payload.stallName || '').trim();

  if (lat === null || lng === null) {
    throw new AppError({
      code: 'MISSING_LOCATION',
      message: 'Falta ubicación',
      statusCode: 400,
    });
  }

  if (!stallPhotoKey || !productsPhotoKey) {
    throw new AppError({
      code: 'MISSING_PHOTOS',
      message: 'Faltan fotos',
      statusCode: 400,
    });
  }

  if (!inventoryText) {
    throw new AppError({
      code: 'MISSING_INVENTORY',
      message: 'Falta inventario',
      statusCode: 400,
    });
  }

  return {
    stallId,
    stallName,
    lat,
    lng,
    accuracy,
    stallPhotoKey,
    productsPhotoKey,
    inventoryText,
  };
}

function validateListOpeningsQuery(query = {}) {
  const raw = Number(query.limit || 20);
  const limit = Number.isFinite(raw) ? Math.max(1, Math.min(raw, 50)) : 20;
  return { limit };
}

module.exports = {
  requireAuthenticated,
  validateStallId,
  validateCreateStallInput,
  validateUpdateStallInput,
  validateOpenStallInput,
  validateListOpeningsQuery,
};