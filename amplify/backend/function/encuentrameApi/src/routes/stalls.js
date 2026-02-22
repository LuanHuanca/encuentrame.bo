/* eslint-disable */
const crypto = require('crypto');
const { ok, bad } = require('../util/http');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  PutCommand,
  UpdateCommand,
  GetCommand,
  QueryCommand,
  DeleteCommand,
  BatchGetCommand
} = require('@aws-sdk/lib-dynamodb');

const { RekognitionClient, DetectLabelsCommand, DetectModerationLabelsCommand } = require('@aws-sdk/client-rekognition');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const BUCKET_NAME = process.env.BUCKET_NAME;
const STALLS_TABLE = process.env.STALLS_TABLE;
const OPENINGLOGS_TABLE = process.env.OPENINGLOGS_TABLE;
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || '';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true }
});
const rek = new RekognitionClient({ region: REGION });
const bedrock = new BedrockRuntimeClient({ region: REGION });

function jsonBody(event) { try { return event.body ? JSON.parse(event.body) : {}; } catch { return {}; } }
function nowIso() { return new Date().toISOString(); }
function uuid() { return crypto.randomUUID ? crypto.randomUUID() : crypto.randomBytes(16).toString('hex'); }
function callerId(caller) { return caller?.sub || caller?.userId || caller?.identityId || caller?.cognitoIdentityId || null; }

function pkStall(stallId) { return `STALL#${stallId}`; }
function pkUser(userId) { return `USER#${userId}`; }
function skStall(stallId) { return `STALL#${stallId}`; }

async function assertOwnsStall(userId, stallId) {
  const res = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) }
  }));
  return !!res.Item;
}

async function detectProductsLabels(productsPhotoKey) {
  const out = await rek.send(new DetectLabelsCommand({
    Image: { S3Object: { Bucket: BUCKET_NAME, Name: productsPhotoKey } },
    MaxLabels: 20,
    MinConfidence: 70
  }));
  return (out.Labels || []).map(l => ({
    name: l.Name,
    confidence: Math.round((l.Confidence || 0) * 10) / 10
  }));
}

async function detectModeration(stallPhotoKey) {
  const out = await rek.send(new DetectModerationLabelsCommand({
    Image: { S3Object: { Bucket: BUCKET_NAME, Name: stallPhotoKey } },
    MinConfidence: 70
  }));
  return (out.ModerationLabels || []).map(l => ({
    name: l.Name,
    confidence: Math.round((l.Confidence || 0) * 10) / 10
  }));
}

function fallbackInventoryParse(raw) {
  const parts = raw.split(',').map(x => x.trim()).filter(Boolean);
  const items = [];
  for (const p of parts) {
    const m = p.match(/^(\d+)\s+(.*)$/);
    if (m) items.push({ name: m[2].trim(), qty: Number(m[1]), color: null, size: null, price: null, tags: [] });
    else items.push({ name: p, qty: 1, color: null, size: null, price: null, tags: [] });
  }
  return { items };
}

function extractJson(text) {
  if (!text) return null;
  const s = text.indexOf('{');
  const e = text.lastIndexOf('}');
  if (s !== -1 && e !== -1 && e > s) return text.substring(s, e + 1);
  return null;
}

const LABEL_SYNONYMS = [
  { label: 'Shoe', words: ['zapato', 'zapatos', 'bota', 'botas', 'calzado'] },
  { label: 'Clothing', words: ['ropa', 'polera', 'poleras', 'camiseta', 'camisetas', 'pantalón', 'pantalones'] },
  { label: 'Food', words: ['comida', 'tomate', 'tomates', 'fruta', 'verdura', 'verduras'] },
  { label: 'Bottle', words: ['desodorante', 'perfume', 'spray'] },
];

function matchLabelsForItem(itemName, labels) {
  const name = (itemName || '').toLowerCase();
  const matched = [];

  for (const l of (labels || [])) {
    const ln = (l.name || '').toLowerCase();
    if (ln && name.includes(ln)) matched.push(l.name);
  }

  for (const map of LABEL_SYNONYMS) {
    if (map.words.some(w => name.includes(w.toLowerCase()))) matched.push(map.label);
  }

  return [...new Set(matched)];
}

function addConsensus(items, labels) {
  return (items || []).map(it => {
    const matched = matchLabelsForItem(it.name, labels);
    const score = matched.length > 0 ? 0.9 : 0.6;
    return { ...it, matchedLabels: matched, consensusScore: score };
  });
}

