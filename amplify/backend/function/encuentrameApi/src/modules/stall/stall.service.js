'use strict';

const { env } = require('../../shared/config/env');
const { AppError } = require('../../shared/errors/app-error');
const { logger } = require('../../shared/logging/logger');
const mapper = require('./stall.mapper');
const repository = require('./stall.repository');
const {
  requireAuthenticated,
  validateStallId,
  validateCreateStallInput,
  validateUpdateStallInput,
  validateOpenStallInput,
  validateListOpeningsQuery,
} = require('./stall.validator');
const {
  normalizeS3Key,
  fallbackInventoryParse,
  sanitizeInventoryItems,
  reconcileInventory,
  slugify,
} = require('./stall.inventory');
const {
  detectLabelsFromS3Key,
  detectModerationFromS3Key,
  isResourceNotFound,
} = require('../../integrations/vision/rekognition.service');
const { reverseGeocode } = require('../../integrations/geo/location.service');
const { extractInventory } = require('../../integrations/ai/bedrock.service');

function nowIso() {
  return new Date().toISOString();
}

function ensureStallsEnv() {
  if (!env.STALLS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta STALLS_TABLE',
      statusCode: 500,
    });
  }
}

function ensureOpenEnv() {
  if (!env.STALLS_TABLE || !env.OPENINGLOGS_TABLE || !env.BUCKET_NAME) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Faltan env vars (tables/bucket)',
      statusCode: 500,
    });
  }
}

function awsDetails(error) {
  return {
    name: error?.name,
    status: error?.$metadata?.httpStatusCode,
  };
}

async function upsertProductsFromInventory({ stallId, items, now }) {
  if (!env.PRODUCTS_TABLE) return;
  if (!items?.length) return;

  const queue = items.slice(0, 50);
  const worker = async () => {
    while (queue.length) {
      const item = queue.shift();
      const productId = slugify(item?.canonical);
      if (!productId) continue;

      await repository.upsertProduct({
        stallId,
        productId,
        canonical: item.canonical,
        display: item.display || item.canonical,
        category: item.category ?? null,
        tags: item.tags ?? [],
        qty: item.qty ?? 1,
        now,
      });
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(5, queue.length) }, () => worker())
  );
}

function idempotencyConflict(message, code = 'OPEN_IN_PROGRESS') {
  return new AppError({ code, message, statusCode: 409 });
}

async function resolveExistingOpenRequest({ stallId, userId, idempotencyKey }) {
  const request = await repository.getOpenRequest(stallId, idempotencyKey);

  if (!request) {
    throw idempotencyConflict('Otra apertura está en proceso');
  }
  if (request.userId !== userId) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'La solicitud no pertenece al usuario autenticado',
      statusCode: 403,
    });
  }
  if (request.status === 'COMPLETED' && request.response) {
    return request.response;
  }
  if (request.status === 'PROCESSING') {
    throw idempotencyConflict('La apertura todavía está en proceso');
  }

  throw idempotencyConflict(
    'La solicitud anterior falló; vuelve a intentar',
    'OPEN_REQUEST_FAILED'
  );
}

function mapOwnedStall(profile, link) {
  const source = profile || link || {};

  return {
    stallId: source.stallId || '',
    vendorUserId: source.vendorUserId || null,
    name: source.name || 'Mi puesto',
    category: source.category || '',
    description: source.description || '',
    mainPhotoKey: source.mainPhotoKey || '',
    coverPhotoKey: source.coverPhotoKey || '',
    paymentMethods: Array.isArray(source.paymentMethods) ? source.paymentMethods : [],
    priceRange: source.priceRange || null,
    referenceText: source.referenceText || null,
    schedule: Array.isArray(source.schedule) ? source.schedule : [],
    locationVisibility: source.locationVisibility || 'exact',
    active: source.active ?? true,
    createdAt: source.createdAt || null,
    updatedAt: source.updatedAt || null,
    isOpen: !!source.currentOpen,
    currentOpen: source.currentOpen || null,
    currentLat: source.currentLat ?? null,
    currentLng: source.currentLng ?? null,
    currentAddressLabel: source.currentAddressLabel ?? null,
  };
}

