'use strict';

const crypto = require('crypto');
const { ok, bad } = require('../util/http');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  QueryCommand,
  GetCommand,
  PutCommand,
} = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const STALLS_TABLE = process.env.STALLS_TABLE;
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;
const ORDERS_TABLE = process.env.ORDERS_TABLE;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true },
});

function jsonBody(event) {
  try {
    return event?.body ? JSON.parse(event.body) : {};
  } catch {
    return {};
  }
}

function callerId(caller) {
  return (
    caller?.sub ||
    caller?.userId ||
    caller?.identityId ||
    caller?.cognitoIdentityId ||
    caller?._identity?.cognitoIdentityId ||
    null
  );
}

function nowIso() {
  return new Date().toISOString();
}

function uuid() {
  return crypto.randomUUID ? crypto.randomUUID() : crypto.randomBytes(16).toString('hex');
}

function toNum(x) {
  const n = Number(x);
  return Number.isFinite(n) ? n : null;
}

function clamp(n, min, max) {
  return Math.max(min, Math.min(max, n));
}

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;

  return 2 * R * Math.asin(Math.sqrt(a));
}

async function queryOpenStallsProfiles(maxItems) {
  if (!STALLS_TABLE) return [];

  const items = [];
  let ExclusiveStartKey;

  while (items.length < maxItems) {
    const page = await ddb.send(
      new QueryCommand({
        TableName: STALLS_TABLE,
        IndexName: 'gsi1',
        KeyConditionExpression: 'gsi1pk = :p',
        ExpressionAttributeValues: { ':p': 'OPEN' },
        ScanIndexForward: false,
        Limit: Math.min(100, maxItems - items.length),
        ExclusiveStartKey,
      })
    );

    items.push(...(page.Items || []));
    ExclusiveStartKey = page.LastEvaluatedKey;
    if (!ExclusiveStartKey) break;
  }

  return items;
}

exports.listOpenStallsNear = async ({ event, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const qs = event?.queryStringParameters || {};
  const lat = toNum(qs.lat);
  const lng = toNum(qs.lng);

  if (lat === null || lng === null) {
    return bad(400, 'VALIDATION', 'lat y lng son requeridos');
  }

  const radiusKm = clamp(toNum(qs.radiusKm) ?? 2, 0.1, 50);
  const limit = clamp(toNum(qs.limit) ?? 30, 1, 100);
  const q = String(qs.q || '').trim().toLowerCase();

  const includeProducts = String(qs.includeProducts || '0') === '1';
  const productsLimit = clamp(toNum(qs.productsLimit) ?? 6, 1, 20);

  if (!STALLS_TABLE) return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');

  const profiles = await queryOpenStallsProfiles(300);
  const radiusMeters = radiusKm * 1000;

  let stalls = profiles
    .map((p) => {
      const sLat = toNum(p.currentLat);
      const sLng = toNum(p.currentLng);
      if (sLat === null || sLng === null) return null;

      const name = String(p.name || '').trim() || 'Puesto';
      if (q && !name.toLowerCase().includes(q)) return null;

      const distanceMeters = haversineMeters(lat, lng, sLat, sLng);

      return {
        stallId: String(p.stallId || '').trim(),
        name,
        isOpen: !!p.currentOpen,
        lat: sLat,
        lng: sLng,
        addressLabel: p.currentAddressLabel ?? null,
        distanceMeters: Math.round(distanceMeters),
      };
    })
    .filter(Boolean)
    .filter((s) => s.stallId && s.distanceMeters <= radiusMeters)
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, limit);

  if (!includeProducts || !PRODUCTS_TABLE || stalls.length === 0) {
    return ok({ radiusKm, count: stalls.length, stalls });
  }

  const stallsWithProducts = await Promise.all(
    stalls.map(async (s) => {
      try {
        const res = await ddb.send(
          new QueryCommand({
            TableName: PRODUCTS_TABLE,
            KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
            ExpressionAttributeValues: {
              ':pk': pkStall(s.stallId),
              ':pfx': 'PROD#',
            },
            ScanIndexForward: true,
            Limit: 60,
          })
        );

        const productsPreview = (res.Items || [])
          .map((x) => ({
            productId: x.productId,
            display: x.display,
            canonical: x.canonical,
            price: x.price ?? null,
            active: x.active ?? true,
            lastQty: x.lastQty ?? null,
            lastSeenAt: x.lastSeenAt ?? null,
          }))
          .filter((p) => p.active === true)
          .slice(0, productsLimit);

        return { ...s, productsPreview };
      } catch {
        return { ...s, productsPreview: [] };
      }
    })
  );

  return ok({ radiusKm, count: stallsWithProducts.length, stalls: stallsWithProducts });
};

