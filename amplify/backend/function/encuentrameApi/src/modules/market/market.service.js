'use strict';

const { env } = require('../../shared/config/env');
const { AppError } = require('../../shared/errors/app-error');
const repository = require('./market.repository');
const mapper = require('./market.mapper');
const {
  requireAuthenticated,
  validateNearbyQuery,
  validateSearchProductsQuery,
  validateStallId,
} = require('./market.validator');

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
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

function normalizeCategory(value) {
  return normalizeText(value);
}

async function listCategories(currentUser) {
  requireAuthenticated(currentUser);

  if (!env.STALLS_TABLE) {
    return mapper.toCategoryResponse([]);
  }

  const profiles = await repository.listOpenStallProfiles(400);

  const categories = unique(
    profiles
      .map((item) => String(item.category || '').trim())
      .filter((value) => value.length > 0)
      .sort((a, b) => a.localeCompare(b))
  );

  return mapper.toCategoryResponse(categories);
}

async function listOpenStallsNear({ currentUser, query }) {
  requireAuthenticated(currentUser);

  if (!env.STALLS_TABLE) {
    return mapper.toOpenStallsResponse({
      radiusKm: 10,
      stalls: [],
    });
  }

  const {
    lat,
    lng,
    radiusKm,
    limit,
    includeProducts,
    productsLimit,
    category,
    q,
  } = validateNearbyQuery(query);

  const radiusMeters = radiusKm * 1000;
  const normalizedCategory = normalizeCategory(category);

  const profiles = await repository.listOpenStallProfiles(400);

  let stalls = profiles
    .map((profile) => {
      const stallLat = toNumber(profile.currentLat);
      const stallLng = toNumber(profile.currentLng);

      if (stallLat === null || stallLng === null) return null;

      const stallId = String(profile.stallId || '').trim();
      const name = String(profile.name || '').trim() || 'Puesto';
      const itemCategory = String(profile.category || '').trim();

      if (!stallId) return null;

      if (
        normalizedCategory &&
        normalizeCategory(itemCategory) !== normalizedCategory
      ) {
        return null;
      }

      const distanceMeters = haversineMeters(lat, lng, stallLat, stallLng);
      if (distanceMeters > radiusMeters) return null;

      const nameScore = q ? computeTextMatchScore(name, q) : 1;
      if (q && nameScore <= 0) return null;

      return {
        stallId,
        name,
        category: itemCategory,
        isOpen: !!profile.currentOpen,
        lat: stallLat,
        lng: stallLng,
        addressLabel: profile.currentAddressLabel ?? null,
        distanceMeters: Math.round(distanceMeters),
        coverPhotoKey: profile.coverPhotoKey ?? null,
        nameScore,
      };
    })
    .filter(Boolean)
    .sort((a, b) => {
      if (a.distanceMeters !== b.distanceMeters) {
        return a.distanceMeters - b.distanceMeters;
      }
      return (b.nameScore || 0) - (a.nameScore || 0);
    })
    .slice(0, limit);

  if (!includeProducts || !env.PRODUCTS_TABLE || stalls.length === 0) {
    return mapper.toOpenStallsResponse({
      radiusKm,
      stalls: stalls.map(({ nameScore, ...item }) => item),
    });
  }

  const stallsWithProducts = await Promise.all(
    stalls.map(async (stall) => {
      const items = await repository.listProductsByStallId(stall.stallId, 80);

      const productsPreview = items
        .map((item) => ({
          productId: item.productId,
          display: item.display,
          canonical: item.canonical,
          price: item.price ?? null,
          active: item.active ?? true,
          lastQty: item.lastQty ?? null,
          lastSeenAt: item.lastSeenAt ?? null,
        }))
        .filter((item) => item.active === true)
        .slice(0, productsLimit);

      const { nameScore, ...stallData } = stall;

      return {
        ...stallData,
        productsPreview,
      };
    })
  );

  return mapper.toOpenStallsResponse({
    radiusKm,
    stalls: stallsWithProducts,
  });
}

