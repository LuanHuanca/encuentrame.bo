'use strict';

const crypto = require('crypto');

const config = require('../config');
const { ok, bad, parseJsonBody } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb, rekognition } = require('../services/aws');
const { reverseGeocode } = require('../services/location');
const {
  fallbackInventoryParse,
  bedrockInventory,
  reconcileInventory,
} = require('../services/inventory');

const {
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand,
  BatchGetCommand,
} = require('@aws-sdk/lib-dynamodb');

const {
  DetectLabelsCommand,
  DetectModerationLabelsCommand,
} = require('@aws-sdk/client-rekognition');

function nowIso() {
  return new Date().toISOString();
}

function uuid() {
  return crypto.randomUUID
    ? crypto.randomUUID()
    : crypto.randomBytes(16).toString('hex');
}

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

async function findFirstOwnedStall(userId) {
  if (!config.STALLS_TABLE) return null;

  const response = await ddb.send(
    new QueryCommand({
      TableName: config.STALLS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkUser(userId),
        ':prefix': 'STALL#',
      },
      ScanIndexForward: true,
      Limit: 1,
    })
  );

  return response.Items?.[0] || null;
}

function normalizeS3Key(value) {
  let key = String(value || '').trim();
  if (!key) return key;
  if (key.startsWith('/')) key = key.slice(1);
  key = key.replace(/\/{2,}/g, '/');
  if (key.startsWith('public/public/')) {
    key = key.replace('public/public/', 'public/');
  }
  return key;
}

function candidateKeys(value) {
  const key = normalizeS3Key(value);
  const keys = [];

  const push = (item) => {
    if (item && !keys.includes(item)) keys.push(item);
  };

  push(key);

  if (key && !key.startsWith('public/')) {
    push(`public/${key}`);
  }

  if (key && key.startsWith('public/')) {
    push(`public/public/${key.slice('public/'.length)}`);
  }

  if (key && key.startsWith('public/public/')) {
    push(key.replace('public/public/', 'public/'));
  }

  return keys.slice(0, 4);
}

function isResourceNotFound(error) {
  return (
    error?.name === 'ResourceNotFoundException' ||
    error?.$metadata?.httpStatusCode === 404
  );
}

function awsDetails(error) {
  return {
    name: error?.name,
    message: error?.message,
    status: error?.$metadata?.httpStatusCode,
  };
}

async function detectProductsLabelsWithKey(productsPhotoKey) {
  const keys = candidateKeys(productsPhotoKey);
  let lastError;

  for (const key of keys) {
    try {
      const output = await rekognition.send(
        new DetectLabelsCommand({
          Image: {
            S3Object: {
              Bucket: config.BUCKET_NAME,
              Name: key,
            },
          },
          MaxLabels: 20,
          MinConfidence: 80,
        })
      );

      const labels = (output.Labels || []).map((item) => ({
        name: item.Name,
        confidence: Math.round((item.Confidence || 0) * 10) / 10,
      }));

      return { labels, keyUsed: key };
    } catch (error) {
      lastError = error;
      if (isResourceNotFound(error)) continue;
      throw error;
    }
  }

  throw lastError;
}

async function detectModerationWithKey(stallPhotoKey) {
  const keys = candidateKeys(stallPhotoKey);
  let lastError;

  for (const key of keys) {
    try {
      const output = await rekognition.send(
        new DetectModerationLabelsCommand({
          Image: {
            S3Object: {
              Bucket: config.BUCKET_NAME,
              Name: key,
            },
          },
          MinConfidence: 75,
        })
      );

      const moderation = (output.ModerationLabels || []).map((item) => ({
        name: item.Name,
        confidence: Math.round((item.Confidence || 0) * 10) / 10,
      }));

      return { moderation, keyUsed: key };
    } catch (error) {
      lastError = error;
      if (isResourceNotFound(error)) continue;
      throw error;
    }
  }

  throw lastError;
}