async function bedrockInventory(rawText, labels) {
  if (!BEDROCK_MODEL_ID) return null;

  const prompt =
`Extrae inventario desde texto en español y usa los labels de Rekognition como evidencia.
Devuelve SOLO JSON válido con este formato:

{
  "items":[
    {"name":string,"qty":number,"color":string|null,"size":string|null,"price":number|null,"tags":string[]}
  ]
}

Texto:
"${rawText}"

Labels:
${JSON.stringify(labels || [])}
`;

  const isTitan = BEDROCK_MODEL_ID.startsWith('amazon.');

  const body = isTitan
    ? JSON.stringify({
        inputText: prompt,
        textGenerationConfig: { maxTokenCount: 500, temperature: 0, topP: 1 }
      })
    : JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 500,
        temperature: 0,
        messages: [{ role: 'user', content: prompt }]
      });

  const res = await bedrock.send(new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    contentType: 'application/json',
    accept: 'application/json',
    body
  }));

  const raw = Buffer.from(res.body).toString('utf8');
  const parsed = JSON.parse(raw);

  const outText = isTitan ? (parsed?.results?.[0]?.outputText || '') : (parsed?.content?.[0]?.text || '');
  const jsonStr = extractJson(outText);
  if (!jsonStr) return null;

  try {
    const obj = JSON.parse(jsonStr);
    if (obj && Array.isArray(obj.items)) return obj;
    return null;
  } catch {
    return null;
  }
}

/* =========================
   CRUD: stalls
========================= */

async function list({ caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const q = await ddb.send(new QueryCommand({
    TableName: STALLS_TABLE,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
    ExpressionAttributeValues: { ':pk': pkUser(userId), ':pfx': 'STALL#' },
    ScanIndexForward: true
  }));

  const links = (q.Items || []).map(x => ({
    stallId: x.stallId,
    name: x.name,
    active: x.active ?? true,
    createdAt: x.createdAt
  }));

  if (!links.length) return ok({ stalls: [] });

  const keys = links.map(s => ({ pk: pkStall(s.stallId), sk: 'PROFILE' }));

  // BatchGet con reintento por UnprocessedKeys (MVP robusto)
  let requestItems = { [STALLS_TABLE]: { Keys: keys } };
  const profiles = [];

  for (let i = 0; i < 3; i++) {
    const bg = await ddb.send(new BatchGetCommand({ RequestItems: requestItems }));
    profiles.push(...(bg.Responses?.[STALLS_TABLE] || []));

    const unprocessed = bg.UnprocessedKeys || {};
    if (!unprocessed[STALLS_TABLE] || !unprocessed[STALLS_TABLE].Keys?.length) break;

    requestItems = unprocessed;
  }

  const profMap = profiles.reduce((acc, it) => {
    if (it?.stallId) acc[it.stallId] = it;
    return acc;
  }, {});

  const stalls = links.map(s => {
    const prof = profMap[s.stallId];
    const currentOpen = prof?.currentOpen || null;

    return {
      ...s,
      currentOpen,
      isOpen: !!currentOpen,
      currentLat: prof?.currentLat ?? null,
      currentLng: prof?.currentLng ?? null,
      updatedAt: prof?.updatedAt ?? null
    };
  });

  return ok({ stalls });
}

async function create({ event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const body = jsonBody(event);
  const name = String(body.name || '').trim();
  if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');

  const stallId = `stall_${uuid()}`;
  const now = nowIso();

  await ddb.send(new PutCommand({
    TableName: STALLS_TABLE,
    Item: {
      pk: pkStall(stallId),
      sk: 'PROFILE',
      entityType: 'STALL',
      stallId,
      vendorUserId: userId,
      name,
      active: true,
      createdAt: now,
      updatedAt: now,
      currentOpen: null
    }
  }));

  await ddb.send(new PutCommand({
    TableName: STALLS_TABLE,
    Item: {
      pk: pkUser(userId),
      sk: skStall(stallId),
      entityType: 'USER_STALL',
      stallId,
      name,
      active: true,
      createdAt: now
    }
  }));

  return ok({ stallId, name });
}

async function get({ stallId, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const res = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' }
  }));

  return ok({ stall: res.Item || null });
}

async function update({ stallId, event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const body = jsonBody(event);
  const name = String(body.name || '').trim();
  if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');

  const now = nowIso();

  await ddb.send(new UpdateCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    UpdateExpression: 'SET #name=:n, updatedAt=:u',
    ExpressionAttributeNames: { '#name': 'name' },
    ExpressionAttributeValues: { ':n': name, ':u': now }
  }));

  await ddb.send(new UpdateCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) },
    UpdateExpression: 'SET #name=:n',
    ExpressionAttributeNames: { '#name': 'name' },
    ExpressionAttributeValues: { ':n': name }
  }));

  return ok({ ok: true });
}

async function remove({ stallId, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const prof = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' }
  }));

  const stall = prof.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no existe');

  if (stall.currentOpen) {
    return bad(400, 'STALL_OPEN', 'Cierra el puesto antes de eliminar');
  }

  await ddb.send(new DeleteCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) }
  }));

  await ddb.send(new DeleteCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' }
  }));

  return ok({ ok: true });
}

/* =========================
   Lifecycle: open / current / close / history
========================= */

