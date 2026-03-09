'use strict';

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

const {
  RekognitionClient,
  DetectLabelsCommand,
  DetectModerationLabelsCommand
} = require('@aws-sdk/client-rekognition');

const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
const { LocationClient, SearchPlaceIndexForPositionCommand } = require('@aws-sdk/client-location');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const BUCKET_NAME = process.env.BUCKET_NAME;
const STALLS_TABLE = process.env.STALLS_TABLE;
const OPENINGLOGS_TABLE = process.env.OPENINGLOGS_TABLE;
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || '';
const LOCATION_PLACE_INDEX_NAME = process.env.LOCATION_PLACE_INDEX_NAME || '';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true }
});
const rek = new RekognitionClient({ region: REGION });
const bedrock = new BedrockRuntimeClient({ region: REGION });
const location = new LocationClient({ region: REGION });

function jsonBody(event) {
  try {
    return event.body ? JSON.parse(event.body) : {};
  } catch {
    return {};
  }
}

function nowIso() {
  return new Date().toISOString();
}

function uuid() {
  return crypto.randomUUID ? crypto.randomUUID() : crypto.randomBytes(16).toString('hex');
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

function pkStall(stallId) { return `STALL#${stallId}`; }
function pkUser(userId) { return `USER#${userId}`; }
function skStall(stallId) { return `STALL#${stallId}`; }
function skProd(productId) { return `PROD#${productId}`; }

async function assertOwnsStall(userId, stallId) {
  const res = await ddb.send(new GetCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkUser(userId), sk: skStall(stallId) }
  }));
  return !!res.Item;
}

async function findFirstOwnedStall(userId) {
  const result = await ddb.send(new QueryCommand({
    TableName: STALLS_TABLE,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :pfx)',
    ExpressionAttributeValues: {
      ':pk': pkUser(userId),
      ':pfx': 'STALL#'
    },
    ScanIndexForward: true,
    Limit: 1
  }));

  return (result.Items && result.Items[0]) ? result.Items[0] : null;
}

function normalizeS3Key(k) {
  let key = String(k || '').trim();
  if (!key) return key;
  if (key.startsWith('/')) key = key.slice(1);
  key = key.replace(/\/{2,}/g, '/');
  if (key.startsWith('public/public/')) key = key.replace('public/public/', 'public/');
  return key;
}

function candidateKeys(k) {
  const key = normalizeS3Key(k);
  const out = [];
  const push = (x) => { if (x && !out.includes(x)) out.push(x); };

  push(key);
  if (key && !key.startsWith('public/')) push(`public/${key}`);
  if (key && key.startsWith('public/')) push(`public/public/${key.slice('public/'.length)}`);
  if (key && key.startsWith('public/public/')) push(key.replace('public/public/', 'public/'));

  return out.slice(0, 4);
}

function isResourceNotFound(e) {
  return e?.name === 'ResourceNotFoundException' || e?.$metadata?.httpStatusCode === 404;
}

function awsDetails(e) {
  return { name: e?.name, message: e?.message, status: e?.$metadata?.httpStatusCode };
}

async function detectProductsLabelsWithKey(productsPhotoKey) {
  const tries = candidateKeys(productsPhotoKey);
  let lastErr;

  for (const k of tries) {
    try {
      const out = await rek.send(new DetectLabelsCommand({
        Image: { S3Object: { Bucket: BUCKET_NAME, Name: k } },
        MaxLabels: 20,
        MinConfidence: 80
      }));

      const labels = (out.Labels || []).map(l => ({
        name: l.Name,
        confidence: Math.round((l.Confidence || 0) * 10) / 10
      }));

      return { labels, keyUsed: k };
    } catch (e) {
      lastErr = e;
      if (isResourceNotFound(e)) continue;
      throw e;
    }
  }

  throw lastErr;
}

