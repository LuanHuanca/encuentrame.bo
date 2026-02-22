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

const {
  RekognitionClient,
  DetectLabelsCommand,
  DetectModerationLabelsCommand
} = require('@aws-sdk/client-rekognition');

const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const BUCKET_NAME = process.env.BUCKET_NAME;
const STALLS_TABLE = process.env.STALLS_TABLE;
const OPENINGLOGS_TABLE = process.env.OPENINGLOGS_TABLE;
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || '';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true }
});
const rek = new RekognitionClient({ region: REGION });
const bedrock = new BedrockRuntimeClient({ region: REGION });

function jsonBody(event) { try { return event.body ? JSON.parse(event.body) : {}; } catch { return {}; } }
function nowIso() { return new Date().toISOString(); }
function uuid() { return crypto.randomUUID ? crypto.randomUUID() : crypto.randomBytes(16).toString('hex'); }

// IAM: cognitoIdentityId / identityId
// User Pools: sub
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

/* =========================
   S3 key normalization (fix public/public etc.)
========================= */

function normalizeS3Key(k) {
  let key = String(k || '').trim();
  if (!key) return key;
  if (key.startsWith('/')) key = key.slice(1);
  key = key.replace(/\/{2,}/g, '/'); // collapse //
  if (key.startsWith('public/public/')) key = key.replace('public/public/', 'public/');
  return key;
}

function candidateKeys(k) {
  const key = normalizeS3Key(k);
  const out = [];
  const push = (x) => { if (x && !out.includes(x)) out.push(x); };

  push(key);

  // si el key vino como "vendor/x.jpg" pero el bucket lo guarda como public/vendor/...
  if (!key.startsWith('public/')) push(`public/${key}`);

  // si el key vino como public/vendor/... pero Amplify lo guardó como public/public/vendor/...
  if (key.startsWith('public/')) push(`public/public/${key.slice('public/'.length)}`);

  // si el key vino como public/public/... pero en realidad era public/...
  if (key.startsWith('public/public/')) push(key.replace('public/public/', 'public/'));

  return out.slice(0, 4);
}

function isResourceNotFound(e) {
  return e?.name === 'ResourceNotFoundException' || e?.$metadata?.httpStatusCode === 404;
}

function awsDetails(e) {
  return {
    name: e?.name,
    message: e?.message,
    status: e?.$metadata?.httpStatusCode
  };
}

/* =========================
   Rekognition with fallback keys
========================= */

