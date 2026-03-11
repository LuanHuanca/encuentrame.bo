'use strict';

const crypto = require('crypto');
const {
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand,
  BatchGetCommand,
} = require('@aws-sdk/lib-dynamodb');

const { documentClient } = require('../../integrations/dynamodb/dynamo-client');
const { env } = require('../../shared/config/env');

function uuid() {
  return crypto.randomUUID
    ? crypto.randomUUID()
    : crypto.randomBytes(16).toString('hex');
}

function pkUser(userId) {
  return `USER#${userId}`;
}

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function skStall(stallId) {
  return `STALL#${stallId}`;
}

function skProduct(productId) {
  return `PROD#${productId}`;
}

async function findUserStallLinks(userId) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.STALLS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkUser(userId),
        ':prefix': 'STALL#',
      },
      ScanIndexForward: true,
    })
  );

  return result.Items || [];
}

async function findFirstOwnedStall(userId) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.STALLS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkUser(userId),
        ':prefix': 'STALL#',
      },
      ScanIndexForward: true,
      Limit: 1,
    })
  );

  return result.Items?.[0] || null;
}

async function getStallProfile(stallId) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
      },
    })
  );

  return result.Item || null;
}

async function userOwnsStall(userId, stallId) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkUser(userId),
        sk: skStall(stallId),
      },
    })
  );

  return !!result.Item;
}

async function createStall({
  userId,
  name,
  category,
  description,
  coverPhotoKey,
  now,
}) {
  const stallId = `stall_${uuid()}`;

  await documentClient.send(
    new PutCommand({
      TableName: env.STALLS_TABLE,
      Item: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
        entityType: 'STALL',
        stallId,
        vendorUserId: userId,
        name,
        category,
        description,
        coverPhotoKey,
        active: true,
        createdAt: now,
        updatedAt: now,
        currentOpen: null,
        currentLat: null,
        currentLng: null,
        currentAddressLabel: null,
        currentAddress: null,
      },
    })
  );

  await documentClient.send(
    new PutCommand({
      TableName: env.STALLS_TABLE,
      Item: {
        pk: pkUser(userId),
        sk: skStall(stallId),
        entityType: 'USER_STALL',
        stallId,
        name,
        category,
        description,
        coverPhotoKey,
        active: true,
        createdAt: now,
      },
    })
  );

  return {
    stallId,
    name,
    category,
    description,
    coverPhotoKey,
  };
}

async function batchGetProfiles(stallIds) {
  if (!stallIds.length) return [];

  const keys = stallIds.map((stallId) => ({
    pk: pkStall(stallId),
    sk: 'PROFILE',
  }));

  let requestItems = {
    [env.STALLS_TABLE]: { Keys: keys },
  };

  const profiles = [];

  for (let i = 0; i < 3; i += 1) {
    const result = await documentClient.send(
      new BatchGetCommand({
        RequestItems: requestItems,
      })
    );

    profiles.push(...(result.Responses?.[env.STALLS_TABLE] || []));

    const unprocessed = result.UnprocessedKeys || {};
    if (!unprocessed[env.STALLS_TABLE]?.Keys?.length) break;
    requestItems = unprocessed;
  }

  return profiles;
}

async function updateStallProfile({
  stallId,
  userId,
  name,
  category,
  description,
  coverPhotoKey,
  now,
}) {
  await documentClient.send(
    new UpdateCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
      },
      UpdateExpression:
        'SET #name = :name, category = :category, description = :description, coverPhotoKey = :coverPhotoKey, updatedAt = :updatedAt',
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':name': name,
        ':category': category,
        ':description': description,
        ':coverPhotoKey': coverPhotoKey,
        ':updatedAt': now,
      },
    })
  );

  await documentClient.send(
    new UpdateCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkUser(userId),
        sk: skStall(stallId),
      },
      UpdateExpression:
        'SET #name = :name, category = :category, description = :description, coverPhotoKey = :coverPhotoKey',
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':name': name,
        ':category': category,
        ':description': description,
        ':coverPhotoKey': coverPhotoKey,
      },
    })
  );
}