async function detectModerationWithKey(stallPhotoKey) {
  const tries = candidateKeys(stallPhotoKey);
  let lastErr;

  for (const k of tries) {
    try {
      const out = await rek.send(new DetectModerationLabelsCommand({
        Image: { S3Object: { Bucket: BUCKET_NAME, Name: k } },
        MinConfidence: 75
      }));

      const moderation = (out.ModerationLabels || []).map(l => ({
        name: l.Name,
        confidence: Math.round((l.Confidence || 0) * 10) / 10
      }));

      return { moderation, keyUsed: k };
    } catch (e) {
      lastErr = e;
      if (isResourceNotFound(e)) continue;
      throw e;
    }
  }

  throw lastErr;
}

async function reverseGeocode(lat, lng) {
  if (!LOCATION_PLACE_INDEX_NAME) return null;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

  try {
    const out = await location.send(new SearchPlaceIndexForPositionCommand({
      IndexName: LOCATION_PLACE_INDEX_NAME,
      Position: [lng, lat],
      MaxResults: 1
    }));

    const place = out?.Results?.[0]?.Place || null;
    if (!place) return null;

    const address = {
      label: place.Label || null,
      street: place.Street || null,
      neighborhood: place.Neighborhood || null,
      municipality: place.Municipality || null,
      subRegion: place.SubRegion || null,
      region: place.Region || null,
      country: place.Country || null,
      postalCode: place.PostalCode || null
    };

    return { label: place.Label || null, address };
  } catch (e) {
    console.log('LOCATION_ERROR', awsDetails(e));
    return null;
  }
}

const VISION_STOP_LABELS = new Set([
  'Person','Human','Face','Man','Woman','Kid','Child','People','Adult','Smile','Head','Hand','Finger'
]);

const VISION_GENERIC = new Set([
  'Product','Products','Object','Indoors','Room','Floor','Table','Furniture','Clothing'
]);

const CANON_MAP = [
  ['tomatodo', 'botella'],
  ['termo', 'botella'],
  ['camiseta', 'polera'],
  ['camisetas', 'polera'],
  ['poleras', 'polera'],
  ['lentes', 'gafas de sol'],
  ['lentes de sol', 'gafas de sol'],
  ['gafas', 'gafas de sol'],
  ['zapatos', 'zapato'],
  ['botas', 'bota']
];

function normalizeCanonical(s) {
  const x = (s || '').toLowerCase().trim();
  if (!x) return '';
  for (const [a, b] of CANON_MAP) {
    if (x === a) return b;
  }
  return x;
}

function isNonProduct(canonical) {
  const x = (canonical || '').toLowerCase();
  return ['hombre','mujer','persona','personas','gente','niño','niña','adulto','adultos'].includes(x);
}

function spanishWordToNumber(word) {
  const w = (word || '').toLowerCase().trim();
  const map = {
    'un': 1, 'una': 1, 'uno': 1,
    'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
    'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
    'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
    'dieciseis': 16, 'dieciséis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19, 'veinte': 20
  };
  return map[w] ?? null;
}

function parseLooseInventory(raw) {
  const text = String(raw || '')
    .replace(/\s+/g, ' ')
    .replace(/\s+y\s+/gi, ', ')
    .replace(/\s+e\s+/gi, ', ')
    .trim();

  if (!text) return [];

  const parts = text.split(',').map(x => x.trim()).filter(Boolean);
  const items = [];

  for (const p of parts) {
    const m1 = p.match(/^(\d+)\s+(.*)$/);
    if (m1) {
      items.push({ canonical: m1[2].trim(), display: m1[2].trim(), qty: Number(m1[1]) });
      continue;
    }

    const m2 = p.match(/^([a-záéíóúñ]+)\s+(.*)$/i);
    if (m2) {
      const n = spanishWordToNumber(m2[1]);
      if (n != null) {
        const name = m2[2].trim();
        if (name) items.push({ canonical: name, display: name, qty: n });
        continue;
      }
    }

    items.push({ canonical: p, display: p, qty: 1 });
  }

  return items;
}

