'use strict';

const config = require('../config');
const { ok, bad } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const { QueryCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

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

function normalizeCategory(value) {
  return normalizeText(value);
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

async function listCategories({ caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const profiles = await queryOpenStallProfiles(500);

  const categories = [
    ...new Set(
      profiles
        .map((item) => String(item.category || '').trim())
        .filter(Boolean)
    ),
  ].sort((a, b) => a.localeCompare(b));

  return ok({ categories });
}

async function listOpenStallsNear({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.STALLS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta STALLS_TABLE');
  }

  const query = event?.queryStringParameters || {};

  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);
  const hasLocation = lat !== null && lng !== null;

  const radiusKm = clamp(toNumber(query.radiusKm) ?? 10, 0.1, 50);
  const limit = clamp(toNumber(query.limit) ?? 50, 1, 200);
  const searchText = String(query.q || '').trim();
  const categoryFilter = normalizeCategory(query.category || '');

  const includeProducts = String(query.includeProducts || '0') === '1';
  const productsLimit = clamp(toNumber(query.productsLimit) ?? 6, 1, 20);

  const profiles = await queryOpenStallProfiles(400);
  const radiusMeters = radiusKm * 1000;

  let stalls = profiles
    .map((profile) => {
      const stallLat = toNumber(profile.currentLat);
      const stallLng = toNumber(profile.currentLng);
      const stallName = String(profile.name || '').trim() || 'Puesto';
      const profileCategory = String(profile.category || '').trim() || null;
      const profileDescription =
        String(profile.description || '').trim() || null;

      if (categoryFilter) {
        const currentCategory = normalizeCategory(profileCategory || '');
        if (currentCategory !== categoryFilter) return null;
      }

      const nameScore = searchText
        ? computeStallNameMatchScore(stallName, searchText)
        : 1;

      if (searchText && nameScore <= 0) return null;

      let distanceMeters = null;
      if (
        hasLocation &&
        stallLat !== null &&
        stallLng !== null
      ) {
        distanceMeters = Math.round(
          haversineMeters(lat, lng, stallLat, stallLng)
        );

        if (distanceMeters > radiusMeters) return null;
      }

      return {
        stallId: String(profile.stallId || '').trim(),
        name: stallName,
        category: profileCategory,
        description: profileDescription,
        isOpen: !!profile.currentOpen,
        lat: stallLat,
        lng: stallLng,
        addressLabel: profile.currentAddressLabel ?? null,
        distanceMeters,
        nameScore,
      };
    })
    .filter(Boolean)
    .filter((stall) => stall.stallId)
    .sort((a, b) => {
      if (hasLocation) {
        const aDistance = a.distanceMeters ?? Number.MAX_SAFE_INTEGER;
        const bDistance = b.distanceMeters ?? Number.MAX_SAFE_INTEGER;

        if (aDistance !== bDistance) return aDistance - bDistance;
      }

      if ((b.nameScore || 0) !== (a.nameScore || 0)) {
        return (b.nameScore || 0) - (a.nameScore || 0);
      }

      return String(a.name || '').localeCompare(String(b.name || ''));
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
            Limit: 200,
          })
        );

        const activeProducts = (result.Items || [])
          .map((item) => ({
            productId: item.productId,
            display: item.display,
            canonical: item.canonical,
            category: item.category ?? null,
            description: item.description ?? null,
            price: item.price ?? null,
            active: item.active ?? true,
            lastQty: item.lastQty ?? null,
            lastSeenAt: item.lastSeenAt ?? null,
          }))
          .filter((product) => product.active === true);

        const productsPreview = activeProducts.slice(0, productsLimit);

        const { nameScore, ...cleanStall } = stall;

        return {
          ...cleanStall,
          productsCount: activeProducts.length,
          productsPreview,
        };
      } catch (_) {
        const { nameScore, ...cleanStall } = stall;

        return {
          ...cleanStall,
          productsCount: 0,
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

  const products = (result.Items || [])
    .map((item) => ({
      productId: item.productId,
      canonical: item.canonical,
      display: item.display,
      category: item.category ?? null,
      description: item.description ?? null,
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
    .slice(0, limit)
    .map(({ matchScore, ...product }) => product);

  return ok({
    stallId: id,
    count: products.length,
    products,
  });
}

async function searchProductsNear({ event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const query = event?.queryStringParameters || {};
  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);
  const searchText = String(query.q || '').trim();
  const category = String(query.category || '').trim();

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
        ...(lat !== null ? { lat: String(lat) } : {}),
        ...(lng !== null ? { lng: String(lng) } : {}),
        radiusKm: String(radiusKm),
        limit: '200',
        includeProducts: '0',
        ...(category ? { category } : {}),
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
        Limit: 250,
      })
    );

    const matches = (result.Items || [])
      .map((item) => {
        const product = {
          productId: item.productId,
          display: item.display,
          canonical: item.canonical,
          category: item.category ?? null,
          description: item.description ?? null,
          price: item.price ?? null,
          active: item.active ?? true,
          lastQty: item.lastQty ?? null,
        };

        const matchScore = computeProductMatchScore(product, searchText);

        return {
          stallId,
          stallName: stall.name,
          stallCategory: stall.category ?? null,
          stallDescription: stall.description ?? null,
          distanceMeters: stall.distanceMeters ?? null,
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
    const aDistance = a.distanceMeters ?? Number.MAX_SAFE_INTEGER;
    const bDistance = b.distanceMeters ?? Number.MAX_SAFE_INTEGER;

    if (aDistance !== bDistance) {
      return aDistance - bDistance;
    }

    if (b.matchScore !== a.matchScore) {
      return b.matchScore - a.matchScore;
    }

    return String(a.product.display || '').localeCompare(
      String(b.product.display || '')
    );
  });

  const finalResults = results
    .slice(0, limit)
    .map(({ matchScore, ...row }) => row);

  return ok({
    q: searchText,
    radiusKm,
    count: finalResults.length,
    results: finalResults,
  });
}

async function getStallPublicDetail({ stallId, event, caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (
    !config.STALLS_TABLE ||
    !config.OPENINGLOGS_TABLE ||
    !config.PRODUCTS_TABLE
  ) {
    return bad(500, 'ENV_MISSING', 'Faltan tablas');
  }

  const id = String(stallId || '').trim();
  if (!id) return bad(400, 'VALIDATION', 'stallId requerido');

  const profileResponse = await ddb.send(
    new GetCommand({
      TableName: config.STALLS_TABLE,
      Key: { pk: pkStall(id), sk: 'PROFILE' },
    })
  );

  const stall = profileResponse.Item || null;
  if (!stall) return bad(404, 'NOT_FOUND', 'Puesto no encontrado');

  let opening = null;

  if (stall.currentOpen) {
    const openingResponse = await ddb.send(
      new GetCommand({
        TableName: config.OPENINGLOGS_TABLE,
        Key: { pk: pkStall(id), sk: stall.currentOpen },
      })
    );

    opening = openingResponse.Item || null;
  }

  const productsResponse = await ddb.send(
    new QueryCommand({
      TableName: config.PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(id),
        ':prefix': 'PROD#',
      },
      ScanIndexForward: true,
      Limit: 300,
    })
  );

  const products = (productsResponse.Items || [])
    .map((item) => ({
      productId: item.productId,
      display: item.display,
      canonical: item.canonical,
      category: item.category ?? null,
      description: item.description ?? null,
      price: item.price ?? null,
      active: item.active ?? true,
      lastQty: item.lastQty ?? null,
      lastSeenAt: item.lastSeenAt ?? null,
    }))
    .filter((product) => product.active === true)
    .sort((a, b) =>
      String(a.display || '').localeCompare(String(b.display || ''))
    );

  const query = event?.queryStringParameters || {};
  const lat = toNumber(query.lat);
  const lng = toNumber(query.lng);

  let distanceMeters = null;

  if (
    lat !== null &&
    lng !== null &&
    stall.currentLat != null &&
    stall.currentLng != null
  ) {
    distanceMeters = Math.round(
      haversineMeters(lat, lng, Number(stall.currentLat), Number(stall.currentLng))
    );
  }

  return ok({
    stall: {
      stallId: stall.stallId,
      name: stall.name,
      category: stall.category ?? null,
      description: stall.description ?? null,
      isOpen: !!stall.currentOpen,
      lat: stall.currentLat ?? null,
      lng: stall.currentLng ?? null,
      addressLabel: stall.currentAddressLabel ?? null,
      distanceMeters,
    },
    opening: opening
      ? {
          status: opening.status,
          openedAt: opening.openedAt,
          addressLabel: opening.addressLabel ?? null,
          stallPhotoKey: opening.stallPhotoKey ?? null,
          productsPhotoKey: opening.productsPhotoKey ?? null,
        }
      : null,
    productsCount: products.length,
    products,
  });
}

module.exports = {
  listCategories,
  listOpenStallsNear,
  listStallProductsPublic,
  searchProductsNear,
  getStallPublicDetail,
};