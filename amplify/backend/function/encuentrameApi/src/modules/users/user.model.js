'use strict';

function withOptionalField(target, key, value) {
  if (value !== undefined && value !== null && String(value).trim() !== '') {
    target[key] = value;
  }

  return target;
}

function buildUserProfile({
  userId,
  email = '',
  firstName = null,
  lastName = null,
  displayName = '',
  phone = null,
  gender = null,
  city = null,
  zone = null,
  birthDate = null,
  photoKey = null,
  isActive = true,
  createdAt,
  updatedAt,
}) {
  const item = {
    pk: `USER#${userId}`,
    sk: 'PROFILE',
    entityType: 'USER',
    userId,
    email,
    isActive,
    createdAt,
    updatedAt,
  };

  withOptionalField(item, 'firstName', firstName);
  withOptionalField(item, 'lastName', lastName);
  withOptionalField(item, 'displayName', displayName);
  withOptionalField(item, 'name', displayName);
  withOptionalField(item, 'phone', phone);
  withOptionalField(item, 'gender', gender);
  withOptionalField(item, 'city', city);
  withOptionalField(item, 'zone', zone);
  withOptionalField(item, 'birthDate', birthDate);
  withOptionalField(item, 'photoKey', photoKey);

  return item;
}

module.exports = {
  buildUserProfile,
};