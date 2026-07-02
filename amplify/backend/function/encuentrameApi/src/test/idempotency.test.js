'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.STALLS_TABLE = 'stalls-test';
process.env.OPENINGLOGS_TABLE = 'openings-test';
process.env.BUCKET_NAME = 'bucket-test';

const userId = 'us-east-1:11111111-1111-1111-1111-111111111111';
const stallId = 'stall_123';
const idempotencyKey = '12345678-1234-1234-1234-123456789012';
const completedResponse = {
  stallId,
  openingKey: 'OPEN#existing',
  status: 'OPEN',
  location: { lat: -16.5, lng: -68.15, accuracy: 20 },
  inventory: { items: [], suggestions: [] },
};

let externalCalls = 0;

function mockModule(relativePath, exports) {
  const path = require.resolve(relativePath);
  require.cache[path] = { id: path, filename: path, loaded: true, exports };
}

mockModule('../modules/stall/stall.repository', {
  userOwnsStall: async () => true,
  getStallProfile: async () => ({
    active: true,
    currentOpen: completedResponse.openingKey,
  }),
  uuid: () => 'new-id',
  clearStaleOpenLock: async () => false,
  beginOpenRequest: async () => {
    const error = new Error('duplicate');
    error.name = 'TransactionCanceledException';
    throw error;
  },
  getOpenRequest: async () => ({
    userId,
    status: 'COMPLETED',
    response: completedResponse,
  }),
});
mockModule('../integrations/geo/location.service', {
  reverseGeocode: async () => {
    externalCalls += 1;
    return null;
  },
});
mockModule('../integrations/vision/rekognition.service', {
  isResourceNotFound: () => false,
  detectLabelsFromS3Key: async () => {
    externalCalls += 1;
    return { labels: [], keyUsed: '' };
  },
  detectModerationFromS3Key: async () => {
    externalCalls += 1;
    return { moderation: [], keyUsed: '' };
  },
});
mockModule('../integrations/ai/bedrock.service', {
  extractInventory: async () => {
    externalCalls += 1;
    return null;
  },
});

const stallService = require('../modules/stall/stall.service');

test('a completed duplicate returns the stored response even when the stall is open', async () => {
  const key = `protected/${userId}/stalls/${stallId}/photo.jpg`;
  const response = await stallService.open(
    { userId },
    {
      stallId,
      lat: -16.5,
      lng: -68.15,
      accuracy: 20,
      stallPhotoKey: key,
      productsPhotoKey: key.replace('photo.jpg', 'products.jpg'),
      inventoryText: '2 poleras',
      idempotencyKey,
    }
  );

  assert.deepEqual(response, completedResponse);
  assert.equal(externalCalls, 0);
});