async function upsertProductsFromInventory({ stallId, items, now }) {
  if (!config.PRODUCTS_TABLE) return;
  if (!items || !items.length) return;

  const slug = (value) =>
    String(value || '')
      .toLowerCase()
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9\-]/g, '')
      .slice(0, 64);

  for (const item of items) {
    const productId = slug(item.canonical);
    if (!productId) continue;

    await ddb.send(
      new UpdateCommand({
        TableName: config.PRODUCTS_TABLE,
        Key: { pk: pkStall(stallId), sk: skProd(productId) },
        UpdateExpression: `
          SET entityType = if_not_exists(entityType, :type),
              productId = if_not_exists(productId, :pid),
              canonical = if_not_exists(canonical, :canonical),
              #display = if_not_exists(#display, :display),
              category = if_not_exists(category, :category),
              description = if_not_exists(description, :description),
              tags = if_not_exists(tags, :tags),
              active = if_not_exists(active, :active),
              lastQty = :lastQty,
              lastSeenAt = :lastSeenAt
        `,
        ExpressionAttributeNames: {
          '#display': 'display',
        },
        ExpressionAttributeValues: {
          ':type': 'PRODUCT',
          ':pid': productId,
          ':canonical': item.canonical,
          ':display': item.display || item.canonical,
          ':category': item.category ?? null,
          ':description': null,
          ':tags': item.tags ?? [],
          ':active': true,
          ':lastQty': item.qty ?? 1,
          ':lastSeenAt': now,
        },
      })
    );
  }
}

async function list({ caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE) return ok({ stalls: [] });

  const linksResponse = await ddb.send(
    new QueryCommand({
      TableName: config.STALLS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkUser(userId),
        ':prefix': 'STALL#',
      },
      ScanIndexForward: true,
    })
  );

  const links = (linksResponse.Items || []).map((item) => ({
    stallId: item.stallId,
    name: item.name,
    category: item.category ?? null,
    description: item.description ?? null,
    active: item.active ?? true,
    createdAt: item.createdAt,
  }));

  if (!links.length) return ok({ stalls: [] });

  const keys = links.map((stall) => ({
    pk: pkStall(stall.stallId),
    sk: 'PROFILE',
  }));

  let requestItems = {
    [config.STALLS_TABLE]: {
      Keys: keys,
    },
  };

  const profiles = [];

  for (let i = 0; i < 3; i += 1) {
    const batch = await ddb.send(
      new BatchGetCommand({
        RequestItems: requestItems,
      })
    );

    profiles.push(...(batch.Responses?.[config.STALLS_TABLE] || []));

    const unprocessed = batch.UnprocessedKeys || {};
    if (
      !unprocessed[config.STALLS_TABLE] ||
      !unprocessed[config.STALLS_TABLE].Keys?.length
    ) {
      break;
    }

    requestItems = unprocessed;
  }

  const profileMap = profiles.reduce((acc, item) => {
    if (item?.stallId) acc[item.stallId] = item;
    return acc;
  }, {});

  const stalls = links.map((stall) => {
    const profile = profileMap[stall.stallId];
    const currentOpen = profile?.currentOpen || null;

    return {
      ...stall,
      name: profile?.name ?? stall.name,
      category: profile?.category ?? stall.category ?? null,
      description: profile?.description ?? stall.description ?? null,
      currentOpen,
      isOpen: !!currentOpen,
      currentLat: profile?.currentLat ?? null,
      currentLng: profile?.currentLng ?? null,
      currentAddressLabel: profile?.currentAddressLabel ?? null,
      updatedAt: profile?.updatedAt ?? null,
    };
  });

  return ok({ stalls });
}