async function listMine(currentUser) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const links = await repository.findUserStallLinks(currentUser.userId);

  if (!links.length) {
    return mapper.toListMineResponse([]);
  }

  const profiles = await repository.batchGetProfiles(
    links.map((item) => item.stallId)
  );

  const profileMap = profiles.reduce((acc, item) => {
    if (item?.stallId) acc[item.stallId] = item;
    return acc;
  }, {});

  const stalls = links.map((link) => mapOwnedStall(profileMap[link.stallId], link));

  return mapper.toListMineResponse(stalls);
}

async function create(currentUser, payload) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const existing = await repository.findFirstOwnedStall(currentUser.userId);
  if (existing) {
    throw new AppError({
      code: 'STALL_ALREADY_EXISTS',
      message: 'Ya tienes un puesto creado',
      statusCode: 409,
    });
  }

  const input = validateCreateStallInput(payload);
  const now = nowIso();

  const stall = await repository.createStall({
    userId: currentUser.userId,
    name: input.name,
    category: input.category,
    description: input.description,
    mainPhotoKey: input.mainPhotoKey,
    coverPhotoKey: input.coverPhotoKey,
    paymentMethods: input.paymentMethods,
    priceRange: input.priceRange,
    referenceText: input.referenceText,
    schedule: input.schedule,
    locationVisibility: input.locationVisibility,
    active: input.active,
    now,
  });

  return mapper.toCreateResponse(stall);
}

async function get(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const stall = await repository.getStallProfile(validStallId);
  return mapper.toGetResponse(mapOwnedStall(stall));
}

async function update(currentUser, stallId, payload) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const current = await repository.getStallProfile(validStallId);
  if (!current) {
    throw new AppError({
      code: 'NOT_FOUND',
      message: 'Puesto no encontrado',
      statusCode: 404,
    });
  }

  const changes = validateUpdateStallInput(payload);

  const merged = {
    name: changes.name !== undefined ? changes.name : current.name || 'Mi puesto',
    category: changes.category !== undefined ? changes.category : current.category || null,
    description:
      changes.description !== undefined ? changes.description : current.description || null,
    mainPhotoKey:
      changes.mainPhotoKey !== undefined ? changes.mainPhotoKey : current.mainPhotoKey || null,
    coverPhotoKey:
      changes.coverPhotoKey !== undefined ? changes.coverPhotoKey : current.coverPhotoKey || null,
    paymentMethods:
      changes.paymentMethods !== undefined
        ? changes.paymentMethods
        : Array.isArray(current.paymentMethods)
          ? current.paymentMethods
          : [],
    priceRange:
      changes.priceRange !== undefined ? changes.priceRange : current.priceRange || null,
    referenceText:
      changes.referenceText !== undefined
        ? changes.referenceText
        : current.referenceText || null,
    schedule:
      changes.schedule !== undefined
        ? changes.schedule
        : Array.isArray(current.schedule)
          ? current.schedule
          : [],
    locationVisibility:
      changes.locationVisibility !== undefined
        ? changes.locationVisibility
        : current.locationVisibility || 'exact',
    active: changes.active !== undefined ? changes.active : current.active ?? true,
  };

  const now = nowIso();

  await repository.updateStallProfile({
    stallId: validStallId,
    userId: currentUser.userId,
    ...merged,
    now,
  });

  const updated = await repository.getStallProfile(validStallId);
  return mapper.toGetResponse(mapOwnedStall(updated));
}

async function remove(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const profile = await repository.getStallProfile(validStallId);
  if (!profile) {
    throw new AppError({
      code: 'NOT_FOUND',
      message: 'Puesto no existe',
      statusCode: 404,
    });
  }

  if (profile.currentOpen) {
    throw new AppError({
      code: 'STALL_OPEN',
      message: 'Cierra el puesto antes de eliminar',
      statusCode: 400,
    });
  }

  await repository.deleteStall(currentUser.userId, validStallId);
  return mapper.toSimpleOk();
}

