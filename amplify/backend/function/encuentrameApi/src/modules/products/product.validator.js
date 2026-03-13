'use strict';

const { AppError } = require('../../shared/errors/app-error');

function throwValidation(message) {
  throw new AppError({
    code: 'VALIDATION',
    message,
    statusCode: 400,
  });
}

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
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

function validateStallId(stallId) {
  const value = String(stallId || '').trim();

  if (!value) {
    throwValidation('stallId requerido');
  }

  return value;
}

function validateProductId(productId) {
  const value = String(productId || '').trim();

  if (!value) {
    throwValidation('productId requerido');
  }

  return value;
}

function normalizeRequiredText(value, fieldName, { min = 1, max = 80 } = {}) {
  const text = String(value || '').trim();

  if (!text) {
    throwValidation(`${fieldName} requerido`);
  }

  if (text.length < min) {
    throwValidation(`${fieldName} no válido`);
  }

  if (text.length > max) {
    throwValidation(`${fieldName} demasiado largo`);
  }

  return text;
}

function normalizeOptionalText(value, fieldName, { max = 240 } = {}) {
  const text = String(value || '').trim();

  if (!text) {
    return null;
  }

  if (text.length > max) {
    throwValidation(`${fieldName} demasiado largo`);
  }

  return text;
}

function normalizeOptionalPrice(value) {
  if (value === undefined) {
    return undefined;
  }

  if (value === null || value === '') {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed) || parsed < 0) {
    throwValidation('Precio no válido');
  }

  return Number(parsed);
}

function normalizeOptionalStock(value) {
  if (value === undefined) {
    return undefined;
  }

  if (value === null || value === '') {
    return 0;
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed) || parsed < 0) {
    throwValidation('Stock no válido');
  }

  return Math.round(parsed);
}

function validateCreateProductInput(payload = {}) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throwValidation('Body inválido');
  }

  const display = normalizeRequiredText(payload.display, 'Nombre', {
    min: 2,
    max: 80,
  });

  const category = normalizeOptionalText(payload.category, 'Categoría', {
    max: 40,
  });

  const description = normalizeOptionalText(payload.description, 'Descripción', {
    max: 240,
  });

  const photoKey = normalizeOptionalText(payload.photoKey, 'photoKey', {
    max: 512,
  });

  const price = normalizeOptionalPrice(payload.price);
  const stock = normalizeOptionalStock(
    hasOwn(payload, 'stock') ? payload.stock : payload.lastQty
  );

  return {
    display,
    category,
    description,
    photoKey,
    price: price === undefined ? null : price,
    stock: stock === undefined ? 0 : stock,
    active: hasOwn(payload, 'active') ? !!payload.active : true,
  };
}

function validateUpdateProductInput(payload = {}) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throwValidation('Body inválido');
  }

  const changes = {};

  if (hasOwn(payload, 'display')) {
    changes.display = normalizeRequiredText(payload.display, 'Nombre', {
      min: 2,
      max: 80,
    });
  }

  if (hasOwn(payload, 'category')) {
    changes.category = normalizeOptionalText(payload.category, 'Categoría', {
      max: 40,
    });
  }

  if (hasOwn(payload, 'description')) {
    changes.description = normalizeOptionalText(payload.description, 'Descripción', {
      max: 240,
    });
  }

  if (hasOwn(payload, 'photoKey')) {
    changes.photoKey = normalizeOptionalText(payload.photoKey, 'photoKey', {
      max: 512,
    });
  }

  if (hasOwn(payload, 'price')) {
    changes.price = normalizeOptionalPrice(payload.price);
  }

  if (hasOwn(payload, 'active')) {
    changes.active = !!payload.active;
  }

  if (hasOwn(payload, 'stock') || hasOwn(payload, 'lastQty')) {
    changes.stock = normalizeOptionalStock(
      hasOwn(payload, 'stock') ? payload.stock : payload.lastQty
    );
  }

  if (!Object.keys(changes).length) {
    throwValidation('Nada para actualizar');
  }

  return changes;
}

module.exports = {
  requireAuthenticated,
  validateStallId,
  validateProductId,
  validateCreateProductInput,
  validateUpdateProductInput,
};