function fallbackInventoryParse(raw) {
  const items = parseLooseInventory(raw).map(it => ({
    canonical: it.canonical,
    display: it.display,
    qty: it.qty,
    unit: 'unidad',
    category: null,
    tags: [],
    suggested: false
  }));
  return { items };
}

function extractJson(text) {
  if (!text) return null;
  const s = text.indexOf('{');
  const e = text.lastIndexOf('}');
  if (s !== -1 && e !== -1 && e > s) return text.substring(s, e + 1);
  return null;
}

function sanitizeInventoryItems(items) {
  const out = [];
  const seen = new Map();

  for (const it of (items || [])) {
    const canonical = normalizeCanonical(it?.canonical || it?.name || it?.display || '');
    if (!canonical || isNonProduct(canonical)) continue;

    let qty = Number(it?.qty ?? 1);
    if (!Number.isFinite(qty) || qty <= 0) qty = 1;
    qty = Math.round(qty);

    const display = String(it?.display || canonical).trim() || canonical;

    const obj = {
      canonical,
      display,
      qty,
      unit: it?.unit ?? 'unidad',
      category: it?.category ?? null,
      tags: Array.isArray(it?.tags) ? it.tags : [],
      suggested: !!it?.suggested
    };

    if (!seen.has(canonical)) {
      seen.set(canonical, out.length);
      out.push(obj);
    } else {
      const idx = seen.get(canonical);
      out[idx].qty += obj.qty;
    }
  }

  return out;
}

async function bedrockInventory(rawText, labels) {
  if (!BEDROCK_MODEL_ID) return null;

  const prompt =
`Eres un extractor de inventario. La app convertirá tu respuesta en una tabla (Producto + Cantidad).

TAREA:
- Lee el texto en español y conviértelo en ITEMS separados.
- Si el texto dice "10 zapatos, una polera y una botella", deben salir 3 filas:
  - zapato qty 10
  - polera qty 1
  - botella qty 1

REGLAS CRÍTICAS:
- Devuelve SOLO JSON válido. Sin texto extra. Sin markdown. Sin explicación.
- Devuelve items SOLO desde el texto. NO inventes items por Rekognition.
- Si no hay cantidad, asume 1.
- Normaliza nombres (obligatorio):
  - "tomatodo" o "termo" -> "botella"
  - "camiseta" o "poleras" -> "polera"
  - "botas" -> "bota"
  - "zapatos" -> "zapato"
- Fusiona duplicados (si se repiten, suma cantidades).
- Ignora "persona/hombre/mujer/niño" como producto.

FORMATO ESTRICTO:
{
  "items": [
    { "canonical": "string", "display": "string", "qty": number }
  ]
}

Texto:
"""${rawText}"""

Labels (solo referencia, NO para crear items):
${JSON.stringify(labels || [])}
`;

  const isTitan = BEDROCK_MODEL_ID.startsWith('amazon.');

  const body = isTitan
    ? JSON.stringify({
        inputText: prompt,
        textGenerationConfig: { maxTokenCount: 700, temperature: 0, topP: 1 }
      })
    : JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 700,
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

  const outText = isTitan
    ? (parsed?.results?.[0]?.outputText || '')
    : (parsed?.content?.[0]?.text || '');

  const jsonStr = extractJson(outText);
  if (!jsonStr) return null;

  try {
    const obj = JSON.parse(jsonStr);
    if (obj && Array.isArray(obj.items)) {
      obj.items = sanitizeInventoryItems(obj.items);
      return obj;
    }
    return null;
  } catch {
    return null;
  }
}

function labelMatchesItem(canonical, labels) {
  const name = canonical.toLowerCase();
  const filtered = (labels || [])
    .filter(l => l?.name && !VISION_STOP_LABELS.has(l.name) && !VISION_GENERIC.has(l.name))
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  const matched = [];

  for (const l of filtered) {
    const ln = String(l.name || '').toLowerCase();
    if (!ln) continue;
    if (name.includes(ln) || ln.includes(name)) matched.push(l.name);
    if (matched.length >= 2) break;
  }

  return [...new Set(matched)];
}

