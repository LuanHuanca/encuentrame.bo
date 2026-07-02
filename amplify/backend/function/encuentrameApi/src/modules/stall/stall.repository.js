'use strict';

const crypto = require('crypto');
const {
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand,
  BatchGetCommand,
  TransactWriteCommand,
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

function skOpenRequest(idempotencyKey) {
  return `REQUEST#${idempotencyKey}`;
}

const OPEN_LOCK_SK = 'OPEN_LOCK';

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

async function getOpenRequest(stallId, idempotencyKey) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.OPENINGLOGS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skOpenRequest(idempotencyKey),
      },
      ConsistentRead: true,
    })
  );

  return result.Item || null;
}

async function beginOpenRequest({ stallId, userId, idempotencyKey, now }) {
  await documentClient.send(
    new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: env.OPENINGLOGS_TABLE,
            Item: {
              pk: pkStall(stallId),
              sk: skOpenRequest(idempotencyKey),
              entityType: 'OPEN_REQUEST',
              idempotencyKey,
              userId,
              status: 'PROCESSING',
              createdAt: now,
              updatedAt: now,
            },
            ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
          },
        },
        {
          Put: {
            TableName: env.OPENINGLOGS_TABLE,
            Item: {
              pk: pkStall(stallId),
              sk: OPEN_LOCK_SK,
              entityType: 'OPEN_LOCK',
              idempotencyKey,
              userId,
              createdAt: now,
            },
            ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
          },
        },
      ],
    })
  );
}

async function clearStaleOpenLock(stallId, cutoffIso) {
  try {
    await documentClient.send(
      new DeleteCommand({
        TableName: env.OPENINGLOGS_TABLE,
        Key: { pk: pkStall(stallId), sk: OPEN_LOCK_SK },
        ConditionExpression: 'createdAt < :cutoff',
        ExpressionAttributeValues: { ':cutoff': cutoffIso },
      })
    );
    return true;
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') return false;
    throw error;
  }
}

async function completeOpenRequest({
  stallId,
  userId,
  idempotencyKey,
  openingKey,
  openingItem,
  response,
  profile,
  now,
}) {
  const profileUpdate = {
    TableName: env.STALLS_TABLE,
    Key: {
      pk: pkStall(stallId),
      sk: 'PROFILE',
    },
    UpdateExpression: `
      SET currentOpen = :currentOpen,
          currentOpenStatus = :openStatus,
          currentOpenedAt = :openedAt,
          currentLat = :lat,
          currentLng = :lng,
          currentAccuracy = :accuracy,
          currentAddressLabel = :addressLabel,
          currentAddress = :address,
          currentStallPhotoKey = :stallPhotoKey,
          currentProductsPhotoKey = :productsPhotoKey,
          currentInventoryItems = :inventoryItems,
          currentInventorySuggestions = :inventorySuggestions,
          gsi1pk = :gsi1pk,
          gsi1sk = :gsi1sk,
          updatedAt = :updatedAt
    `,
    ConditionExpression:
      'vendorUserId = :userId AND (attribute_not_exists(currentOpen) OR currentOpen = :empty)',
    ExpressionAttributeValues: {
      ':userId': userId,
      ':empty': null,
      ':currentOpen': openingKey,
      ':openStatus': 'OPEN',
      ':openedAt': now,
      ':lat': profile.lat,
      ':lng': profile.lng,
      ':accuracy': profile.accuracy,
      ':addressLabel': profile.addressLabel,
      ':address': profile.address,
      ':stallPhotoKey': profile.stallPhotoKey,
      ':productsPhotoKey': profile.productsPhotoKey,
      ':inventoryItems': profile.inventoryItems,
      ':inventorySuggestions': profile.inventorySuggestions,
      ':gsi1pk': 'OPEN',
      ':gsi1sk': `OPEN#${now}#${stallId}`,
      ':updatedAt': now,
    },
  };

  await documentClient.send(
    new TransactWriteCommand({
      TransactItems: [
        { Update: profileUpdate },
        {
          Put: {
            TableName: env.OPENINGLOGS_TABLE,
            Item: {
              pk: pkStall(stallId),
              sk: openingKey,
              ...openingItem,
            },
            ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
          },
        },
        {
          Update: {
            TableName: env.OPENINGLOGS_TABLE,
            Key: {
              pk: pkStall(stallId),
              sk: skOpenRequest(idempotencyKey),
            },
            UpdateExpression:
              'SET #status = :completed, openingKey = :openingKey, response = :response, updatedAt = :updatedAt',
            ConditionExpression: '#status = :processing AND userId = :userId',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: {
              ':completed': 'COMPLETED',
              ':processing': 'PROCESSING',
              ':openingKey': openingKey,
              ':response': response,
              ':updatedAt': now,
              ':userId': userId,
            },
          },
        },
        {
          Delete: {
            TableName: env.OPENINGLOGS_TABLE,
            Key: { pk: pkStall(stallId), sk: OPEN_LOCK_SK },
            ConditionExpression: 'idempotencyKey = :idempotencyKey',
            ExpressionAttributeValues: { ':idempotencyKey': idempotencyKey },
          },
        },
      ],
    })
  );
}

