'use strict';

const config = require('../config');
const { ok, bad, parseJsonBody } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const { GetCommand, QueryCommand, UpdateCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');

function pkUser(userId) { return `USER#${userId}`; }
function pkStall(stallId) { return `STALL#${stallId}`; }
function skStall(stallId) { return `STALL#${stallId}`; }
function skProd(productId) { return `PROD#${productId}`; }

async function assertOwnsStall(userId, stallId) {
  if (!config.STALLS_TABLE) return false;
  const res = await ddb.send(new GetCommand({
    TableName: config.STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) }
  }));
  return !!res.Item;
}

async function list({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) return ok({ products: [] });

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const q = await ddb.send(new QueryCommand({
    TableName: config.PRODUCTS_TABLE,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
    ExpressionAttributeValues: {
      ':pk': pkStall(stallId),
      ':pfx': 'PROD#'
    },
    ScanIndexForward: true
  }));

  const products = (q.Items || []).map(x => ({
    productId: x.productId,
    canonical: x.canonical,
    display: x.display,
    category: x.category ?? null,
    price: x.price ?? null,
    active: x.active ?? true,
    lastQty: x.lastQty ?? null,
    lastSeenAt: x.lastSeenAt ?? null
  }));

  return ok({ products });
}

async function update({ stallId, productId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = parseJsonBody(event);

  const display = body.display != null ? String(body.display).trim() : null;
  const price = body.price != null ? Number(body.price) : null;
  const active = body.active != null ? !!body.active : null;
  const lastQty = body.lastQty != null ? Number(body.lastQty) : null;

  const sets = [];
  const names = {};
  const values = {};

  if (display !== null && display.length) {
    names['#display'] = 'display';
    values[':display'] = display;
    sets.push('#display=:display');
  }
  if (price !== null && Number.isFinite(price)) {
    names['#price'] = 'price';
    values[':price'] = price;
    sets.push('#price=:price');
  }
  if (active !== null) {
    names['#active'] = 'active';
    values[':active'] = active;
    sets.push('#active=:active');
  }
  if (lastQty !== null && Number.isFinite(lastQty)) {
    names['#lastQty'] = 'lastQty';
    values[':lastQty'] = Math.max(0, Math.round(lastQty));
    sets.push('#lastQty=:lastQty');
  }

  if (!sets.length) return bad(400, 'VALIDATION', 'Nada para actualizar');

  await ddb.send(new UpdateCommand({
    TableName: config.PRODUCTS_TABLE,
    Key: { pk: pkStall(stallId), sk: skProd(productId) },
    UpdateExpression: `SET ${sets.join(', ')}`,
    ExpressionAttributeNames: names,
    ExpressionAttributeValues: values,
    ConditionExpression: 'attribute_exists(pk) AND attribute_exists(sk)'
  }));

  return ok({ ok: true });
}

async function remove({ stallId, productId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.PRODUCTS_TABLE) return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  await ddb.send(new DeleteCommand({
    TableName: config.PRODUCTS_TABLE,
    Key: { pk: pkStall(stallId), sk: skProd(productId) }
  }));

  return ok({ ok: true });
}

module.exports = { list, update, remove };