async function open(currentUser, payload) {
  requireAuthenticated(currentUser);
  ensureOpenEnv();

  const input = validateOpenStallInput(payload, currentUser);

  const owns = await repository.userOwnsStall(currentUser.userId, input.stallId);
  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const stallProfile = await repository.getStallProfile(input.stallId);
  if (!stallProfile) {
    throw new AppError({
      code: 'NOT_FOUND',
      message: 'Puesto no existe',
      statusCode: 404,
    });
  }
  if (stallProfile.active === false) {
    throw new AppError({
      code: 'STALL_INACTIVE',
      message: 'Activa el puesto antes de abrirlo',
      statusCode: 400,
    });
  }

  const existingRequest = await repository.getOpenRequest(
    input.stallId,
    input.idempotencyKey
  );
  if (existingRequest) {
    return resolveExistingOpenRequest({
      stallId: input.stallId,
      userId: currentUser.userId,
      idempotencyKey: input.idempotencyKey,
    });
  }

  if (stallProfile.currentOpen) {
    throw idempotencyConflict(
      'El puesto ya tiene una apertura activa',
      'STALL_ALREADY_OPEN'
    );
  }

  const now = nowIso();
  const openingKey = `OPEN#${now}#${repository.uuid()}`;
  let requestStarted = false;

  try {
    await repository.clearStaleOpenLock(
      input.stallId,
      new Date(Date.now() - 2 * 60 * 1000).toISOString()
    );
    await repository.beginOpenRequest({
      stallId: input.stallId,
      userId: currentUser.userId,
      idempotencyKey: input.idempotencyKey,
      now,
    });
    requestStarted = true;
  } catch (error) {
    if (
      error?.name === 'TransactionCanceledException' ||
      error?.name === 'ConditionalCheckFailedException'
    ) {
      return resolveExistingOpenRequest({
        stallId: input.stallId,
        userId: currentUser.userId,
        idempotencyKey: input.idempotencyKey,
      });
    }
    throw error;
  }

  try {
    const geo = await reverseGeocode(input.lat, input.lng);
    let labels = [];
    let moderation = [];
    let stallPhotoKey = normalizeS3Key(input.stallPhotoKey);
    let productsPhotoKey = normalizeS3Key(input.productsPhotoKey);

    try {
      const [labelsResult, moderationResult] = await Promise.all([
        detectLabelsFromS3Key(productsPhotoKey),
        detectModerationFromS3Key(stallPhotoKey),
      ]);

      labels = labelsResult.labels;
      moderation = moderationResult.moderation;
      productsPhotoKey = labelsResult.keyUsed;
      stallPhotoKey = moderationResult.keyUsed;
    } catch (error) {
      logger.error('REKOGNITION_ERROR', awsDetails(error));

      if (isResourceNotFound(error)) {
        throw new AppError({
          code: 'PHOTO_NOT_FOUND',
          message: 'No se encontró la foto en S3',
          statusCode: 400,
        });
      }

      throw new AppError({
        code: 'REKOGNITION_ERROR',
        message: 'Error procesando las fotos',
        statusCode: 500,
      });
    }

    let inventory = null;
    try {
      inventory = await extractInventory({
        rawText: input.inventoryText,
        labels,
      });
    } catch (error) {
      logger.error('BEDROCK_ERROR', awsDetails(error));
    }

    inventory = inventory
      ? { items: sanitizeInventoryItems(inventory.items) }
      : fallbackInventoryParse(input.inventoryText);

    const reconciled = reconcileInventory(inventory.items, labels);
    if (reconciled.items.length > 50) {
      throw new AppError({
        code: 'TOO_MANY_PRODUCTS',
        message: 'El inventario no puede superar 50 productos',
        statusCode: 400,
      });
    }

    const status = moderation.length > 0 ? 'REVIEW' : 'OPEN';
    const openingItem = {
      entityType: 'OPENING',
      status,
      openedAt: now,
      userId: currentUser.userId,
      idempotencyKey: input.idempotencyKey,
      lat: input.lat,
      lng: input.lng,
      accuracy: input.accuracy,
      addressLabel: geo?.label ?? null,
      address: geo?.address ?? null,
      stallPhotoKey,
      productsPhotoKey,
      rekognitionLabels: labels,
      moderationLabels: moderation,
      inventoryRaw: input.inventoryText,
      inventoryItems: reconciled.items,
      inventorySuggestions: reconciled.suggestions,
    };
    const response = mapper.toOpenResponse({
      stallId: input.stallId,
      openingKey,
      status,
      location: {
        lat: input.lat,
        lng: input.lng,
        accuracy: input.accuracy,
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

    if (status === 'REVIEW') {
      await repository.completeReviewRequest({
        stallId: input.stallId,
        userId: currentUser.userId,
        idempotencyKey: input.idempotencyKey,
        openingKey,
        openingItem,
        response,
        now,
      });
      requestStarted = false;
      return response;
    }

    await repository.completeOpenRequest({
      stallId: input.stallId,
      userId: currentUser.userId,
      idempotencyKey: input.idempotencyKey,
      openingKey,
      openingItem,
      response,
      profile: {
        lat: input.lat,
        lng: input.lng,
        accuracy: input.accuracy,
        addressLabel: geo?.label ?? null,
        address: geo?.address ?? null,
        stallPhotoKey,
        productsPhotoKey,
        inventoryItems: reconciled.items,
        inventorySuggestions: reconciled.suggestions,
      },
      now,
    });
    requestStarted = false;

    try {
      await upsertProductsFromInventory({
        stallId: input.stallId,
        items: reconciled.items,
        now,
      });
    } catch (error) {
      logger.error('PRODUCT_SYNC_ERROR', {
        ...awsDetails(error),
        stallId: input.stallId,
      });
    }

    return response;
  } catch (error) {
    if (requestStarted) {
      await repository.failOpenRequest({
        stallId: input.stallId,
        idempotencyKey: input.idempotencyKey,
        now: nowIso(),
        errorCode: error?.code || error?.name,
      });
    }
    throw error;
  }
}

async function getCurrent(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const stall = await repository.getStallProfile(validStallId);

  let opening = null;
  if (stall?.currentOpen) {
    opening = await repository.getOpening(validStallId, stall.currentOpen);
  } else {
    opening = await repository.getLatestOpening(validStallId);
  }

  return mapper.toGetCurrentResponse({
    stall: mapOwnedStall(stall),
    opening,
  });
}

async function close(currentUser, stallId) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const profile = await repository.getStallProfile(validStallId);
  if (!profile) {
    throw new AppError({
      code: 'NOT_FOUND',
      message: 'Puesto no existe',
      statusCode: 404,
    });
  }

  if (!profile.currentOpen) {
    throw new AppError({
      code: 'NO_OPEN',
      message: 'No hay apertura activa',
      statusCode: 400,
    });
  }

  await repository.closeOpening({
    stallId: validStallId,
    openingKey: profile.currentOpen,
    now: nowIso(),
  });

  return mapper.toSimpleOk();
}

async function listOpenings(currentUser, stallId, query) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const validStallId = validateStallId(stallId);
  const owns = await repository.userOwnsStall(currentUser.userId, validStallId);

  if (!owns) {
    throw new AppError({
      code: 'FORBIDDEN',
      message: 'No es tu puesto',
      statusCode: 403,
    });
  }

  const { limit } = validateListOpeningsQuery(query);
  const openings = await repository.listOpenings(validStallId, limit);

  return mapper.toListOpeningsResponse(openings);
}

async function getMy(currentUser) {
  requireAuthenticated(currentUser);
  ensureStallsEnv();

  const first = await repository.findFirstOwnedStall(currentUser.userId);

  if (!first) {
    return mapper.toGetCurrentResponse({
      stall: null,
      opening: null,
    });
  }

  return getCurrent(currentUser, first.stallId);
}

module.exports = {
  listMine,
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
