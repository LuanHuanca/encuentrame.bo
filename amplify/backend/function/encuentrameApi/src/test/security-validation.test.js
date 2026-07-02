'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { isOwnedStallImageKey } = require('../integrations/storage/s3-paths');
const { validateOpenStallInput } = require('../modules/stall/stall.validator');
const { validateNearbyQuery } = require('../modules/market/market.validator');

const userId = 'us-east-1:11111111-1111-1111-1111-111111111111';
const stallId = 'stall_123';
const validKey = `protected/${userId}/stalls/${stallId}/photo.jpg`;

function validOpenInput() {
  return {
    stallId,
    lat: -16.5,
    lng: -68.15,
    accuracy: 20,
    stallPhotoKey: validKey,
    productsPhotoKey: `protected/${userId}/stalls/${stallId}/products.png`,
    inventoryText: '2 poleras y 1 zapato',
    idempotencyKey: '12345678-1234-1234-1234-123456789012',
  };
}

test('accepts only an owned protected stall image key', () => {
  assert.equal(
    isOwnedStallImageKey({ key: validKey, userId, stallId }),
    true
  );
  for (const key of [
    'https://example.com/photo.jpg',
    `protected/${userId}/stalls/${stallId}/../photo.jpg`,
    `protected/other/stalls/${stallId}/photo.jpg`,
    `protected/${userId}/stalls/other/photo.jpg`,
    `protected/${userId}/stalls/${stallId}/photo.exe`,
    `protected/${userId}/stalls/${stallId}/nested/photo.jpg`,
  ]) {
    assert.equal(isOwnedStallImageKey({ key, userId, stallId }), false, key);
  }
});

test('validates open location, accuracy, inventory and identity', () => {
  const result = validateOpenStallInput(validOpenInput(), { userId });
  assert.equal(result.stallId, stallId);

  for (const changes of [
    { lat: 91 },
    { lng: -181 },
    { accuracy: 201 },
    { inventoryText: 'x'.repeat(2001) },
    { idempotencyKey: 'short' },
    { stallPhotoKey: 'public/vendor/photo.jpg' },
  ]) {
    assert.throws(
      () => validateOpenStallInput({ ...validOpenInput(), ...changes }, { userId })
    );
  }
});

test('nearby clamps result and preview limits and validates coordinates', () => {
  const result = validateNearbyQuery({
    lat: '-16.5',
    lng: '-68.15',
    limit: '500',
    productsLimit: '50',
  });
  assert.equal(result.limit, 50);
  assert.equal(result.productsLimit, 6);
  assert.throws(() => validateNearbyQuery({ lat: '100', lng: '0' }));
});