async function searchProductsNear({ currentUser, query }) {
  requireAuthenticated(currentUser);

  if (!env.PRODUCTS_TABLE) {
    return mapper.toProductSearchResponse({
      q: String(query.q || ''),
      radiusKm: 10,
      results: [],
    });
  }

  const { lat, lng, radiusKm, limit, q, category } =
    validateSearchProductsQuery(query);

  const nearbyStallsResponse = await listOpenStallsNear({
    currentUser,
    query: {
      lat: String(lat),
      lng: String(lng),
      radiusKm: String(radiusKm),
      limit: '200',
      includeProducts: '0',
      category,
    },
  });

  const stalls = nearbyStallsResponse.stalls || [];
  const results = [];

  for (const stall of stalls) {
    const items = await repository.listProductsByStallId(stall.stallId, 200);

    const matches = items
      .map((item) => {
        const product = {
          productId: item.productId,
          display: item.display,
          canonical: item.canonical,
          price: item.price ?? null,
          active: item.active ?? true,
          lastQty: item.lastQty ?? null,
          lastSeenAt: item.lastSeenAt ?? null,
        };

        const matchScore = computeProductMatchScore(product, q);

        return {
          stallId: stall.stallId,
          stallName: stall.name,
          category: stall.category ?? '',
          addressLabel: stall.addressLabel ?? null,
          lat: stall.lat,
          lng: stall.lng,
          distanceMeters: stall.distanceMeters,
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

  const finalResults = results
    .slice(0, limit)
    .map(({ matchScore, ...item }) => item);

  return mapper.toProductSearchResponse({
    q,
    radiusKm,
    results: finalResults,
  });
}

async function getPublicStallDetail({ currentUser, stallId }) {
  requireAuthenticated(currentUser);

  if (!env.STALLS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta STALLS_TABLE',
      statusCode: 500,
    });
  }

  const validStallId = validateStallId(stallId);
  const profile = await repository.getStallProfile(validStallId);

  if (!profile) {
    throw new AppError({
      code: 'NOT_FOUND',
      message: 'Puesto no encontrado',
      statusCode: 404,
    });
  }

  const products = env.PRODUCTS_TABLE
    ? await repository.listProductsByStallId(validStallId, 200)
    : [];

  const activeProducts = products
    .map((item) => ({
      productId: item.productId,
      display: item.display,
      canonical: item.canonical,
      price: item.price ?? null,
      active: item.active ?? true,
      lastQty: item.lastQty ?? null,
      lastSeenAt: item.lastSeenAt ?? null,
    }))
    .filter((item) => item.active === true);

  return mapper.toPublicStallDetailResponse({
    stall: {
      stallId: profile.stallId,
      name: profile.name || 'Puesto',
      category: profile.category || '',
      description: profile.description || '',
      isOpen: !!profile.currentOpen,
      lat: profile.currentLat ?? null,
      lng: profile.currentLng ?? null,
      addressLabel: profile.currentAddressLabel ?? null,
      coverPhotoKey: profile.coverPhotoKey ?? null,
      vendorUserId: profile.vendorUserId ?? null,
      updatedAt: profile.updatedAt ?? null,
    },
    products: activeProducts,
  });
}

async function listPublicStallProducts({ currentUser, stallId, query }) {
  requireAuthenticated(currentUser);

  if (!env.PRODUCTS_TABLE) {
    return mapper.toPublicStallProductsResponse({
      stallId: validateStallId(stallId),
      products: [],
    });
  }

  const validStallId = validateStallId(stallId);
  const q = String(query.q || '').trim();
  const limit = Math.max(1, Math.min(Number(query.limit || 100), 200));

  const items = await repository.listProductsByStallId(validStallId, 250);

  const products = items
    .map((item) => ({
      productId: item.productId,
      canonical: item.canonical,
      display: item.display,
      price: item.price ?? null,
      active: item.active ?? true,
      lastQty: item.lastQty ?? null,
      lastSeenAt: item.lastSeenAt ?? null,
      matchScore: q ? computeProductMatchScore(item, q) : 1,
    }))
    .filter((item) => item.active === true)
    .filter((item) => !q || item.matchScore > 0)
    .sort((a, b) => {
      if (b.matchScore !== a.matchScore) {
        return b.matchScore - a.matchScore;
      }
      return String(a.display || '').localeCompare(String(b.display || ''));
    })
    .slice(0, limit)
    .map(({ matchScore, ...item }) => item);

  return mapper.toPublicStallProductsResponse({
    stallId: validStallId,
    products,
  });
}

module.exports = {
  listCategories,
  listOpenStallsNear,
  searchProductsNear,
  getPublicStallDetail,
  listPublicStallProducts,
};