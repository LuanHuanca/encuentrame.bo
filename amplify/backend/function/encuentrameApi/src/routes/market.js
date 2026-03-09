'use strict';

const config = require('../config');
const { ok, bad } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const { QueryCommand } = require('@aws-sdk/lib-dynamodb');

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const earthRadius = 6371000;
  const toRadians = (degrees) => (degrees * Math.PI) / 180;

  const deltaLat = toRadians(lat2 - lat1);
  const deltaLng = toRadians(lng2 - lng1);

  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(deltaLng / 2) ** 2;

  return 2 * earthRadius * Math.asin(Math.sqrt(a));
}

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function singularizeToken(token) {
  const text = String(token || '').trim();
  if (!text) return '';

  if (text.length > 4 && text.endsWith('es')) {
    return text.slice(0, -2);
  }

  if (text.length > 3 && text.endsWith('s')) {
    return text.slice(0, -1);
  }

  return text;
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function buildVariants(value) {
  const normalized = normalizeText(value);
  if (!normalized) return [];

  const tokens = normalized.split(' ').filter(Boolean);
  const singularTokens = tokens.map(singularizeToken);

  return unique([
    normalized,
    normalized.replace(/\s+/g, ''),
    singularTokens.join(' '),
    singularTokens.join(''),
  ]);
}

function tokenSet(value) {
  return unique(buildVariants(value).flatMap((variant) => variant.split(' ')));
}

function computeTextMatchScore(targetText, queryText) {
  const targetVariants = buildVariants(targetText);
  const queryVariants = buildVariants(queryText);

  if (!targetVariants.length || !queryVariants.length) return 0;

  for (const queryVariant of queryVariants) {
    for (const targetVariant of targetVariants) {
      if (targetVariant === queryVariant) return 100;
    }
  }

  for (const queryVariant of queryVariants) {
    for (const targetVariant of targetVariants) {
      if (targetVariant.startsWith(queryVariant)) return 90;
    }
  }

  const targetTokens = tokenSet(targetText);
  const queryTokens = tokenSet(queryText);

  if (
    queryTokens.length > 0 &&
    queryTokens.every((queryToken) =>
      targetTokens.some((targetToken) => targetToken === queryToken)
    )
  ) {
    return 82;
  }

  if (
    queryTokens.length > 0 &&
    queryTokens.every((queryToken) =>
      targetTokens.some(
        (targetToken) =>
          targetToken.startsWith(queryToken) ||
          targetToken.includes(queryToken)
      )
    )
  ) {
    return 74;
  }

  for (const queryVariant of queryVariants) {
    for (const targetVariant of targetVariants) {
      if (targetVariant.includes(queryVariant)) return 64;
    }
  }

  if (
    queryTokens.some((queryToken) =>
      targetTokens.some((targetToken) => targetToken.includes(queryToken))
    )
  ) {
    return 54;
  }

  return 0;
}

function computeProductMatchScore(product, queryText) {
  const display = String(product?.display || '');
  const canonical = String(product?.canonical || '');

  return Math.max(
    computeTextMatchScore(display, queryText),
    computeTextMatchScore(canonical, queryText)
  );
}

function computeStallNameMatchScore(stallName, queryText) {
  return computeTextMatchScore(stallName, queryText);
}

async function queryOpenStallProfiles(maxItems) {
  if (!config.STALLS_TABLE) return [];

  const items = [];
  let exclusiveStartKey;

  while (items.length < maxItems) {
    const page = await ddb.send(
      new QueryCommand({
        TableName: config.STALLS_TABLE,
        IndexName: 'gsi1',
        KeyConditionExpression: 'gsi1pk = :partition',
        ExpressionAttributeValues: {
          ':partition': 'OPEN',
        },
        ScanIndexForward: false,
        Limit: Math.min(100, maxItems - items.length),
        ExclusiveStartKey: exclusiveStartKey,
      })
    );

    items.push(...(page.Items || []));
    exclusiveStartKey = page.LastEvaluatedKey;

    if (!exclusiveStartKey) break;
  }

  return items;
}

async function listOpenStallsNear({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const query = event?.queryStringParameters || {};
  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);

  if (lat === null || lng === null) {
    return bad(400, 'VALIDATION', 'lat y lng son requeridos');
  }

  if (!config.STALLS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  }

  const radiusKm = clamp(toNumber(query.radiusKm) ?? 10, 0.1, 50);
  const limit = clamp(toNumber(query.limit) ?? 100, 1, 200);
  const searchText = String(query.q || '').trim();

  const includeProducts = String(query.includeProducts || '0') === '1';
  const productsLimit = clamp(toNumber(query.productsLimit) ?? 6, 1, 20);

  const profiles = await queryOpenStallProfiles(400);
  const radiusMeters = radiusKm * 1000;

  let stalls = profiles
    .map((profile) => {
      const stallLat = toNumber(profile.currentLat);
      const stallLng = toNumber(profile.currentLng);

      if (stallLat === null || stallLng === null) return null;

      const stallName = String(profile.name || '').trim() || 'Puesto';
      const nameScore = searchText
        ? computeStallNameMatchScore(stallName, searchText)
        : 1;

      if (searchText && nameScore <= 0) return null;

      const distanceMeters = haversineMeters(
        lat,
        lng,
        stallLat,
        stallLng
      );

      return {
        stallId: String(profile.stallId || '').trim(),
        name: stallName,
        isOpen: !!profile.currentOpen,
        lat: stallLat,
        lng: stallLng,
        addressLabel: profile.currentAddressLabel ?? null,
        distanceMeters: Math.round(distanceMeters),
        nameScore,
      };
    })
    .filter(Boolean)
    .filter((stall) => stall.stallId && stall.distanceMeters <= radiusMeters)
    .sort((a, b) => {
      if (a.distanceMeters !== b.distanceMeters) {
        return a.distanceMeters - b.distanceMeters;
      }
      return (b.nameScore || 0) - (a.nameScore || 0);
    })
    .slice(0, limit);

  if (!includeProducts || !config.PRODUCTS_TABLE || stalls.length === 0) {
    return ok({
      radiusKm,
      count: stalls.length,
      stalls: stalls.map(({ nameScore, ...stall }) => stall),
    });
  }

  const stallsWithProducts = await Promise.all(
    stalls.map(async (stall) => {
      try {
        const result = await ddb.send(
          new QueryCommand({
            TableName: config.PRODUCTS_TABLE,
            KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
            ExpressionAttributeValues: {
              ':pk': pkStall(stall.stallId),
              ':prefix': 'PROD#',
            },
            ScanIndexForward: true,
            Limit: 80,
          })
        );

        const productsPreview = (result.Items || [])
          .map((item) => ({
            productId: item.productId,
            display: item.display,
            canonical: item.canonical,
            price: item.price ?? null,
            active: item.active ?? true,
            lastQty: item.lastQty ?? null,
            lastSeenAt: item.lastSeenAt ?? null,
          }))
          .filter((product) => product.active === true)
          .slice(0, productsLimit);

        const { nameScore, ...stallClean } = stall;

        return {
          ...stallClean,
          productsPreview,
        };
      } catch (_) {
        const { nameScore, ...stallClean } = stall;

        return {
          ...stallClean,
          productsPreview: [],
        };
      }
    })
  );

  return ok({
    radiusKm,
    count: stallsWithProducts.length,
    stalls: stallsWithProducts,
  });
}

async function listStallProductsPublic({ stallId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const id = String(stallId || '').trim();
  if (!id) return bad(400, 'VALIDATION', 'stallId requerido');

  if (!config.PRODUCTS_TABLE) {
    return ok({
      stallId: id,
      count: 0,
      products: [],
    });
  }

  const query = event?.queryStringParameters || {};
  const searchText = String(query.q || '').trim();
  const limit = clamp(toNumber(query.limit) ?? 100, 1, 200);

  const result = await ddb.send(
    new QueryCommand({
      TableName: config.PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(id),
        ':prefix': 'PROD#',
      },
      ScanIndexForward: true,
      Limit: 250,
    })
  );

  let products = (result.Items || [])
    .map((item) => ({
      productId: item.productId,
      canonical: item.canonical,
      display: item.display,
      price: item.price ?? null,
      active: item.active ?? true,
      lastQty: item.lastQty ?? null,
      lastSeenAt: item.lastSeenAt ?? null,
      matchScore: searchText ? computeProductMatchScore(item, searchText) : 1,
    }))
    .filter((product) => product.active === true)
    .filter((product) => !searchText || product.matchScore > 0)
    .sort((a, b) => {
      if (b.matchScore !== a.matchScore) {
        return b.matchScore - a.matchScore;
      }
      return String(a.display || '').localeCompare(String(b.display || ''));
    })
    .slice(0, limit);

  return ok({
    stallId: id,
    count: products.length,
    products: products.map(({ matchScore, ...product }) => product),
  });
}

async function searchProductsNear({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const query = event?.queryStringParameters || {};
  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);
  const searchText = String(query.q || '').trim();

  if (lat === null || lng === null) {
    return bad(400, 'VALIDATION', 'lat y lng son requeridos');
  }

  if (!searchText) {
    return bad(400, 'VALIDATION', 'q es requerido');
  }

  if (!config.PRODUCTS_TABLE) {
    return ok({
      q: searchText,
      radiusKm: 10,
      count: 0,
      results: [],
    });
  }

  const radiusKm = clamp(toNumber(query.radiusKm) ?? 10, 0.1, 50);
  const limit = clamp(toNumber(query.limit) ?? 100, 1, 300);

  const openResponse = await listOpenStallsNear({
    event: {
      queryStringParameters: {
        lat: String(lat),
        lng: String(lng),
        radiusKm: String(radiusKm),
        limit: '200',
        includeProducts: '0',
      },
    },
    caller,
  });

  if (openResponse.statusCode >= 400) {
    return openResponse;
  }

  const openBody = JSON.parse(openResponse.body || '{}');
  const stalls = (openBody.stalls || []).slice(0, 200);

  const results = [];

  for (const stall of stalls) {
    const stallId = String(stall.stallId || '').trim();
    if (!stallId) continue;

    const result = await ddb.send(
      new QueryCommand({
        TableName: config.PRODUCTS_TABLE,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
        ExpressionAttributeValues: {
          ':pk': pkStall(stallId),
          ':prefix': 'PROD#',
        },
        ScanIndexForward: true,
        Limit: 200,
      })
    );

    const matches = (result.Items || [])
      .map((item) => {
        const product = {
          productId: item.productId,
          display: item.display,
          canonical: item.canonical,
          price: item.price ?? null,
          active: item.active ?? true,
          lastQty: item.lastQty ?? null,
        };

        const matchScore = computeProductMatchScore(product, searchText);

        return {
          stallId,
          stallName: stall.name,
          distanceMeters: stall.distanceMeters,
          addressLabel: stall.addressLabel ?? null,
          lat: stall.lat,
          lng: stall.lng,
          matchScore,
          product,
        };
      })
      .filter((row) => row.product.active === true)
      .filter((row) => row.matchScore > 0);

    results.push(...matches);
  }

  results.sort((a, b) => {
    if (a.distanceMeters !== b.distanceMeters) {
      return a.distanceMeters - b.distanceMeters;
    }

    if (b.matchScore !== a.matchScore) {
      return b.matchScore - a.matchScore;
    }

    return String(a.product.display || '').localeCompare(
      String(b.product.display || '')
    );
  });

  const finalResults = results.slice(0, limit).map(({ matchScore, ...row }) => row);

  return ok({
    q: searchText,
    radiusKm,
    count: finalResults.length,
    results: finalResults,
  });
}

module.exports = {
  listOpenStallsNear,
  listStallProductsPublic,
  searchProductsNear,
};