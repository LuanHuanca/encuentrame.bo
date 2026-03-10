'use strict';

const config = require('../config');
const { ok, bad, parseJsonBody } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const {
  GetCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
} = require('@aws-sdk/lib-dynamodb');

function pkUser(userId) {
  return `USER#${userId}`;
}

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function skStall(stallId) {
  return `STALL#${stallId}`;
}

function skProd(productId) {
  return `PROD#${productId}`;
}

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9\-]/g, '')
    .slice(0, 64);
}

async function assertOwnsStall(userId, stallId) {
  if (!config.STALLS_TABLE) return false;

  const response = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkUser(userId), sk: skStall(stallId) },
    })
  );

  return !!response.Item;
}

async function list({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) return ok({ products: [] });

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const result = await ddb.send(
    new QueryCommand({
      TableName: config.PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'PROD#',
      },
      ScanIndexForward: true,
    })
  );

  const products = (result.Items || []).map((item) => ({
    productId: item.productId,
    canonical: item.canonical,
    display: item.display,
    category: item.category ?? null,
    description: item.description ?? null,
    price: item.price ?? null,
    active: item.active ?? true,
    lastQty: item.lastQty ?? null,
    lastSeenAt: item.lastSeenAt ?? null,
  }));

  return ok({ products });
}

async function create({ stallId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = parseJsonBody(event);

  const display = String(body.display || '').trim();
  const canonical = String(body.canonical || display)
    .trim()
    .toLowerCase();
  const category = String(body.category || '').trim() || null;
  const description = String(body.description || '').trim() || null;
  const price = body.price != null ? Number(body.price) : null;
  const lastQty = body.lastQty != null ? Number(body.lastQty) : 1;

  if (!display) return bad(400, 'VALIDATION', 'Nombre requerido');

  const productId = slugify(canonical || display);
  if (!productId) return bad(400, 'VALIDATION', 'Producto no válido');

  await ddb.send(
    new UpdateCommand({
      TableName: config.PRODUCTS_TABLE,
      Key: { pk: pkStall(stallId), sk: skProd(productId) },
      UpdateExpression: `
        SET entityType = if_not_exists(entityType, :type),
            productId = if_not_exists(productId, :pid),
            canonical = :canonical,
            #display = :display,
            category = :category,
            description = :description,
            price = :price,
            active = :active,
            lastQty = :lastQty,
            lastSeenAt = :now
      `,
      ExpressionAttributeNames: {
        '#display': 'display',
      },
      ExpressionAttributeValues: {
        ':type': 'PRODUCT',
        ':pid': productId,
        ':canonical': canonical || display.toLowerCase(),
        ':display': display,
        ':category': category,
        ':description': description,
        ':price': Number.isFinite(price) ? price : null,
        ':active': true,
        ':lastQty': Math.max(0, Math.round(lastQty)),
        ':now': new Date().toISOString(),
      },
    })
  );

  return ok({ ok: true, productId });
}

async function update({ stallId, productId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = parseJsonBody(event);

  const display = body.display != null ? String(body.display).trim() : null;
  const category = body.category != null ? String(body.category).trim() : null;
  const description =
    body.description != null ? String(body.description).trim() : null;
  const price = body.price != null ? Number(body.price) : null;
  const active = body.active != null ? !!body.active : null;
  const lastQty = body.lastQty != null ? Number(body.lastQty) : null;

  const sets = [];
  const names = {};
  const values = {};

  if (display !== null && display.length) {
    names['#display'] = 'display';
    values[':display'] = display;
    sets.push('#display = :display');
  }

  if (category !== null) {
    values[':category'] = category || null;
    sets.push('category = :category');
  }

  if (description !== null) {
    values[':description'] = description || null;
    sets.push('description = :description');
  }

  if (price !== null && Number.isFinite(price)) {
    values[':price'] = price;
    sets.push('price = :price');
  }

  if (active !== null) {
    values[':active'] = active;
    sets.push('active = :active');
  }

  if (lastQty !== null && Number.isFinite(lastQty)) {
    values[':lastQty'] = Math.max(0, Math.round(lastQty));
    sets.push('lastQty = :lastQty');
  }

  if (!sets.length) return bad(400, 'VALIDATION', 'Nada para actualizar');

  values[':lastSeenAt'] = new Date().toISOString();
  sets.push('lastSeenAt = :lastSeenAt');

  await ddb.send(
    new UpdateCommand({
      TableName: config.PRODUCTS_TABLE,
      Key: { pk: pkStall(stallId), sk: skProd(productId) },
      UpdateExpression: `SET ${sets.join(', ')}`,
      ExpressionAttributeNames: Object.keys(names).length ? names : undefined,
      ExpressionAttributeValues: values,
      ConditionExpression: 'attribute_exists(pk) AND attribute_exists(sk)',
    })
  );

  return ok({ ok: true });
}

async function remove({ stallId, productId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  await ddb.send(
    new DeleteCommand({
      TableName: config.PRODUCTS_TABLE,
      Key: { pk: pkStall(stallId), sk: skProd(productId) },
    })
  );

  return ok({ ok: true });
}

module.exports = {
  list,
  create,
  update,
  remove,
};