async function completeReviewRequest({
  stallId,
  userId,
  idempotencyKey,
  openingKey,
  openingItem,
  response,
  now,
}) {
  await documentClient.send(
    new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: env.OPENINGLOGS_TABLE,
            Item: {
              pk: pkStall(stallId),
              sk: openingKey,
              ...openingItem,
            },
            ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
          },
        },
        {
          Update: {
            TableName: env.OPENINGLOGS_TABLE,
            Key: {
              pk: pkStall(stallId),
              sk: skOpenRequest(idempotencyKey),
            },
            UpdateExpression:
              'SET #status = :completed, openingKey = :openingKey, response = :response, updatedAt = :updatedAt',
            ConditionExpression: '#status = :processing AND userId = :userId',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: {
              ':completed': 'COMPLETED',
              ':processing': 'PROCESSING',
              ':openingKey': openingKey,
              ':response': response,
              ':updatedAt': now,
              ':userId': userId,
            },
          },
        },
        {
          Delete: {
            TableName: env.OPENINGLOGS_TABLE,
            Key: { pk: pkStall(stallId), sk: OPEN_LOCK_SK },
            ConditionExpression: 'idempotencyKey = :idempotencyKey',
            ExpressionAttributeValues: { ':idempotencyKey': idempotencyKey },
          },
        },
      ],
    })
  );
}

async function failOpenRequest({ stallId, idempotencyKey, now, errorCode }) {
  try {
    await documentClient.send(
      new TransactWriteCommand({
        TransactItems: [
          {
            Update: {
              TableName: env.OPENINGLOGS_TABLE,
              Key: {
                pk: pkStall(stallId),
                sk: skOpenRequest(idempotencyKey),
              },
              UpdateExpression:
                'SET #status = :failed, errorCode = :errorCode, updatedAt = :updatedAt',
              ExpressionAttributeNames: { '#status': 'status' },
              ExpressionAttributeValues: {
                ':failed': 'FAILED',
                ':errorCode': String(errorCode || 'OPEN_FAILED'),
                ':updatedAt': now,
              },
            },
          },
          {
            Delete: {
              TableName: env.OPENINGLOGS_TABLE,
              Key: { pk: pkStall(stallId), sk: OPEN_LOCK_SK },
              ConditionExpression: 'idempotencyKey = :idempotencyKey',
              ExpressionAttributeValues: { ':idempotencyKey': idempotencyKey },
            },
          },
        ],
      })
    );
  } catch (_) {
    // No oculta el error original. Una operación posterior puede limpiar el lock.
  }
}

