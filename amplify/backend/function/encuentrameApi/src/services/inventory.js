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

function fallbackInventoryParse(raw) {
  const parts = String(raw || '').split(',').map(x => x.trim()).filter(Boolean);
  const items = [];
  for (const p of parts) {
    const m = p.match(/^(\d+)\s+(.*)$/);
    if (m) {
      items.push({ canonical: m[2].trim(), display: m[2].trim(), qty: Number(m[1]), unit: 'unidad', category: null, tags: [], suggested: false });
    } else {
      items.push({ canonical: p, display: p, qty: 1, unit: 'unidad', category: null, tags: [], suggested: false });
    }
  }
  return { items };
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
  ['gafas', 'gafas de sol']
];

const LABEL_SYNONYMS = [
  { label: 'Bottle', words: ['botella','tomatodo','termo','vaso','shaker'] },
  { label: 'Clothing', words: ['ropa','polera','camiseta','pantalón','pantalones'] },
  { label: 'Sunglasses', words: ['gafas de sol','lentes de sol'] },
  { label: 'Plate', words: ['plato','platos'] },
  { label: 'Deodorant', words: ['desodorante'] }
];

function normalizeCanonical(s) {
  const x = String(s || '').toLowerCase().trim();
  if (!x) return '';
  for (const [a, b] of CANON_MAP) {
    if (x === a) return b;
  }
  return x;
}

function isNonProduct(canonical) {
  const x = String(canonical || '').toLowerCase();
  return ['hombre','mujer','persona','personas','gente','niño','niña','adulto','adultos'].includes(x);
}

function labelMatchesItem(canonical, labels) {
  const name = canonical.toLowerCase();
  const matched = [];

  const filtered = (labels || []).filter(l => l?.name && !VISION_STOP_LABELS.has(l.name));

  for (const l of filtered) {
    const ln = String(l.name || '').toLowerCase();
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
  const seen = new Map();

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

    const ln = String(l.name).toLowerCase();
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

async function bedrockInventory(rawText, labels) {
  if (!config.BEDROCK_MODEL_ID) return null;

  const prompt =
`Eres un extractor de inventario para un puesto de venta en Bolivia.
Entrada: texto hablado (español) + labels de Rekognition (evidencia visual).
Objetivo: devolver un inventario estructurado.

REGLAS:
- Devuelve SOLO JSON válido, sin explicación.
- Respeta cantidades del texto.
- Normaliza: "tomatodo" -> "botella", "polera/camiseta" -> "polera", "gafas/lentes" -> "gafas de sol".
- No inventes productos.
- "persona/hombre/mujer" no es producto.

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
"""${String(rawText || '').slice(0, 4000)}"""

Labels:
${JSON.stringify(labels || [])}
`;

  const isTitan = config.BEDROCK_MODEL_ID.startsWith('amazon.');

  const body = isTitan
    ? JSON.stringify({ inputText: prompt, textGenerationConfig: { maxTokenCount: 700, temperature: 0, topP: 1 } })
    : JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 700,
        temperature: 0,
        messages: [{ role: 'user', content: prompt }]
      });

  const res = await bedrock.send(new InvokeModelCommand({
    modelId: config.BEDROCK_MODEL_ID,
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

module.exports = {
  fallbackInventoryParse,
  bedrockInventory,
  reconcileInventory
};