async function deleteStall(userId, stallId) {
  await documentClient.send(
    new DeleteCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkUser(userId),
        sk: skStall(stallId),
      },
    })
  );

  await documentClient.send(
    new DeleteCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
      },
    })
  );
}

async function setStallOpened({
  stallId,
  userId,
  name,
  lat,
  lng,
  addressLabel,
  address,
  openingKey,
  now,
}) {
  await documentClient.send(
    new UpdateCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
      },
      UpdateExpression: `
        SET vendorUserId = :vendorUserId,
            #name = if_not_exists(#name, :name),
            currentOpen = :currentOpen,
            currentLat = :lat,
            currentLng = :lng,
            currentAddressLabel = :addressLabel,
            currentAddress = :address,
            gsi1pk = :gsi1pk,
            gsi1sk = :gsi1sk,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':vendorUserId': userId,
        ':name': name || 'Puesto',
        ':currentOpen': openingKey,
        ':lat': lat,
        ':lng': lng,
        ':addressLabel': addressLabel,
        ':address': address,
        ':gsi1pk': 'OPEN',
        ':gsi1sk': `OPEN#${now}#${stallId}`,
        ':updatedAt': now,
      },
    })
  );
}

async function createOpeningLog({
  stallId,
  openingKey,
  item,
}) {
  await documentClient.send(
    new PutCommand({
      TableName: env.OPENINGLOGS_TABLE,
      Item: {
        pk: pkStall(stallId),
        sk: openingKey,
        ...item,
      },
    })
  );
}

async function getOpening(stallId, openingKey) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.OPENINGLOGS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: openingKey,
      },
    })
  );

  return result.Item || null;
}

async function getLatestOpening(stallId) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.OPENINGLOGS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'OPEN#',
      },
      ScanIndexForward: false,
      Limit: 1,
    })
  );

  return result.Items?.[0] || null;
}

async function listOpenings(stallId, limit) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.OPENINGLOGS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'OPEN#',
      },
      ScanIndexForward: false,
      Limit: limit,
    })
  );

  return result.Items || [];
}

async function closeOpening({ stallId, openingKey, now }) {
  await documentClient.send(
    new UpdateCommand({
      TableName: env.OPENINGLOGS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: openingKey,
      },
      UpdateExpression: 'SET #status = :status, closedAt = :closedAt',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ':status': 'CLOSED',
        ':closedAt': now,
      },
    })
  );

  await documentClient.send(
    new UpdateCommand({
      TableName: env.STALLS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: 'PROFILE',
      },
      UpdateExpression:
        'REMOVE gsi1pk, gsi1sk SET currentOpen = :currentOpen, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':currentOpen': null,
        ':updatedAt': now,
      },
    })
  );
}

async function upsertProduct({
  stallId,
  productId,
  canonical,
  display,
  category,
  tags,
  qty,
  now,
}) {
  await documentClient.send(
    new UpdateCommand({
      TableName: env.PRODUCTS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skProduct(productId),
      },
      UpdateExpression: `
        SET entityType = if_not_exists(entityType, :entityType),
            productId = if_not_exists(productId, :productId),
            canonical = if_not_exists(canonical, :canonical),
            #display = if_not_exists(#display, :display),
            category = if_not_exists(category, :category),
            tags = if_not_exists(tags, :tags),
            active = if_not_exists(active, :active),
            lastQty = :lastQty,
            lastSeenAt = :lastSeenAt
      `,
      ExpressionAttributeNames: {
        '#display': 'display',
      },
      ExpressionAttributeValues: {
        ':entityType': 'PRODUCT',
        ':productId': productId,
        ':canonical': canonical,
        ':display': display,
        ':category': category ?? null,
        ':tags': tags ?? [],
        ':active': true,
        ':lastQty': qty,
        ':lastSeenAt': now,
      },
    })
  );
}

module.exports = {
  uuid,
  pkUser,
  pkStall,
  skStall,
  findUserStallLinks,
  findFirstOwnedStall,
  getStallProfile,
  userOwnsStall,
  createStall,
  batchGetProfiles,
  updateStallProfile,
  deleteStall,
  setStallOpened,
  createOpeningLog,
  getOpening,
  getLatestOpening,
  listOpenings,
  closeOpening,
  upsertProduct,
};