async function create({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  }

  const existingStall = await findFirstOwnedStall(userId);
  if (existingStall) {
    return bad(409, 'STALL_ALREADY_EXISTS', 'Ya tienes un puesto creado');
  }

  const body = parseJsonBody(event);

  const name = String(body.name || '').trim();
  const category = String(body.category || '').trim() || null;
  const description = String(body.description || '').trim() || null;

  if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');

  const stallId = `stall_${uuid()}`;
  const now = nowIso();

  await ddb.send(
    new PutCommand({
      TableName: config.STALLS_TABLE,
      Item: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
        entityType: 'STALL',
        stallId,
        vendorUserId: userId,
        name,
        category,
        description,
        active: true,
        createdAt: now,
        updatedAt: now,
        currentOpen: null,
        currentLat: null,
        currentLng: null,
        currentAddressLabel: null,
        currentAddress: null,
      },
    })
  );

  await ddb.send(
    new PutCommand({
      TableName: config.STALLS_TABLE,
      Item: {
        pk: pkUser(userId),
        sk: skStall(stallId),
        entityType: 'USER_STALL',
        stallId,
        name,
        category,
        description,
        active: true,
        createdAt: now,
      },
    })
  );

  return ok({
    stallId,
    name,
    category,
    description,
  });
}

async function get({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const response = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  return ok({ stall: response.Item || null });
}

async function update({ stallId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = parseJsonBody(event);

  const name = body.name != null ? String(body.name).trim() : null;
  const category =
    body.category != null ? String(body.category).trim() || null : null;
  const description =
    body.description != null ? String(body.description).trim() || null : null;

  if (name !== null) {
    if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');
    if (name.length < 2) {
      return bad(400, 'VALIDATION', 'Nombre demasiado corto');
    }
    if (name.length > 60) {
      return bad(400, 'VALIDATION', 'Máximo 60 caracteres');
    }
  }

  const profileSets = ['updatedAt = :updatedAt'];
  const profileNames = {};
  const profileValues = {
    ':updatedAt': nowIso(),
  };

  const linkSets = [];
  const linkNames = {};
  const linkValues = {};

  if (name !== null) {
    profileNames['#name'] = 'name';
    profileValues[':name'] = name;
    profileSets.push('#name = :name');

    linkNames['#name'] = 'name';
    linkValues[':name'] = name;
    linkSets.push('#name = :name');
  }

  if (category !== null) {
    profileValues[':category'] = category;
    profileSets.push('category = :category');

    linkValues[':category'] = category;
    linkSets.push('category = :category');
  }

  if (description !== null) {
    profileValues[':description'] = description;
    profileSets.push('description = :description');

    linkValues[':description'] = description;
    linkSets.push('description = :description');
  }

  if (profileSets.length === 1) {
    return bad(400, 'VALIDATION', 'Nada para actualizar');
  }

  await ddb.send(
    new UpdateCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
      UpdateExpression: `SET ${profileSets.join(', ')}`,
      ExpressionAttributeNames: Object.keys(profileNames).length
        ? profileNames
        : undefined,
      ExpressionAttributeValues: profileValues,
    })
  );

  if (linkSets.length) {
    await ddb.send(
      new UpdateCommand({
        TableName: config.STALLS_TABLE,
        Key: { pk: pkUser(userId), sk: skStall(stallId) },
        UpdateExpression: `SET ${linkSets.join(', ')}`,
        ExpressionAttributeNames: Object.keys(linkNames).length
          ? linkNames
          : undefined,
        ExpressionAttributeValues: linkValues,
      })
    );
  }

  return ok({ ok: true });
}

async function remove({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const profileResponse = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  const stall = profileResponse.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no existe');
  if (stall.currentOpen) {
    return bad(400, 'STALL_OPEN', 'Cierra el puesto antes de eliminar');
  }

  await ddb.send(
    new DeleteCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkUser(userId), sk: skStall(stallId) },
    })
  );

  await ddb.send(
    new DeleteCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  return ok({ ok: true });
}

