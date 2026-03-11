'use strict';

const { AppError } = require('../../shared/errors/app-error');

function validateUpdateProfileInput(input) {
  const name = String(input?.name || '').trim();

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

  return {
    name,
  };
}

module.exports = {
  validateUpdateProfileInput,
};