function reconcileInventory(itemsFromText, labels) {
  const items = [];
  const seen = new Map();

  const cleanTextItems = sanitizeInventoryItems(itemsFromText || []);
  const cleanLabels = (labels || [])
    .filter(l => l?.name && !VISION_STOP_LABELS.has(l.name) && !VISION_GENERIC.has(l.name))
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  for (const it of cleanTextItems) {
    const matched = labelMatchesItem(it.canonical, cleanLabels);

    const obj = {
      canonical: it.canonical,
      display: it.display,
      qty: it.qty,
      unit: it.unit ?? 'unidad',
      category: it.category ?? (matched[0] ?? null),
      tags: it.tags ?? [],
      evidence: { text: true, vision: matched.slice(0, 2) },
      confidence: matched.length ? 0.92 : 0.82,
      suggested: false
    };

    if (!seen.has(obj.canonical)) {
      seen.set(obj.canonical, items.length);
      items.push(obj);
    } else {
      const idx = seen.get(obj.canonical);
      items[idx].qty += obj.qty;
    }
  }

  const suggestions = [];
  const used = new Set(items.flatMap(x => (x.evidence?.vision || [])).filter(Boolean));

  for (const l of cleanLabels) {
    if (!l?.name) continue;
    if (used.has(l.name)) continue;
    if ((l.confidence || 0) < 88) continue;

    suggestions.push({
      label: l.name,
      confidence: Math.min(0.7, Math.max(0.55, (l.confidence || 0) / 100)),
    });

    if (suggestions.length >= 6) break;
  }

  return { items, suggestions };
}

async function upsertProductsFromInventory({ stallId, items, now }) {
  if (!PRODUCTS_TABLE) return;
  if (!items || !items.length) return;

  const slug = (s) =>
    String(s || '')
      .toLowerCase()
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9\-]/g, '')
      .slice(0, 64);

  for (const it of items) {
    const productId = slug(it.canonical);
    if (!productId) continue;

    await ddb.send(new UpdateCommand({
      TableName: PRODUCTS_TABLE,
      Key: { pk: pkStall(stallId), sk: skProd(productId) },
      UpdateExpression: `
        SET entityType = if_not_exists(entityType, :type),
            productId = if_not_exists(productId, :pid),
            canonical = if_not_exists(canonical, :canon),
            #display = if_not_exists(#display, :display),
            category = if_not_exists(category, :cat),
            tags = if_not_exists(tags, :tags),
            active = if_not_exists(active, :active),
            lastQty = :lastQty,
            lastSeenAt = :lastSeenAt
      `,
      ExpressionAttributeNames: { '#display': 'display' },
      ExpressionAttributeValues: {
        ':type': 'PRODUCT',
        ':pid': productId,
        ':canon': it.canonical,
        ':display': it.display || it.canonical,
        ':cat': it.category ?? null,
        ':tags': it.tags ?? [],
        ':active': true,
        ':lastQty': it.qty ?? 1,
        ':lastSeenAt': now
      }
    }));
  }
}

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
      currentAddressLabel: prof?.currentAddressLabel ?? null,
      updatedAt: prof?.updatedAt ?? null
    };
  });

  return ok({ stalls });
}

