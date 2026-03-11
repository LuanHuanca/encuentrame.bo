'use strict';

const { normalizeS3Key, candidateKeys } = require('../../integrations/storage/s3-paths');

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
  'Clothing',
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
  ['botas', 'bota'],
];

function normalizeCanonical(value) {
  const input = String(value || '').toLowerCase().trim();
  if (!input) return '';

  for (const [from, to] of CANON_MAP) {
    if (input === from) return to;
  }

  return input;
}

function isNonProduct(canonical) {
  const input = String(canonical || '').toLowerCase();
  return [
    'hombre',
    'mujer',
    'persona',
    'personas',
    'gente',
    'niño',
    'niña',
    'adulto',
    'adultos',
  ].includes(input);
}

function spanishWordToNumber(word) {
  const input = String(word || '').toLowerCase().trim();
  const dictionary = {
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
    dieciséis: 16,
    diecisiete: 17,
    dieciocho: 18,
    diecinueve: 19,
    veinte: 20,
  };

  return dictionary[input] ?? null;
}

function parseLooseInventory(raw) {
  const text = String(raw || '')
    .replace(/\s+/g, ' ')
    .replace(/\s+y\s+/gi, ', ')
    .replace(/\s+e\s+/gi, ', ')
    .trim();

  if (!text) return [];

  const parts = text.split(',').map((item) => item.trim()).filter(Boolean);
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
      const number = spanishWordToNumber(wordMatch[1]);
      if (number != null) {
        items.push({
          canonical: wordMatch[2].trim(),
          display: wordMatch[2].trim(),
          qty: number,
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

function fallbackInventoryParse(raw) {
  return {
    items: parseLooseInventory(raw).map((item) => ({
      canonical: item.canonical,
      display: item.display,
      qty: item.qty,
      unit: 'unidad',
      category: null,
      tags: [],
      suggested: false,
    })),
  };
}

function sanitizeInventoryItems(items) {
  const out = [];
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

    const normalized = {
      canonical,
      display,
      qty,
      unit: item?.unit ?? 'unidad',
      category: item?.category ?? null,
      tags: Array.isArray(item?.tags) ? item.tags : [],
      suggested: !!item?.suggested,
    };

    if (!seen.has(canonical)) {
      seen.set(canonical, out.length);
      out.push(normalized);
    } else {
      out[seen.get(canonical)].qty += normalized.qty;
    }
  }

  return out;
}

function labelMatchesItem(canonical, labels) {
  const name = canonical.toLowerCase();

  const filtered = (labels || [])
    .filter(
      (label) =>
        label?.name &&
        !VISION_STOP_LABELS.has(label.name) &&
        !VISION_GENERIC.has(label.name)
    )
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  const matched = [];

  for (const label of filtered) {
    const labelName = String(label.name || '').toLowerCase();
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
      (label) =>
        label?.name &&
        !VISION_STOP_LABELS.has(label.name) &&
        !VISION_GENERIC.has(label.name)
    )
    .sort((a, b) => (b.confidence || 0) - (a.confidence || 0));

  for (const item of cleanTextItems) {
    const matched = labelMatchesItem(item.canonical, cleanLabels);

    const normalized = {
      canonical: item.canonical,
      display: item.display,
      qty: item.qty,
      unit: item.unit ?? 'unidad',
      category: item.category ?? (matched[0] ?? null),
      tags: item.tags ?? [],
      evidence: {
        text: true,
        vision: matched.slice(0, 2),
      },
      confidence: matched.length ? 0.92 : 0.82,
      suggested: false,
    };

    if (!seen.has(normalized.canonical)) {
      seen.set(normalized.canonical, items.length);
      items.push(normalized);
    } else {
      items[seen.get(normalized.canonical)].qty += normalized.qty;
    }
  }

  const suggestions = [];
  const used = new Set(
    items.flatMap((item) => item.evidence?.vision || []).filter(Boolean)
  );

  for (const label of cleanLabels) {
    if (!label?.name) continue;
    if (used.has(label.name)) continue;
    if ((label.confidence || 0) < 88) continue;

    suggestions.push({
      label: label.name,
      confidence: Math.min(0.7, Math.max(0.55, (label.confidence || 0) / 100)),
    });

    if (suggestions.length >= 6) break;
  }

  return {
    items,
    suggestions,
  };
}

module.exports = {
  normalizeS3Key,
  candidateKeys,
  slugify,
  fallbackInventoryParse,
  sanitizeInventoryItems,
  reconcileInventory,
};