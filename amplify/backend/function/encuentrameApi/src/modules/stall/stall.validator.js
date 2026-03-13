'use strict';

const { AppError } = require('../../shared/errors/app-error');

const PAYMENT_METHOD_MAP = {
  efectivo: 'cash',
  cash: 'cash',
  qr: 'qr',
  transferencia: 'transfer',
  transfer: 'transfer',
};

const PRICE_RANGE_MAP = {
  economic: 'economic',
  economico: 'economic',
  económico: 'economic',
  medio: 'medium',
  medium: 'medium',
  premium: 'premium',
};

const LOCATION_VISIBILITY_MAP = {
  exact: 'exact',
  exacta: 'exact',
  approximate: 'approximate',
  aproximada: 'approximate',
};

const DAY_MAP = {
  mon: 'mon',
  monday: 'mon',
  lunes: 'mon',

  tue: 'tue',
  tuesday: 'tue',
  martes: 'tue',

  wed: 'wed',
  wednesday: 'wed',
  miercoles: 'wed',
  miércoles: 'wed',

  thu: 'thu',
  thursday: 'thu',
  jueves: 'thu',

  fri: 'fri',
  friday: 'fri',
  viernes: 'fri',

  sat: 'sat',
  saturday: 'sat',
  sabado: 'sat',
  sábado: 'sat',

  sun: 'sun',
  sunday: 'sun',
  domingo: 'sun',
};

function throwValidation(message) {
  throw new AppError({
    code: 'VALIDATION',
    message,
    statusCode: 400,
  });
}

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
}

function requireAuthenticated(currentUser) {
  if (!currentUser?.userId) {
    throw new AppError({
      code: 'UNAUTHORIZED',
      message: 'No autenticado',
      statusCode: 401,
    });
  }
}

function validateStallId(stallId) {
  const value = String(stallId || '').trim();

  if (!value) {
    throwValidation('stallId requerido');
  }

  return value;
}

function normalizeRequiredText(value, fieldName, { min = 1, max = 80 } = {}) {
  const text = String(value || '').trim();

  if (!text) {
    throwValidation(`${fieldName} requerido`);
  }

  if (text.length < min) {
    throwValidation(`${fieldName} no válido`);
  }

  if (text.length > max) {
    throwValidation(`${fieldName} demasiado largo`);
  }

  return text;
}

function normalizeOptionalText(value, fieldName, { max = 240 } = {}) {
  const text = String(value || '').trim();

  if (!text) {
    return null;
  }

  if (text.length > max) {
    throwValidation(`${fieldName} demasiado largo`);
  }

  return text;
}

function normalizeBoolean(value, defaultValue = true) {
  if (value === undefined) {
    return defaultValue;
  }

  return !!value;
}

function normalizePaymentMethods(value, { required = false } = {}) {
  if (value === undefined) {
    return required ? [] : undefined;
  }

  if (value === null) {
    return [];
  }

  if (!Array.isArray(value)) {
    throwValidation('paymentMethods debe ser un arreglo');
  }

  const normalized = [
    ...new Set(
      value
        .map((item) => String(item || '').trim().toLowerCase())
        .filter(Boolean)
        .map((item) => PAYMENT_METHOD_MAP[item])
        .filter(Boolean)
    ),
  ];

  if (value.length > 0 && normalized.length === 0) {
    throwValidation('Métodos de pago no válidos');
  }

  if (normalized.length > 3) {
    throwValidation('Máximo 3 métodos de pago');
  }

  return normalized;
}

function normalizePriceRange(value, { required = false } = {}) {
  if (value === undefined) {
    return required ? null : undefined;
  }

  if (value === null || value === '') {
    return null;
  }

  const normalized = PRICE_RANGE_MAP[String(value).trim().toLowerCase()];

  if (!normalized) {
    throwValidation('priceRange no válido');
  }

  return normalized;
}

function normalizeLocationVisibility(value, { required = false } = {}) {
  if (value === undefined) {
    return required ? 'exact' : undefined;
  }

  if (value === null || value === '') {
    return null;
  }

  const normalized =
    LOCATION_VISIBILITY_MAP[String(value).trim().toLowerCase()];

  if (!normalized) {
    throwValidation('locationVisibility no válido');
  }

  return normalized;
}

function isValidHourMinute(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value || '').trim());
}

function normalizeSchedule(value, { required = false } = {}) {
  if (value === undefined) {
    return required ? [] : undefined;
  }

  if (value === null) {
    return [];
  }

  if (!Array.isArray(value)) {
    throwValidation('schedule debe ser un arreglo');
  }

  if (value.length > 7) {
    throwValidation('Máximo 7 horarios');
  }

  const usedDays = new Set();

  const normalized = value.map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throwValidation('Cada horario debe ser un objeto válido');
    }

    const rawDay = String(item.day || '').trim().toLowerCase();
    const day = DAY_MAP[rawDay];

    if (!day) {
      throwValidation('Día no válido en schedule');
    }

    if (usedDays.has(day)) {
      throwValidation('No repitas días en schedule');
    }

    usedDays.add(day);

    const from = String(item.from || '').trim();
    const to = String(item.to || '').trim();

    if (!isValidHourMinute(from) || !isValidHourMinute(to)) {
      throwValidation('Horario no válido. Usa formato HH:mm');
    }

    if (from >= to) {
      throwValidation('La hora inicial debe ser menor a la final');
    }

    return {
      day,
      from,
      to,
    };
  });

  return normalized;
}