async function open({ event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (!STALLS_TABLE || !OPENINGLOGS_TABLE || !BUCKET_NAME) {
    return bad(500, 'ENV_MISSING', 'Faltan env vars (tables/bucket)');
  }

  const body = jsonBody(event);

  const stallId = String(body.stallId || '').trim();
  if (!stallId) return bad(400, 'VALIDATION', 'stallId requerido');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const stallName = String(body.stallName || 'Mi puesto').trim();

  const lat = Number(body.lat);
  const lng = Number(body.lng);
  const accuracy = Number(body.accuracy || 0);

  const stallPhotoKey = body.stallPhotoKey;
  const productsPhotoKey = body.productsPhotoKey;
  const inventoryText = String(body.inventoryText || '').trim();

  if (!stallPhotoKey || !productsPhotoKey) return bad(400, 'MISSING_PHOTOS', 'Faltan fotos');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad(400, 'MISSING_LOCATION', 'Falta ubicación');
  if (!inventoryText) return bad(400, 'MISSING_INVENTORY', 'Falta inventario');

  const now = nowIso();
  const openSk = `OPEN#${now}#${uuid()}`;

  const [labels, moderation] = await Promise.all([
    detectProductsLabels(productsPhotoKey),
    detectModeration(stallPhotoKey)
  ]);

  const flagged = (moderation || []).length > 0;

  let inv = null;
  try { inv = await bedrockInventory(inventoryText, labels); } catch (_) { inv = null; }
  if (!inv) inv = fallbackInventoryParse(inventoryText);

  const invWithConsensus = addConsensus(inv.items, labels);

  await ddb.send(new UpdateCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    UpdateExpression: 'SET vendorUserId=:u, #name=:n, currentOpen=:o, currentLat=:lat, currentLng=:lng, updatedAt=:now',
    ExpressionAttributeNames: { '#name': 'name' },
    ExpressionAttributeValues: { ':u': userId, ':n': stallName, ':o': openSk, ':lat': lat, ':lng': lng, ':now': now }
  }));

  await ddb.send(new PutCommand({
    TableName: OPENINGLOGS_TABLE,
    Item: {
      pk: pkStall(stallId),
      sk: openSk,
      entityType: 'OPENING',
      status: flagged ? 'REVIEW' : 'OPEN',
      openedAt: now,
      lat, lng, accuracy,
      stallPhotoKey,
      productsPhotoKey,
      rekognitionLabels: labels,
      moderationLabels: moderation,
      inventoryRaw: inventoryText,
      inventoryItems: invWithConsensus
    }
  }));

  return ok({
    stallId,
    openingKey: openSk,
    status: flagged ? 'REVIEW' : 'OPEN',
    labels,
    moderation,
    inventory: { items: invWithConsensus }
  });
}

async function getCurrent({ stallId, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const prof = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' }
  }));

  const stall = prof.Item || null;
  let opening = null;

  if (stall?.currentOpen) {
    const o = await ddb.send(new GetCommand({
      TableName: OPENINGLOGS_TABLE,
      Key: { pk: pkStall(stallId), sk: stall.currentOpen }
    }));
    opening = o.Item || null;
  } else {
    const q = await ddb.send(new QueryCommand({
      TableName: OPENINGLOGS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
      ExpressionAttributeValues: { ':pk': pkStall(stallId), ':pfx': 'OPEN#' },
      ScanIndexForward: false,
      Limit: 1
    }));
    opening = (q.Items && q.Items[0]) ? q.Items[0] : null;
  }

  return ok({ stall, opening });
}

async function close({ stallId, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const prof = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' }
  }));
  const stall = prof.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no existe');

  const currentOpen = stall.currentOpen;
  if (!currentOpen) return bad(400, 'NO_OPEN', 'No hay apertura activa');

  const now = nowIso();

  await ddb.send(new UpdateCommand({
    TableName: OPENINGLOGS_TABLE,
    Key: { pk: pkStall(stallId), sk: currentOpen },
    UpdateExpression: 'SET #status=:s, closedAt=:c',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':s': 'CLOSED', ':c': now }
  }));

  await ddb.send(new UpdateCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    UpdateExpression: 'SET currentOpen=:n, updatedAt=:u',
    ExpressionAttributeValues: { ':n': null, ':u': now }
  }));

  return ok({ ok: true });
}

async function listOpenings({ stallId, event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const owns = await assertOwnsStall(userId, stallId);
  if (!owns) return bad(403, 'FORBIDDEN', 'No es tu puesto');

  const limit = Math.min(Number((event.queryStringParameters || {}).limit || 20), 50);

  const q = await ddb.send(new QueryCommand({
    TableName: OPENINGLOGS_TABLE,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
    ExpressionAttributeValues: { ':pk': pkStall(stallId), ':pfx': 'OPEN#' },
    ScanIndexForward: false,
    Limit: limit
  }));

  return ok({ openings: q.Items || [] });
}

async function getMy({ caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const q = await ddb.send(new QueryCommand({
    TableName: STALLS_TABLE,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
    ExpressionAttributeValues: { ':pk': pkUser(userId), ':pfx': 'STALL#' },
    ScanIndexForward: true,
    Limit: 1
  }));

  const first = (q.Items && q.Items[0]) ? q.Items[0] : null;
  if (!first) return ok({ stall: null, opening: null });

  return getCurrent({ stallId: first.stallId, caller });
}

module.exports = {
  list,
  create,
  get,
  update,
  remove, // 👈 nuevo
  open,
  getCurrent,
  close,
  listOpenings,
  getMy
};