async function create({ event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!STALLS_TABLE) return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');

  const existingStall = await findFirstOwnedStall(userId);
  if (existingStall) {
    return bad(409, 'STALL_ALREADY_EXISTS', 'Ya tienes un puesto creado');
  }

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
      currentOpen: null,
      currentLat: null,
      currentLng: null,
      currentAddressLabel: null,
      currentAddress: null
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
  if (stall.currentOpen) return bad(400, 'STALL_OPEN', 'Cierra el puesto antes de eliminar');

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

  const lat = Number(body.lat);
  const lng = Number(body.lng);
  const accuracy = Number(body.accuracy || 0);

  let stallPhotoKey = normalizeS3Key(body.stallPhotoKey);
  let productsPhotoKey = normalizeS3Key(body.productsPhotoKey);
  const inventoryText = String(body.inventoryText || '').trim();

  if (!stallPhotoKey || !productsPhotoKey) return bad(400, 'MISSING_PHOTOS', 'Faltan fotos');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad(400, 'MISSING_LOCATION', 'Falta ubicación');
  if (!inventoryText) return bad(400, 'MISSING_INVENTORY', 'Falta inventario');

  const now = nowIso();
  const openSk = `OPEN#${now}#${uuid()}`;

  const geo = await reverseGeocode(lat, lng);

  let labels = [];
  let moderation = [];

  try {
    const [labelsRes, modRes] = await Promise.all([
      detectProductsLabelsWithKey(productsPhotoKey),
      detectModerationWithKey(stallPhotoKey)
    ]);

    labels = labelsRes.labels;
    moderation = modRes.moderation;

    productsPhotoKey = labelsRes.keyUsed;
    stallPhotoKey = modRes.keyUsed;
  } catch (e) {
    console.log('REKOGNITION_ERROR', awsDetails(e));

    if (isResourceNotFound(e)) {
      return bad(
        400,
        'PHOTO_NOT_FOUND',
        'No se encontró la foto en S3 (key incorrecto)',
        JSON.stringify({ stallPhotoKey, productsPhotoKey, bucket: BUCKET_NAME, err: awsDetails(e) })
      );
    }

    return bad(500, 'REKOGNITION_ERROR', 'Error en Rekognition', JSON.stringify(awsDetails(e)));
  }

  const flagged = (moderation || []).length > 0;

  let inv = null;
  try {
    inv = await bedrockInventory(inventoryText, labels);
  } catch (e) {
    console.log('BEDROCK_ERROR', awsDetails(e));
    inv = null;
  }
  if (!inv) inv = fallbackInventoryParse(inventoryText);

  const reconciled = reconcileInventory(inv.items, labels);

  try {
    await upsertProductsFromInventory({ stallId, items: reconciled.items, now });
  } catch (e) {
    console.log('UPSERT_PRODUCTS_ERROR', awsDetails(e));
  }

  const stallName = String(body.stallName || '').trim();

  await ddb.send(new UpdateCommand({
    TableName: STALLS_TABLE,
    Key: { pk: pkStall(stallId), sk: 'PROFILE' },
    UpdateExpression: `
      SET vendorUserId=:u,
          #name=:n,
          currentOpen=:o,
          currentLat=:lat,
          currentLng=:lng,
          currentAddressLabel=:al,
          currentAddress=:a,
          gsi1pk=:gpk,
          gsi1sk=:gsk,
          updatedAt=:now
    `,
    ExpressionAttributeNames: { '#name': 'name' },
    ExpressionAttributeValues: {
      ':u': userId,
      ':n': stallName || undefined,
      ':o': openSk,
      ':lat': lat,
      ':lng': lng,
      ':al': geo?.label ?? null,
      ':a': geo?.address ?? null,
      ':gpk': 'OPEN',
      ':gsk': `OPEN#${now}#${stallId}`,
      ':now': now
    }
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
      addressLabel: geo?.label ?? null,
      address: geo?.address ?? null,
      stallPhotoKey,
      productsPhotoKey,
      rekognitionLabels: labels,
      moderationLabels: moderation,
      inventoryRaw: inventoryText,
      inventoryItems: reconciled.items,
      inventorySuggestions: reconciled.suggestions
    }
  }));

  return ok({
    stallId,
    openingKey: openSk,
    status: flagged ? 'REVIEW' : 'OPEN',
    location: {
      lat,
      lng,
      accuracy,
      addressLabel: geo?.label ?? null
    },
    inventory: {
      items: reconciled.items.map(x => ({ display: x.display, qty: x.qty, canonical: x.canonical })),
      suggestions: reconciled.suggestions
    }
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
    UpdateExpression: 'REMOVE gsi1pk, gsi1sk SET currentOpen=:n, updatedAt=:u',
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
  getMy
};