function validateCreateStallInput(payload = {}) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throwValidation('Body inválido');
  }

  return {
    name: normalizeRequiredText(payload.name, 'Nombre', {
      min: 2,
      max: 60,
    }),
    category: normalizeOptionalText(payload.category, 'Categoría', {
      max: 40,
    }),
    description: normalizeOptionalText(payload.description, 'Descripción', {
      max: 240,
    }),
    mainPhotoKey: normalizeOptionalText(payload.mainPhotoKey, 'mainPhotoKey', {
      max: 512,
    }),
    coverPhotoKey: normalizeOptionalText(payload.coverPhotoKey, 'coverPhotoKey', {
      max: 512,
    }),
    paymentMethods: normalizePaymentMethods(payload.paymentMethods, {
      required: true,
    }),
    priceRange: normalizePriceRange(payload.priceRange, {
      required: true,
    }),
    referenceText: normalizeOptionalText(payload.referenceText, 'Referencia', {
      max: 160,
    }),
    schedule: normalizeSchedule(payload.schedule, {
      required: true,
    }),
    locationVisibility: normalizeLocationVisibility(payload.locationVisibility, {
      required: true,
    }),
    active: normalizeBoolean(payload.active, true),
  };
}

function validateUpdateStallInput(payload = {}) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throwValidation('Body inválido');
  }

  const changes = {};

  if (hasOwn(payload, 'name')) {
    changes.name = normalizeRequiredText(payload.name, 'Nombre', {
      min: 2,
      max: 60,
    });
  }

  if (hasOwn(payload, 'category')) {
    changes.category = normalizeOptionalText(payload.category, 'Categoría', {
      max: 40,
    });
  }

  if (hasOwn(payload, 'description')) {
    changes.description = normalizeOptionalText(payload.description, 'Descripción', {
      max: 240,
    });
  }

  if (hasOwn(payload, 'mainPhotoKey')) {
    changes.mainPhotoKey = normalizeOptionalText(payload.mainPhotoKey, 'mainPhotoKey', {
      max: 512,
    });
  }

  if (hasOwn(payload, 'coverPhotoKey')) {
    changes.coverPhotoKey = normalizeOptionalText(payload.coverPhotoKey, 'coverPhotoKey', {
      max: 512,
    });
  }

  if (hasOwn(payload, 'paymentMethods')) {
    changes.paymentMethods = normalizePaymentMethods(payload.paymentMethods);
  }

  if (hasOwn(payload, 'priceRange')) {
    changes.priceRange = normalizePriceRange(payload.priceRange);
  }

  if (hasOwn(payload, 'referenceText')) {
    changes.referenceText = normalizeOptionalText(payload.referenceText, 'Referencia', {
      max: 160,
    });
  }

  if (hasOwn(payload, 'schedule')) {
    changes.schedule = normalizeSchedule(payload.schedule);
  }

  if (hasOwn(payload, 'locationVisibility')) {
    changes.locationVisibility = normalizeLocationVisibility(payload.locationVisibility);
  }

  if (hasOwn(payload, 'active')) {
    changes.active = !!payload.active;
  }

  if (!Object.keys(changes).length) {
    throwValidation('Nada para actualizar');
  }

  return changes;
}

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function validateOpenStallInput(payload = {}) {
  const stallId = validateStallId(payload.stallId);
  const lat = toNumber(payload.lat);
  const lng = toNumber(payload.lng);
  const accuracy = toNumber(payload.accuracy || 0) ?? 0;

  const stallPhotoKey = String(payload.stallPhotoKey || '').trim();
  const productsPhotoKey = String(payload.productsPhotoKey || '').trim();
  const inventoryText = String(payload.inventoryText || '').trim();
  const stallName = String(payload.stallName || '').trim();

  if (lat === null || lng === null) {
    throw new AppError({
      code: 'MISSING_LOCATION',
      message: 'Falta ubicación',
      statusCode: 400,
    });
  }

  if (!stallPhotoKey || !productsPhotoKey) {
    throw new AppError({
      code: 'MISSING_PHOTOS',
      message: 'Faltan fotos',
      statusCode: 400,
    });
  }

  if (!inventoryText) {
    throw new AppError({
      code: 'MISSING_INVENTORY',
      message: 'Falta inventario',
      statusCode: 400,
    });
  }

  return {
    stallId,
    stallName,
    lat,
    lng,
    accuracy,
    stallPhotoKey,
    productsPhotoKey,
    inventoryText,
  };
}

function validateListOpeningsQuery(query = {}) {
  const raw = Number(query.limit || 20);
  const limit = Number.isFinite(raw) ? Math.max(1, Math.min(raw, 50)) : 20;
  return { limit };
}

module.exports = {
  requireAuthenticated,
  validateStallId,
  validateCreateStallInput,
  validateUpdateStallInput,
  validateOpenStallInput,
  validateListOpeningsQuery,
};