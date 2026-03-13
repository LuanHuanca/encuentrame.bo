'use strict';

function toNullableString(value) {
  const text = String(value || '').trim();
  return text || null;
}

function buildDisplayName(item = {}) {
  const explicitDisplayName = String(item.displayName || '').trim();
  if (explicitDisplayName) {
    return explicitDisplayName;
  }

  const legacyName = String(item.name || '').trim();
  if (legacyName) {
    return legacyName;
  }

  const fullName = [item.firstName, item.lastName]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join(' ')
    .trim();

  return fullName || '';
}

function calculateProfileCompletion(item = {}) {
  const fields = [
    toNullableString(item.firstName),
    toNullableString(item.lastName),
    toNullableString(item.phone),
    toNullableString(item.gender),
    toNullableString(item.city),
    toNullableString(item.zone),
    toNullableString(item.birthDate),
    toNullableString(item.photoKey),
  ];

  const completed = fields.filter(Boolean).length;
  return Math.round((completed / fields.length) * 100);
}

function toUserResponse(item = {}, currentUser = {}) {
  const displayName = buildDisplayName(item);

  return {
    userId: item.userId || '',
    firstName: toNullableString(item.firstName),
    lastName: toNullableString(item.lastName),
    displayName: displayName || '',
    name: displayName || '',
    email: String(currentUser.email || item.email || '').trim(),
    phone: toNullableString(item.phone),
    gender: toNullableString(item.gender),
    city: toNullableString(item.city),
    zone: toNullableString(item.zone),
    birthDate: toNullableString(item.birthDate),
    photoKey: toNullableString(item.photoKey),
    isActive: item.isActive !== false,
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
    profileCompletion: calculateProfileCompletion(item),
  };
}

function toPublicUserResponse(item = {}, extra = {}) {
  const displayName = buildDisplayName(item);

  return {
    userId: item.userId || '',
    displayName: displayName || 'Vendedor',
    photoKey: toNullableString(item.photoKey),
    city: toNullableString(item.city),
    zone: toNullableString(item.zone),
    sellerSince: item.createdAt || null,
    stallCount: Number(extra.stallCount || 0),
    publicTagline: toNullableString(extra.publicTagline),
  };
}

module.exports = {
  toUserResponse,
  toPublicUserResponse,
};