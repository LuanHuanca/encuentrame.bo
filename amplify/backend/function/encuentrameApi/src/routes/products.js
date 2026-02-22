/* eslint-disable */
const { ok, bad } = require('../util/http');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  QueryCommand,
  UpdateCommand,
  GetCommand
} = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const STALLS_TABLE = process.env.STALLS_TABLE;
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true }
});

function jsonBody(event) { try { return event.body ? JSON.parse(event.body) : {}; } catch { return {}; } }
function callerId(caller) { return caller?.sub || caller?.userId || caller?.identityId || caller?.cognitoIdentityId || null; }

function pkUser(userId) { return `USER#${userId}`; }
function pkStall(stallId) { return `STALL#${stallId}`; }
function skStall(stallId) { return `STALL#${stallId}`; }
function skProd(productId) { return `PROD#${productId}`; }

async function assertOwnsStall(userId, stallId) {
  if (!STALLS_TABLE) return false;
  const res = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) }
  }));
  return !!res.Item;
}

exports.list = async ({ stallId, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  // Si aún no creaste products table, no rompas el app
  if (!PRODUCTS_TABLE) return ok({ products: [] });

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const q = await ddb.send(new QueryCommand({
    TableName: PRODUCTS_TABLE,
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
    tags: x.tags ?? [],
    price: x.price ?? null,
    active: x.active ?? true,
    lastQty: x.lastQty ?? null,
    lastSeenAt: x.lastSeenAt ?? null
  }));

  return ok({ products });
};

exports.update = async ({ stallId, productId, event, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (!PRODUCTS_TABLE) return bad(500, 'ENV_MISSING', 'Falta PRODUCTS_TABLE (crea la tabla products)');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = jsonBody(event);

  const display = body.display != null ? String(body.display).trim() : null;
  const price = body.price != null ? Number(body.price) : null;
  const active = body.active != null ? !!body.active : null;
  const tags = Array.isArray(body.tags) ? body.tags.map(x => String(x)) : null;

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
  if (tags !== null) {
    names['#tags'] = 'tags';
    values[':tags'] = tags;
    sets.push('#tags=:tags');
  }

  if (!sets.length) return bad(400, 'VALIDATION', 'Nada para actualizar');

  await ddb.send(new UpdateCommand({
    TableName: PRODUCTS_TABLE,
    Key: { pk: pkStall(stallId), sk: skProd(productId) },
    UpdateExpression: `SET ${sets.join(', ')}`,
    ExpressionAttributeNames: names,
    ExpressionAttributeValues: values
  }));

  return ok({ ok: true });
};