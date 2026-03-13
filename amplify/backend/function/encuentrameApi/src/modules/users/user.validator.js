'use strict';

const { AppError } = require('../../shared/errors/app-error');

const GENDER_MAP = {
  male: 'male',
  masculino: 'male',
  hombre: 'male',
  m: 'male',

  female: 'female',
  femenino: 'female',
  mujer: 'female',
  f: 'female',

  other: 'other',
  otro: 'other',

  prefer_not_to_say: 'prefer_not_to_say',
  prefiero_no_decirlo: 'prefer_not_to_say',
  no_especificar: 'prefer_not_to_say',
};

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
}

function throwValidation(message) {
  throw new AppError({
    code: 'VALIDATION',
    message,
    statusCode: 400,
  });
}

function normalizeText(value) {
  return String(value || '').trim();
}

function normalizeOptionalText(value, { max, fieldName, min = 0 } = {}) {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  if (text.length < min) {
    throwValidation(`${fieldName} no válido`);
  }

  if (max && text.length > max) {
    throwValidation(`${fieldName} demasiado largo`);
  }

  return text;
}

function normalizePhone(value) {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  if (text.length > 25) {
    throwValidation('Teléfono demasiado largo');
  }

  if (!/^[+\d\s\-()]+$/.test(text)) {
    throwValidation('Teléfono no válido');
  }

  return text;
}

function normalizeGender(value) {
  const text = normalizeText(value).toLowerCase();

  if (!text) {
    return null;
  }

  const normalized = GENDER_MAP[text];
  if (!normalized) {
    throwValidation('Género no válido');
  }

  return normalized;
}

function normalizeBirthDate(value) {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    throwValidation('Fecha de nacimiento no válida');
  }

  const date = new Date(`${text}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) {
    throwValidation('Fecha de nacimiento no válida');
  }

  const reconstructed = date.toISOString().slice(0, 10);
  if (reconstructed !== text) {
    throwValidation('Fecha de nacimiento no válida');
  }

  const today = new Date();
  const todayString = new Date(
    Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
  )
    .toISOString()
    .slice(0, 10);

  if (text > todayString) {
    throwValidation('La fecha de nacimiento no puede ser futura');
  }

  return text;
}

function normalizePhotoKey(value) {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  if (text.length > 512) {
    throwValidation('photoKey demasiado largo');
  }

  return text;
}

function splitLegacyName(name) {
  const text = normalizeText(name);

  if (!text) {
    return {
      firstName: null,
      lastName: null,
    };
  }

  if (text.length < 2) {
    throwValidation('Nombre no válido');
  }

  if (text.length > 120) {
    throwValidation('Nombre demasiado largo');
  }

  const parts = text.split(/\s+/).filter(Boolean);

  if (parts.length === 1) {
    return {
      firstName: parts[0],
      lastName: null,
    };
  }

  return {
    firstName: parts[0],
    lastName: parts.slice(1).join(' '),
  };
}

function validateUpdateProfileInput(payload = {}) {
  const changes = {};

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throwValidation('Body inválido');
  }

  if (hasOwn(payload, 'name') && !hasOwn(payload, 'firstName') && !hasOwn(payload, 'lastName')) {
    const legacy = splitLegacyName(payload.name);
    changes.firstName = legacy.firstName;
    changes.lastName = legacy.lastName;
  }

  if (hasOwn(payload, 'firstName')) {
    changes.firstName = normalizeOptionalText(payload.firstName, {
      fieldName: 'Nombre',
      min: 2,
      max: 40,
    });
  }

  if (hasOwn(payload, 'lastName')) {
    changes.lastName = normalizeOptionalText(payload.lastName, {
      fieldName: 'Apellido',
      min: 2,
      max: 60,
    });
  }

  if (hasOwn(payload, 'phone')) {
    changes.phone = normalizePhone(payload.phone);
  }

  if (hasOwn(payload, 'gender')) {
    changes.gender = normalizeGender(payload.gender);
  }

  if (hasOwn(payload, 'city')) {
    changes.city = normalizeOptionalText(payload.city, {
      fieldName: 'Ciudad',
      min: 2,
      max: 60,
    });
  }

  if (hasOwn(payload, 'zone')) {
    changes.zone = normalizeOptionalText(payload.zone, {
      fieldName: 'Zona',
      min: 2,
      max: 80,
    });
  }

  if (hasOwn(payload, 'birthDate')) {
    changes.birthDate = normalizeBirthDate(payload.birthDate);
  }

  if (hasOwn(payload, 'photoKey')) {
    changes.photoKey = normalizePhotoKey(payload.photoKey);
  }

  if (!Object.keys(changes).length) {
    throwValidation('Nada para actualizar');
  }

  return changes;
}

module.exports = {
  validateUpdateProfileInput,
};