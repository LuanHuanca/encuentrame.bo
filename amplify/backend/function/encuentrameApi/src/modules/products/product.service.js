'use strict';

const { env } = require('../../shared/config/env');
const { AppError } = require('../../shared/errors/app-error');
const repository = require('./product.repository');
const mapper = require('./product.mapper');
const {
  requireAuthenticated,
  validateStallId,
  validateProductId,
  validateUpdateProductInput,
} = require('./product.validator');

function ensureProductsEnv() {
  if (!env.PRODUCTS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta PRODUCTS_TABLE',
      statusCode: 500,
    });
  }
}

function ensureStallsEnv() {
  if (!env.STALLS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta STALLS_TABLE',
      statusCode: 500,
    });
  }
}

async function assertOwnsStall(userId, stallId) {
  const owns = await repository.userOwnsStall(userId, stallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }
}

async function list(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  await assertOwnsStall(currentUser.userId, validStallId);

  const items = await repository.listByStallId(validStallId);

  const products = items.map((item) => mapper.toProductResponse(item));

  return mapper.toListResponse(products);
}

async function update(currentUser, stallId, productId, payload) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const validProductId = validateProductId(productId);

  await assertOwnsStall(currentUser.userId, validStallId);

  const changes = validateUpdateProductInput(payload);

  let updated;
  try {
    updated = await repository.updateProduct({
      stallId: validStallId,
      productId: validProductId,
      changes,
    });
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') {
      throw new AppError({
        code: 'NOT_FOUND',
        message: 'Producto no encontrado',
        statusCode: 404,
      });
    }
    throw error;
  }

  return {
    ok: true,
    product: mapper.toProductResponse(updated),
  };
}

async function remove(currentUser, stallId, productId) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const validProductId = validateProductId(productId);

  await assertOwnsStall(currentUser.userId, validStallId);

  await repository.deleteProduct(validStallId, validProductId);

  return mapper.toSimpleOk();
}

module.exports = {
  list,
  update,
  remove,
};