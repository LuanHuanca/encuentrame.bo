'use strict';

const {
  QueryCommand,
  GetCommand,
  ScanCommand,
  BatchGetCommand,
} = require('@aws-sdk/lib-dynamodb');

const { documentClient } = require('../../integrations/dynamodb/dynamo-client');
const { env } = require('../../shared/config/env');

function pkUser(userId) {
  return `USER#${userId}`;
}

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function skStall(stallId) {
  return `STALL#${stallId}`;
}

function isOpenProfile(item) {
  if (item?.currentOpenStatus !== 'OPEN') return false;
  const value = item?.currentOpen;

  if (value === true || value === 1 || value === '1') {
    return true;
  }

  if (typeof value === 'string') {
    return value.trim().length > 0;
  }

  return false;
}

async function scanStallProfiles(limit = 400, onlyOpen = false) {
  const items = [];
  let exclusiveStartKey;

  while (items.length < limit) {
    const page = await documentClient.send(
      new ScanCommand({
        TableName: env.STALLS_TABLE,
        FilterExpression: '#sk = :profile',
        ExpressionAttributeNames: {
          '#sk': 'sk',
        },
        ExpressionAttributeValues: {
          ':profile': 'PROFILE',
        },
        Limit: Math.min(100, limit - items.length),
        ExclusiveStartKey: exclusiveStartKey,
      })
    );

    const pageItems = page.Items || [];
    items.push(...(onlyOpen ? pageItems.filter(isOpenProfile) : pageItems));

    exclusiveStartKey = page.LastEvaluatedKey;
    if (!exclusiveStartKey) {
      break;
    }
  }

  return items.slice(0, limit);
}

async function listOpenStallProfiles(limit = 400) {
  const items = [];
  let exclusiveStartKey;

  try {
    while (items.length < limit) {
      const page = await documentClient.send(
        new QueryCommand({
          TableName: env.STALLS_TABLE,
          IndexName: 'gsi1',
          KeyConditionExpression: 'gsi1pk = :gsi1pk',
          ExpressionAttributeValues: {
            ':gsi1pk': 'OPEN',
          },
          ScanIndexForward: false,
          Limit: Math.min(100, limit - items.length),
          ExclusiveStartKey: exclusiveStartKey,
        })
      );

      items.push(...(page.Items || []).filter(isOpenProfile));
      exclusiveStartKey = page.LastEvaluatedKey;

      if (!exclusiveStartKey) {
        break;
      }
    }

    return items.slice(0, limit);
  } catch (error) {
    if (error?.name === 'ValidationException' && env.ENV === 'dev') {
      return scanStallProfiles(limit, true);
    }

    throw error;
  }
}

async function listAllStallProfiles(limit = 400) {
  return scanStallProfiles(limit, false);
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

async function listProductsByStallId(stallId, limit = 250) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'PROD#',
      },
      ScanIndexForward: true,
      Limit: limit,
    })
  );

  return result.Items || [];
}

async function getOpening(stallId, openingKey) {
  if (!env.OPENINGLOGS_TABLE || !openingKey) {
    return null;
  }

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

async function getUserProfile(userId) {
  if (!env.USERS_TABLE || !userId) {
    return null;
  }

  const result = await documentClient.send(
    new GetCommand({
      TableName: env.USERS_TABLE,
      Key: {
        pk: pkUser(userId),
        sk: 'PROFILE',
      },
    })
  );

  return result.Item || null;
}

async function countStallsByUserId(userId) {
  if (!env.STALLS_TABLE || !userId) {
    return 0;
  }

  let total = 0;
  let exclusiveStartKey;

  do {
    const result = await documentClient.send(
      new QueryCommand({
        TableName: env.STALLS_TABLE,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
        ExpressionAttributeValues: {
          ':pk': pkUser(userId),
          ':prefix': 'STALL#',
        },
        Select: 'COUNT',
        ExclusiveStartKey: exclusiveStartKey,
      })
    );

    total += Number(result.Count || 0);
    exclusiveStartKey = result.LastEvaluatedKey;
  } while (exclusiveStartKey);

  return total;
}

async function listUserStallLinks(userId, limit = 20) {
  if (!env.STALLS_TABLE || !userId) {
    return [];
  }

  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.STALLS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkUser(userId),
        ':prefix': 'STALL#',
      },
      ScanIndexForward: true,
      Limit: limit,
    })
  );

  return result.Items || [];
}

async function batchGetStallProfiles(stallIds) {
  if (!stallIds.length) {
    return [];
  }

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
    if (!unprocessed[env.STALLS_TABLE]?.Keys?.length) {
      break;
    }

    requestItems = unprocessed;
  }

  return profiles;
}

module.exports = {
  listOpenStallProfiles,
  listAllStallProfiles,
  getStallProfile,
  listProductsByStallId,
  getOpening,
  getUserProfile,
  countStallsByUserId,
  listUserStallLinks,
  batchGetStallProfiles,
};
