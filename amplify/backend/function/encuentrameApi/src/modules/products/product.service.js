'use strict';

const crypto = require('crypto');
const { env } = require('../../shared/config/env');
const { AppError } = require('../../shared/errors/app-error');
const repository = require('./product.repository');
const mapper = require('./product.mapper');
const {
  requireAuthenticated,
  validateStallId,
  validateProductId,
  validateCreateProductInput,
  validateUpdateProductInput,
} = require('./product.validator');

function nowIso() {
  return new Date().toISOString();
}

function uuid() {
  return crypto.randomUUID
    ? crypto.randomUUID()
    : crypto.randomBytes(16).toString('hex');
}

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

function buildCanonical(value) {
  return String(value || '')
    .toLowerCase()
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildProductItem({ stallId, productId, input, now }) {
  const item = {
    pk: `STALL#${stallId}`,
    sk: `PROD#${productId}`,
    entityType: 'PRODUCT',
    stallId,
    productId,
    canonical: buildCanonical(input.display),
    display: input.display,
    active: input.active,
    lastQty: input.stock,
    createdAt: now,
    updatedAt: now,
    lastSeenAt: now,
  };

  if (input.category) {
    item.category = input.category;
  }

  if (input.description) {
    item.description = input.description;
  }

  if (input.photoKey) {
    item.photoKey = input.photoKey;
  }

  if (input.price !== null) {
    item.price = input.price;
  }

  return item;
}

async function create(currentUser, stallId, payload) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  await assertOwnsStall(currentUser.userId, validStallId);

  const input = validateCreateProductInput(payload);
  const now = nowIso();
  const productId = `prod_${uuid()}`;

  const item = buildProductItem({
    stallId: validStallId,
    productId,
    input,
    now,
  });

  await repository.createProduct(item);

  return mapper.toCreateResponse(mapper.toProductResponse(item));
}

async function list(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  await assertOwnsStall(currentUser.userId, validStallId);

  const items = await repository.listByStallId(validStallId);

  const products = items
    .map((item) => mapper.toProductResponse(item))
    .sort((a, b) => {
      if (a.active !== b.active) {
        return a.active ? -1 : 1;
      }

      return String(a.display || '').localeCompare(String(b.display || ''));
    });

  return mapper.toListResponse(products);
}

async function update(currentUser, stallId, productId, payload) {
  requireAuthenticated(currentUser);
  ensureProductsEnv();
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const validProductId = validateProductId(productId);

  await assertOwnsStall(currentUser.userId, validStallId);

  const input = validateUpdateProductInput(payload);
  const now = nowIso();

  const changes = {
    updatedAt: now,
  };

  if ('display' in input) {
    changes.display = input.display;
    changes.canonical = buildCanonical(input.display);
  }

  if ('category' in input) {
    changes.category = input.category;
  }

  if ('description' in input) {
    changes.description = input.description;
  }

  if ('photoKey' in input) {
    changes.photoKey = input.photoKey;
  }

  if ('price' in input) {
    changes.price = input.price;
  }

  if ('active' in input) {
    changes.active = input.active;
  }

  if ('stock' in input) {
    changes.lastQty = input.stock;
    changes.lastSeenAt = now;
  }

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

  return mapper.toUpdateResponse(mapper.toProductResponse(updated));
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
  create,
  list,
  update,
  remove,
};