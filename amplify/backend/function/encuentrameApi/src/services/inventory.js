'use strict';

const config = require('../config');
const { bedrock } = require('./aws');
const { InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

function extractJson(text) {
  if (!text) return null;
  const s = text.indexOf('{');
  const e = text.lastIndexOf('}');
  if (s !== -1 && e !== -1 && e > s) return text.substring(s, e + 1);
  return null;
}

function normalizeText(text) {
  return String(text || '')
    .toLowerCase()
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function spanishWordToNumber(word) {
  const map = {
    un: 1,
    una: 1,
    uno: 1,
    dos: 2,
    tres: 3,
    cuatro: 4,
    cinco: 5,
    seis: 6,
    siete: 7,
    ocho: 8,
    nueve: 9,
    diez: 10,
    once: 11,
    doce: 12,
    trece: 13,
    catorce: 14,
    quince: 15,
    dieciseis: 16,
    'dieciséis': 16,
    diecisiete: 17,
    dieciocho: 18,
    diecinueve: 19,
    veinte: 20,
  };
  return map[normalizeText(word)] ?? null;
}

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
  ['botas', 'bota'],
];

function normalizeCanonical(text) {
  const value = normalizeText(text);
  if (!value) return '';
  for (const [source, target] of CANON_MAP) {
    if (value === source) return target;
  }
  return value;
}

function isNonProduct(canonical) {
  const value = normalizeText(canonical);
  return [
    'hombre',
    'mujer',
    'persona',
    'personas',
    'gente',
    'nino',
    'nina',
    'adulto',
    'adultos',
    'person',
    'people',
  ].includes(value);
}

function parseLooseInventory(raw) {
  const text = String(raw || '')
    .replace(/\s+/g, ' ')
    .replace(/\s+y\s+/gi, ', ')
    .replace(/\s+e\s+/gi, ', ')
    .trim();

  if (!text) return [];

  const parts = text
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  const items = [];

  for (const part of parts) {
    const numericMatch = part.match(/^(\d+)\s+(.*)$/);
    if (numericMatch) {
      items.push({
        canonical: numericMatch[2].trim(),
        display: numericMatch[2].trim(),
        qty: Number(numericMatch[1]),
      });
      continue;
    }

    const wordMatch = part.match(/^([a-záéíóúñ]+)\s+(.*)$/i);
    if (wordMatch) {
      const asNumber = spanishWordToNumber(wordMatch[1]);
      if (asNumber != null) {
        items.push({
          canonical: wordMatch[2].trim(),
          display: wordMatch[2].trim(),
          qty: asNumber,
        });
        continue;
      }
    }

    items.push({
      canonical: part,
      display: part,
      qty: 1,
    });
  }

  return items;
}

function sanitizeInventoryItems(items) {
  const output = [];
  const seen = new Map();

  for (const item of items || []) {
    const canonical = normalizeCanonical(
      item?.canonical || item?.name || item?.display || ''
    );
    if (!canonical || isNonProduct(canonical)) continue;

    let qty = Number(item?.qty ?? 1);
    if (!Number.isFinite(qty) || qty <= 0) qty = 1;
    qty = Math.round(qty);

    const display = String(item?.display || canonical).trim() || canonical;

    const clean = {
      canonical,
      display,
      qty,
      unit: item?.unit ?? 'unidad',
      category: item?.category ?? null,
      tags: Array.isArray(item?.tags) ? item.tags : [],
      suggested: !!item?.suggested,
    };

    if (!seen.has(canonical)) {
      seen.set(canonical, output.length);
      output.push(clean);
    } else {
      const index = seen.get(canonical);
      output[index].qty += clean.qty;
    }
  }

  return output;
}

function fallbackInventoryParse(raw) {
  return {
    items: sanitizeInventoryItems(
      parseLooseInventory(raw).map((item) => ({
        ...item,
        unit: 'unidad',
        category: null,
        tags: [],
        suggested: false,
      }))
    ),
  };
}

const VISION_STOP_LABELS = new Set([
  'Person',
  'Human',
  'Face',
  'Man',
  'Woman',
  'Kid',
  'Child',
  'People',
  'Adult',
  'Smile',
  'Head',
  'Hand',
  'Finger',
]);

const VISION_GENERIC = new Set([
  'Product',
  'Products',
  'Object',
  'Indoors',
  'Room',
  'Floor',
  'Table',
  'Furniture',
]);

function labelMatchesItem(canonical, labels) {
  const name = normalizeText(canonical);
  const filtered = (labels || [])
    .filter(
      (item) =>
        item?.name &&
        !VISION_STOP_LABELS.has(item.name) &&
        !VISION_GENERIC.has(item.name)
    )
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  const matched = [];

  for (const label of filtered) {
    const labelName = normalizeText(label.name);
    if (!labelName) continue;

    if (name.includes(labelName) || labelName.includes(name)) {
      matched.push(label.name);
    }

    if (matched.length >= 2) break;
  }

  return [...new Set(matched)];
}

function reconcileInventory(itemsFromText, labels) {
  const items = [];
  const seen = new Map();

  const cleanTextItems = sanitizeInventoryItems(itemsFromText || []);
  const cleanLabels = (labels || [])
    .filter(
      (item) =>
        item?.name &&
        !VISION_STOP_LABELS.has(item.name) &&
        !VISION_GENERIC.has(item.name)
    )
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  for (const item of cleanTextItems) {
    const matched = labelMatchesItem(item.canonical, cleanLabels);

    const outputItem = {
      canonical: item.canonical,
      display: item.display,
      qty: item.qty,
      unit: item.unit ?? 'unidad',
      category: item.category ?? (matched[0] ?? null),
      tags: item.tags ?? [],
      evidence: { text: true, vision: matched.slice(0, 2) },
      confidence: matched.length ? 0.92 : 0.82,
      suggested: false,
    };

    if (!seen.has(outputItem.canonical)) {
      seen.set(outputItem.canonical, items.length);
      items.push(outputItem);
    } else {
      const index = seen.get(outputItem.canonical);
      items[index].qty += outputItem.qty;
    }
  }

  const suggestions = [];
  const used = new Set(
    items.flatMap((item) => (item.evidence?.vision || []).filter(Boolean))
  );

  for (const label of cleanLabels) {
    if (!label?.name) continue;
    if (used.has(label.name)) continue;
    if ((label.confidence || 0) < 88) continue;

    suggestions.push({
      label: label.name,
      confidence: Math.min(
        0.7,
        Math.max(0.55, (label.confidence || 0) / 100)
      ),
    });

    if (suggestions.length >= 6) break;
  }

  return { items, suggestions };
}

async function bedrockInventory(rawText, labels) {
  if (!config.BEDROCK_MODEL_ID) return null;

  const prompt = `Eres un extractor de inventario para un puesto de venta en Bolivia.

TAREA:
- Lee el texto en español y conviértelo en items separados.
- Si el texto dice "10 zapatos, una polera y una botella", deben salir 3 filas:
  - zapato qty 10
  - polera qty 1
  - botella qty 1

REGLAS:
- Devuelve SOLO JSON válido. Sin explicación. Sin markdown.
- No inventes productos.
- Si no hay cantidad, asume 1.
- Normaliza:
  - "tomatodo" o "termo" -> "botella"
  - "camiseta" o "poleras" -> "polera"
  - "botas" -> "bota"
  - "zapatos" -> "zapato"
- Ignora persona/hombre/mujer/niño como producto.

FORMATO:
{
  "items": [
    { "canonical": "string", "display": "string", "qty": number }
  ]
}

Texto:
"""${String(rawText || '').slice(0, 4000)}"""

Labels:
${JSON.stringify(labels || [])}
`;

  const isTitan = config.BEDROCK_MODEL_ID.startsWith('amazon.');

  const body = isTitan
    ? JSON.stringify({
        inputText: prompt,
        textGenerationConfig: {
          maxTokenCount: 700,
          temperature: 0,
          topP: 1,
        },
      })
    : JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 700,
        temperature: 0,
        messages: [{ role: 'user', content: prompt }],
      });

  const response = await bedrock.send(
    new InvokeModelCommand({
      modelId: config.BEDROCK_MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body,
    })
  );

  const raw = Buffer.from(response.body).toString('utf8');
  const parsed = JSON.parse(raw);

  const outputText = isTitan
    ? parsed?.results?.[0]?.outputText || ''
    : parsed?.content?.[0]?.text || '';

  const jsonText = extractJson(outputText);
  if (!jsonText) return null;

  try {
    const output = JSON.parse(jsonText);
    if (output && Array.isArray(output.items)) {
      output.items = sanitizeInventoryItems(output.items);
      return output;
    }
    return null;
  } catch {
    return null;
  }
}

module.exports = {
  fallbackInventoryParse,
  bedrockInventory,
  reconcileInventory,
};