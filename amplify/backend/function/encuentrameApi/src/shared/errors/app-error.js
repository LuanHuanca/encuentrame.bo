'use strict';

class AppError extends Error {
  constructor({
    code = 'INTERNAL',
    message = 'Error interno',
    statusCode = 500,
    details = undefined,
  }) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

module.exports = {
  AppError,
};