async function open({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (
    !config.STALLS_TABLE ||
    !config.OPENINGLOGS_TABLE ||
    !config.BUCKET_NAME
  ) {
    return bad(500, 'ENV_MISSING', 'Faltan env vars (tables/bucket)');
  }

  const body = parseJsonBody(event);

  const stallId = String(body.stallId || '').trim();
  const stallName = String(body.stallName || '').trim();
  const lat = Number(body.lat);
  const lng = Number(body.lng);
  const accuracy = Number(body.accuracy || 0);

  let stallPhotoKey = normalizeS3Key(body.stallPhotoKey);
  let productsPhotoKey = normalizeS3Key(body.productsPhotoKey);
  const inventoryText = String(body.inventoryText || '').trim();

  if (!stallId) return bad(400, 'VALIDATION', 'stallId requerido');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const profileResponse = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  const currentProfile = profileResponse.Item || null;
  if (!currentProfile) return bad(404, 'NOT_FOUND', 'Puesto no existe');

  if (!stallPhotoKey || !productsPhotoKey) {
    return bad(400, 'MISSING_PHOTOS', 'Faltan fotos');
  }

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return bad(400, 'MISSING_LOCATION', 'Falta ubicación');
  }

  if (!inventoryText) {
    return bad(400, 'MISSING_INVENTORY', 'Falta inventario');
  }

  const now = nowIso();
  const openSk = `OPEN#${now}#${uuid()}`;

  const geo = await reverseGeocode(lat, lng);

  let labels = [];
  let moderation = [];

  try {
    const [labelsResult, moderationResult] = await Promise.all([
      detectProductsLabelsWithKey(productsPhotoKey),
      detectModerationWithKey(stallPhotoKey),
    ]);

    labels = labelsResult.labels;
    moderation = moderationResult.moderation;

    productsPhotoKey = labelsResult.keyUsed;
    stallPhotoKey = moderationResult.keyUsed;
  } catch (error) {
    console.log('REKOGNITION_ERROR', awsDetails(error));

    if (isResourceNotFound(error)) {
      return bad(
        400,
        'PHOTO_NOT_FOUND',
        'No se encontró la foto en S3 (key incorrecto)',
        JSON.stringify({
          stallPhotoKey,
          productsPhotoKey,
          bucket: config.BUCKET_NAME,
          err: awsDetails(error),
        })
      );
    }

    return bad(
      500,
      'REKOGNITION_ERROR',
      'Error en Rekognition',
      JSON.stringify(awsDetails(error))
    );
  }

  const flagged = moderation.length > 0;

  let inventory = null;

  try {
    inventory = await bedrockInventory(inventoryText, labels);
  } catch (error) {
    console.log('BEDROCK_ERROR', awsDetails(error));
    inventory = null;
  }

  if (!inventory) {
    inventory = fallbackInventoryParse(inventoryText);
  }

  const reconciled = reconcileInventory(inventory.items, labels);

  try {
    await upsertProductsFromInventory({
      stallId,
      items: reconciled.items,
      now,
    });
  } catch (error) {
    console.log('UPSERT_PRODUCTS_ERROR', awsDetails(error));
  }

  const resolvedStallName =
    stallName || currentProfile.name || 'Puesto';

  await ddb.send(
    new UpdateCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
      UpdateExpression: `
        SET vendorUserId = :userId,
            #name = :name,
            currentOpen = :currentOpen,
            currentLat = :lat,
            currentLng = :lng,
            currentAddressLabel = :addressLabel,
            currentAddress = :address,
            gsi1pk = :gsi1pk,
            gsi1sk = :gsi1sk,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':name': resolvedStallName,
        ':currentOpen': openSk,
        ':lat': lat,
        ':lng': lng,
        ':addressLabel': geo?.label ?? null,
        ':address': geo?.address ?? null,
        ':gsi1pk': 'OPEN',
        ':gsi1sk': `OPEN#${now}#${stallId}`,
        ':updatedAt': now,
      },
    })
  );

  await ddb.send(
    new UpdateCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkUser(userId), sk: skStall(stallId) },
      UpdateExpression: 'SET #name = :name',
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':name': resolvedStallName,
      },
    })
  );

  await ddb.send(
    new PutCommand({
      TableName: config.OPENINGLOGS_TABLE,
      Item: {
        pk: pkStall(stallId),
        sk: openSk,
        entityType: 'OPENING',
        status: flagged ? 'REVIEW' : 'OPEN',
        openedAt: now,
        lat,
        lng,
        accuracy,
        addressLabel: geo?.label ?? null,
        address: geo?.address ?? null,
        stallPhotoKey,
        productsPhotoKey,
        rekognitionLabels: labels,
        moderationLabels: moderation,
        inventoryRaw: inventoryText,
        inventoryItems: reconciled.items,
        inventorySuggestions: reconciled.suggestions,
      },
    })
  );

  return ok({
    stallId,
    openingKey: openSk,
    status: flagged ? 'REVIEW' : 'OPEN',
    location: {
      lat,
      lng,
      accuracy,
      addressLabel: geo?.label ?? null,
    },
    inventory: {
      items: reconciled.items.map((item) => ({
        display: item.display,
        qty: item.qty,
        canonical: item.canonical,
      })),
      suggestions: reconciled.suggestions,
    },
  });
}

