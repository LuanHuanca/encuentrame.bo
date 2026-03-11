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

function validateProductId(productId) {
  const value = String(productId || '').trim();

  if (!value) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'productId requerido',
      statusCode: 400,
    });
  }

  return value;
}

function validateUpdateProductInput(payload = {}) {
  const output = {};

  if (payload.display !== undefined) {
    const display = String(payload.display || '').trim();

    if (!display) {
      throw new AppError({
        code: 'VALIDATION',
        message: 'Nombre visible no válido',
        statusCode: 400,
      });
    }

    if (display.length > 80) {
      throw new AppError({
        code: 'VALIDATION',
        message: 'Máximo 80 caracteres para el nombre',
        statusCode: 400,
      });
    }

    output.display = display;
  }

  if (payload.price !== undefined && payload.price !== null && payload.price !== '') {
    const price = Number(payload.price);

    if (!Number.isFinite(price) || price < 0) {
      throw new AppError({
        code: 'VALIDATION',
        message: 'Precio no válido',
        statusCode: 400,
      });
    }

    output.price = Number(price);
  }

  if (payload.active !== undefined) {
    output.active = !!payload.active;
  }

  if (payload.lastQty !== undefined && payload.lastQty !== null && payload.lastQty !== '') {
    const qty = Number(payload.lastQty);

    if (!Number.isFinite(qty) || qty < 0) {
      throw new AppError({
        code: 'VALIDATION',
        message: 'Cantidad no válida',
        statusCode: 400,
      });
    }

    output.lastQty = Math.round(qty);
  }

  if (!Object.keys(output).length) {
    throw new AppError({
      code: 'VALIDATION',
      message: 'Nada para actualizar',
      statusCode: 400,
    });
  }

  return output;
}

module.exports = {
  requireAuthenticated,
  validateStallId,
  validateProductId,
  validateUpdateProductInput,
};