exports.listStallProductsPublic = async ({ stallId, event, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (!PRODUCTS_TABLE) return ok({ stallId, products: [] });

  const id = String(stallId || '').trim();
  if (!id) return bad(400, 'VALIDATION', 'stallId requerido');

  const qs = event?.queryStringParameters || {};
  const q = String(qs.q || '').trim().toLowerCase();
  const limit = clamp(toNum(qs.limit) ?? 50, 1, 100);

  const res = await ddb.send(
    new QueryCommand({
      TableName: PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
      ExpressionAttributeValues: {
        ':pk': pkStall(id),
        ':pfx': 'PROD#',
      },
      ScanIndexForward: true,
      Limit: 200,
    })
  );

  let products = (res.Items || [])
    .map((x) => ({
      productId: x.productId,
      canonical: x.canonical,
      display: x.display,
      price: x.price ?? null,
      active: x.active ?? true,
      lastQty: x.lastQty ?? null,
      lastSeenAt: x.lastSeenAt ?? null,
    }))
    .filter((p) => p.active === true);

  if (q) {
    products = products.filter((p) => {
      const a = String(p.display || '').toLowerCase();
      const b = String(p.canonical || '').toLowerCase();
      return a.includes(q) || b.includes(q);
    });
  }

  products = products.slice(0, limit);

  return ok({ stallId: id, count: products.length, products });
};

exports.searchProductsNear = async ({ event, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const qs = event?.queryStringParameters || {};
  const lat = toNum(qs.lat);
  const lng = toNum(qs.lng);
  const q = String(qs.q || '').trim().toLowerCase();

  if (lat === null || lng === null) return bad(400, 'VALIDATION', 'lat y lng son requeridos');
  if (!q) return bad(400, 'VALIDATION', 'q es requerido');
  if (!PRODUCTS_TABLE) return ok({ q, results: [] });

  const radiusKm = clamp(toNum(qs.radiusKm) ?? 2, 0.1, 50);
  const limit = clamp(toNum(qs.limit) ?? 30, 1, 100);

  const openEvent = {
    queryStringParameters: {
      lat: String(lat),
      lng: String(lng),
      radiusKm: String(radiusKm),
      limit: '80',
      includeProducts: '0',
    },
  };

  const openRes = await exports.listOpenStallsNear({ event: openEvent, caller });
  const openBody = JSON.parse(openRes.body || '{}');
  const stalls = (openBody.stalls || []).slice(0, 80);

  const results = [];

  for (const s of stalls) {
    const sid = String(s.stallId || '').trim();
    if (!sid) continue;

    const res = await ddb.send(
      new QueryCommand({
        TableName: PRODUCTS_TABLE,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
        ExpressionAttributeValues: {
          ':pk': pkStall(sid),
          ':pfx': 'PROD#',
        },
        ScanIndexForward: true,
        Limit: 120,
      })
    );

    const matches = (res.Items || [])
      .map((x) => ({
        stallId: sid,
        stallName: s.name,
        distanceMeters: s.distanceMeters,
        addressLabel: s.addressLabel ?? null,
        lat: s.lat,
        lng: s.lng,
        product: {
          productId: x.productId,
          display: x.display,
          canonical: x.canonical,
          price: x.price ?? null,
          active: x.active ?? true,
          lastQty: x.lastQty ?? null,
        },
      }))
      .filter((row) => row.product.active === true)
      .filter((row) => {
        const a = String(row.product.display || '').toLowerCase();
        const b = String(row.product.canonical || '').toLowerCase();
        return a.includes(q) || b.includes(q);
      });

    results.push(...matches);
    if (results.length >= limit) break;
  }

  results.sort((a, b) => a.distanceMeters - b.distanceMeters);

  return ok({
    q,
    radiusKm,
    count: results.slice(0, limit).length,
    results: results.slice(0, limit),
  });
};

exports.createOrder = async ({ event, caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const body = jsonBody(event);
  const stallId = String(body.stallId || '').trim();
  const rawItems = Array.isArray(body.items) ? body.items : [];

  if (!STALLS_TABLE) return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  if (!stallId) return bad(400, 'VALIDATION', 'stallId requerido');
  if (!rawItems.length) return bad(400, 'VALIDATION', 'items requerido');

  const prof = await ddb.send(
    new GetCommand({
      TableName: STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  const stall = prof.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no existe');
  if (!stall.currentOpen) return bad(400, 'STALL_CLOSED', 'El puesto no está abierto');

  const pickup = {
    stallId,
    stallName: stall.name || 'Puesto',
    lat: stall.currentLat ?? null,
    lng: stall.currentLng ?? null,
    addressLabel: stall.currentAddressLabel ?? null,
  };

  const items = rawItems
    .map((it) => ({
      productId: String(it.productId || '').trim(),
      qty: Math.max(1, Number(it.qty || 1)),
    }))
    .filter((it) => it.productId);

  if (!items.length) return bad(400, 'VALIDATION', 'items inválido');

  const orderId = `order_${uuid()}`;
  const createdAt = nowIso();

  if (!ORDERS_TABLE) {
    return ok({
      orderId,
      createdAt,
      saved: false,
      pickup,
      message: 'ORDERS_TABLE no configurada. Se devolvió la ubicación sin guardar la orden.',
    });
  }

  await ddb.send(
    new PutCommand({
      TableName: ORDERS_TABLE,
      Item: {
        pk: `USER#${userId}`,
        sk: `ORDER#${createdAt}#${orderId}`,
        entityType: 'ORDER',
        orderId,
        stallId,
        items,
        status: 'CREATED',
        pickup,
        createdAt,
        notes: body.notes ? String(body.notes).slice(0, 500) : null,
        region: REGION,
      },
    })
  );

  return ok({ orderId, createdAt, saved: true, pickup });
};