async function getCurrent({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE || !config.OPENINGLOGS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Faltan tablas');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const profileResponse = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  const stall = profileResponse.Item || null;
  let opening = null;

  if (stall?.currentOpen) {
    const openingResponse = await ddb.send(
      new GetCommand({
        TableName: config.OPENINGLOGS_TABLE,
        Key: { pk: pkStall(stallId), sk: stall.currentOpen },
      })
    );

    opening = openingResponse.Item || null;
  } else {
    const queryResponse = await ddb.send(
      new QueryCommand({
        TableName: config.OPENINGLOGS_TABLE,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
        ExpressionAttributeValues: {
          ':pk': pkStall(stallId),
          ':prefix': 'OPEN#',
        },
        ScanIndexForward: false,
        Limit: 1,
      })
    );

    opening = queryResponse.Items?.[0] || null;
  }

  return ok({ stall, opening });
}

async function close({ stallId, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE || !config.OPENINGLOGS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Faltan tablas');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const profileResponse = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    })
  );

  const stall = profileResponse.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no existe');

  const currentOpen = stall.currentOpen;
  if (!currentOpen) return bad(400, 'NO_OPEN', 'No hay apertura activa');

  const now = nowIso();

  await ddb.send(
    new UpdateCommand({
      TableName: config.OPENINGLOGS_TABLE,
      Key: { pk: pkStall(stallId), sk: currentOpen },
      UpdateExpression: 'SET #status = :status, closedAt = :closedAt',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ':status': 'CLOSED',
        ':closedAt': now,
      },
    })
  );

  await ddb.send(
    new UpdateCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(stallId), sk: 'PROFILE' },
      UpdateExpression: 'REMOVE gsi1pk, gsi1sk SET currentOpen = :currentOpen, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':currentOpen': null,
        ':updatedAt': now,
      },
    })
  );

  return ok({ ok: true });
}

async function listOpenings({ stallId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.OPENINGLOGS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta OPENINGLOGS_TABLE');
  }

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const limit = Math.min(
    Number((event.queryStringParameters || {}).limit || 20),
    50
  );

  const response = await ddb.send(
    new QueryCommand({
      TableName: config.OPENINGLOGS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'OPEN#',
      },
      ScanIndexForward: false,
      Limit: limit,
    })
  );

  return ok({ openings: response.Items || [] });
}

async function getMy({ caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const first = await findFirstOwnedStall(userId);
  if (!first) return ok({ stall: null, opening: null });

  return getCurrent({ stallId: first.stallId, caller });
}

module.exports = {
  list,
  create,
  get,
  update,
  remove,
  open,
  getCurrent,
  close,
  listOpenings,
  getMy,
};