async function createStall({
  userId,
  name,
  category,
  description,
  mainPhotoKey,
  coverPhotoKey,
  paymentMethods,
  priceRange,
  referenceText,
  schedule,
  locationVisibility,
  active,
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
        mainPhotoKey,
        coverPhotoKey,
        paymentMethods,
        priceRange,
        referenceText,
        schedule,
        locationVisibility,
        active,
        createdAt: now,
        updatedAt: now,
        currentOpen: null,
        currentOpenStatus: null,
        currentOpenedAt: null,
        currentLat: null,
        currentLng: null,
        currentAccuracy: null,
        currentAddressLabel: null,
        currentAddress: null,
        currentStallPhotoKey: null,
        currentProductsPhotoKey: null,
        currentInventoryItems: [],
        currentInventorySuggestions: [],
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
        mainPhotoKey,
        coverPhotoKey,
        priceRange,
        active,
        createdAt: now,
        updatedAt: now,
      },
    })
  );

  return {
    stallId,
    vendorUserId: userId,
    name,
    category,
    description,
    mainPhotoKey,
    coverPhotoKey,
    paymentMethods,
    priceRange,
    referenceText,
    schedule,
    locationVisibility,
    active,
    createdAt: now,
    updatedAt: now,
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
  mainPhotoKey,
  coverPhotoKey,
  paymentMethods,
  priceRange,
  referenceText,
  schedule,
  locationVisibility,
  active,
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
        SET #name = :name,
            category = :category,
            description = :description,
            mainPhotoKey = :mainPhotoKey,
            coverPhotoKey = :coverPhotoKey,
            paymentMethods = :paymentMethods,
            priceRange = :priceRange,
            referenceText = :referenceText,
            schedule = :schedule,
            locationVisibility = :locationVisibility,
            active = :active,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':name': name,
        ':category': category,
        ':description': description,
        ':mainPhotoKey': mainPhotoKey,
        ':coverPhotoKey': coverPhotoKey,
        ':paymentMethods': paymentMethods,
        ':priceRange': priceRange,
        ':referenceText': referenceText,
        ':schedule': schedule,
        ':locationVisibility': locationVisibility,
        ':active': active,
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
      UpdateExpression: `
        SET #name = :name,
            category = :category,
            description = :description,
            mainPhotoKey = :mainPhotoKey,
            coverPhotoKey = :coverPhotoKey,
            priceRange = :priceRange,
            active = :active,
            updatedAt = :updatedAt
      `,
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':name': name,
        ':category': category,
        ':description': description,
        ':mainPhotoKey': mainPhotoKey,
        ':coverPhotoKey': coverPhotoKey,
        ':priceRange': priceRange,
        ':active': active,
        ':updatedAt': now,
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
  accuracy,
  addressLabel,
  address,
  stallPhotoKey,
  productsPhotoKey,
  inventoryItems,
  inventorySuggestions,
  status,
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
            currentOpenStatus = :currentOpenStatus,
            currentOpenedAt = :currentOpenedAt,
            currentLat = :lat,
            currentLng = :lng,
            currentAccuracy = :accuracy,
            currentAddressLabel = :addressLabel,
            currentAddress = :address,
            currentStallPhotoKey = :stallPhotoKey,
            currentProductsPhotoKey = :productsPhotoKey,
            currentInventoryItems = :currentInventoryItems,
            currentInventorySuggestions = :currentInventorySuggestions,
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
        ':currentOpenStatus': status || 'OPEN',
        ':currentOpenedAt': now,
        ':lat': lat,
        ':lng': lng,
        ':accuracy': accuracy ?? 0,
        ':addressLabel': addressLabel,
        ':address': address,
        ':stallPhotoKey': stallPhotoKey || null,
        ':productsPhotoKey': productsPhotoKey || null,
        ':currentInventoryItems': Array.isArray(inventoryItems) ? inventoryItems : [],
        ':currentInventorySuggestions': Array.isArray(inventorySuggestions)
          ? inventorySuggestions
          : [],
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
    new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: env.OPENINGLOGS_TABLE,
            Key: {
              pk: pkStall(stallId),
              sk: openingKey,
            },
            UpdateExpression: 'SET #status = :closed, closedAt = :closedAt',
            ConditionExpression: '#status = :open',
            ExpressionAttributeNames: {
              '#status': 'status',
            },
            ExpressionAttributeValues: {
              ':open': 'OPEN',
              ':closed': 'CLOSED',
              ':closedAt': now,
            },
          },
        },
        {
          Update: {
            TableName: env.STALLS_TABLE,
            Key: {
              pk: pkStall(stallId),
              sk: 'PROFILE',
            },
            UpdateExpression: `
              REMOVE gsi1pk,
                     gsi1sk,
                     currentOpenStatus,
                     currentOpenedAt,
                     currentAccuracy,
                     currentStallPhotoKey,
                     currentProductsPhotoKey,
                     currentInventoryItems,
                     currentInventorySuggestions
              SET currentOpen = :empty,
                  updatedAt = :updatedAt
            `,
            ConditionExpression: 'currentOpen = :openingKey',
            ExpressionAttributeValues: {
              ':openingKey': openingKey,
              ':empty': null,
              ':updatedAt': now,
            },
          },
        },
      ],
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
  getOpenRequest,
  beginOpenRequest,
  clearStaleOpenLock,
  completeOpenRequest,
  completeReviewRequest,
  failOpenRequest,
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