async function detectProductsLabelsWithKey(productsPhotoKey) {
  const tries = candidateKeys(productsPhotoKey);
  let lastErr;

  for (const k of tries) {
    try {
      const out = await rek.send(new DetectLabelsCommand({
        Image: { S3Object: { Bucket: BUCKET_NAME, Name: k } },
        MaxLabels: 25,
        MinConfidence: 70
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
        MinConfidence: 70
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

/* =========================
   Inventory: normalization + reconciliation
========================= */

function fallbackInventoryParse(raw) {
  const parts = raw.split(',').map(x => x.trim()).filter(Boolean);
  const items = [];
  for (const p of parts) {
    const m = p.match(/^(\d+)\s+(.*)$/);
    if (m) items.push({ canonical: m[2].trim(), display: m[2].trim(), qty: Number(m[1]), unit: 'unidad', category: null, tags: [], suggested: false });
    else items.push({ canonical: p, display: p, qty: 1, unit: 'unidad', category: null, tags: [], suggested: false });
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

const VISION_STOP_LABELS = new Set([
  'Person','Human','Face','Man','Woman','Kid','Child','People','Adult','Smile','Head','Hand','Finger'
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
];

const LABEL_SYNONYMS = [
  { label: 'Bottle', words: ['botella','tomatodo','termo','vaso','shaker'] },
  { label: 'Clothing', words: ['ropa','polera','camiseta','pantalón','pantalones'] },
  { label: 'Sunglasses', words: ['gafas de sol','lentes de sol'] },
  { label: 'Plate', words: ['plato','platos'] },
  { label: 'Deodorant', words: ['desodorante'] },
];

function normalizeCanonical(s) {
  const x = (s || '').toLowerCase().trim();
  if (!x) return '';
  for (const [a,b] of CANON_MAP) {
    if (x === a) return b;
  }
  return x;
}

function isNonProduct(canonical) {
  const x = (canonical || '').toLowerCase();
  return ['hombre','mujer','persona','personas','gente','niño','niña','adulto','adultos'].includes(x);
}

function labelMatchesItem(canonical, labels) {
  const name = canonical.toLowerCase();
  const matched = [];

  const labelsFiltered = (labels || []).filter(l => l?.name && !VISION_STOP_LABELS.has(l.name));

  for (const l of labelsFiltered) {
    const ln = (l.name || '').toLowerCase();
    if (!ln) continue;
    if (name.includes(ln) || ln.includes(name)) matched.push(l.name);
  }

  for (const map of LABEL_SYNONYMS) {
    if (map.words.some(w => name.includes(w))) matched.push(map.label);
  }

  return [...new Set(matched)];
}

function reconcileInventory(itemsFromText, labels) {
  const out = [];
  const seen = new Map(); // canonical -> index

  for (const it of (itemsFromText || [])) {
    const canonical = normalizeCanonical(it.canonical || it.name || '');
    if (!canonical || isNonProduct(canonical)) continue;

    const qty = Math.max(1, Number(it.qty || 1));
    const matched = labelMatchesItem(canonical, labels);

    const confBase = (it.suggested === true) ? 0.60 : 0.78;
    const conf = Math.min(0.95, confBase + (matched.length ? 0.14 : 0));

    const obj = {
      canonical,
      display: it.display || canonical,
      qty,
      unit: it.unit ?? 'unidad',
      category: it.category ?? (matched[0] ?? null),
      tags: it.tags ?? [],
      evidence: { text: true, vision: matched },
      confidence: Number(conf.toFixed(2)),
      suggested: false
    };

    if (!seen.has(canonical)) {
      seen.set(canonical, out.length);
      out.push(obj);
    } else {
      const idx = seen.get(canonical);
      out[idx].qty += qty;
      out[idx].confidence = Math.max(out[idx].confidence, obj.confidence);
      out[idx].evidence.vision = [...new Set([...out[idx].evidence.vision, ...matched])];
    }
  }

  const visionOnly = [];
  const alreadyVision = new Set(out.flatMap(x => x.evidence.vision || []));
  for (const l of (labels || [])) {
    if (!l?.name) continue;
    if (VISION_STOP_LABELS.has(l.name)) continue;
    if (alreadyVision.has(l.name)) continue;

    const ln = l.name.toLowerCase();
    if (['clothing','food','product','object','indoor','room'].includes(ln)) continue;

    visionOnly.push({
      canonical: normalizeCanonical(l.name),
      display: l.name,
      qty: 1,
      unit: 'unidad',
      category: l.name,
      tags: [],
      evidence: { text: false, vision: [l.name] },
      confidence: 0.65,
      suggested: true
    });
  }

  return { items: out, visionOnly };
}

/* =========================
   Bedrock inventory extraction
========================= */

async function bedrockInventory(rawText, labels) {
  if (!BEDROCK_MODEL_ID) return null;

  const prompt =
`Eres un extractor de inventario para un puesto de venta en Bolivia.
Entrada: texto hablado (español) + labels de Rekognition (evidencia visual).
Objetivo: devolver un inventario estructurado y fácil de entender.

REGLAS:
- Devuelve SOLO JSON válido, sin explicación.
- Si el texto dice cantidades (ej "10 poleras"), respétalas aunque no se vean en la foto.
- Normaliza nombres: "tomatodo" -> "botella", "polera/camiseta" -> "polera", "gafas de sol/lentes" -> "gafas de sol".
- No inventes productos. Si aparece solo en labels, NO lo metas como item confirmado.
- Si en el texto aparece "hombre/persona", NO lo trates como producto.

FORMATO:
{
  "items":[
    {
      "canonical": string,
      "display": string,
      "qty": number,
      "unit": "unidad"|"par"|"paquete"|null,
      "category": string|null,
      "tags": string[],
      "suggested": boolean
    }
  ]
}

Texto:
"""${rawText}"""

Labels (Rekognition):
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
    if (obj && Array.isArray(obj.items)) return obj;
    return null;
  } catch {
    return null;
  }
}

/* =========================
   Products upsert (catalog per stall)
========================= */

async function upsertProductsFromInventory({ stallId, items, now }) {
  if (!PRODUCTS_TABLE) return;
  if (!items || !items.length) return;

  const slug = (s) =>
    String(s || '')
      .toLowerCase()
      .trim()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9\-áéíóúñ]/g, '')
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

/* =========================
   CRUD: stalls (igual que tenías)
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

/* =========================
   Lifecycle: open / current / close / history
========================= */

async function open({ event, caller }) {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (!STALLS_TABLE || !OPENINGLOGS_TABLE || !BUCKET_NAME) {
    return bad(500, 'ENV_MISSING', 'Faltan env vars (tables/bucket)', JSON.stringify({
      STALLS_TABLE, OPENINGLOGS_TABLE, BUCKET_NAME
    }));
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

  // ✅ normalize keys aquí
  let stallPhotoKey = normalizeS3Key(body.stallPhotoKey);
  let productsPhotoKey = normalizeS3Key(body.productsPhotoKey);
  const inventoryText = String(body.inventoryText || '').trim();

  console.log('OPEN keys/env', {
    stallId,
    BUCKET_NAME,
    STALLS_TABLE,
    OPENINGLOGS_TABLE,
    PRODUCTS_TABLE,
    BEDROCK_MODEL_ID,
    stallPhotoKey,
    productsPhotoKey
  });

  if (!stallPhotoKey || !productsPhotoKey) return bad(400, 'MISSING_PHOTOS', 'Faltan fotos');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad(400, 'MISSING_LOCATION', 'Falta ubicación');
  if (!inventoryText) return bad(400, 'MISSING_INVENTORY', 'Falta inventario');

  const now = nowIso();
  const openSk = `OPEN#${now}#${uuid()}`;

  let labels = [];
  let moderation = [];

  try {
    const [labelsRes, modRes] = await Promise.all([
      detectProductsLabelsWithKey(productsPhotoKey),
      detectModerationWithKey(stallPhotoKey)
    ]);

    labels = labelsRes.labels;
    moderation = modRes.moderation;

    // ✅ guarda el key que realmente existe
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
    console.log('BEDROCK_ERROR (fallback to parser)', awsDetails(e));
    inv = null;
  }
  if (!inv) inv = fallbackInventoryParse(inventoryText);

  const reconciled = reconcileInventory(inv.items, labels);

  try {
    await upsertProductsFromInventory({ stallId, items: reconciled.items, now });
  } catch (e) {
    console.log('UPSERT_PRODUCTS_ERROR (ignored for MVP)', awsDetails(e));
  }

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
      inventoryItems: reconciled.items,
      inventoryVisionOnly: reconciled.visionOnly
    }
  }));

  return ok({
    stallId,
    openingKey: openSk,
    status: flagged ? 'REVIEW' : 'OPEN',
    labels,
    moderation,
    inventory: {
      items: reconciled.items,
      visionOnly: reconciled.visionOnly
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
  remove,
  open,
  getCurrent,
  close,
  listOpenings,
  getMy
};