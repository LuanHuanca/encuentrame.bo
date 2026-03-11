'use strict';

const {
  QueryCommand,
  GetCommand,
  ScanCommand,
} = require('@aws-sdk/lib-dynamodb');
const { documentClient } = require('../../integrations/dynamodb/dynamo-client');
const { env } = require('../../shared/config/env');

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

function isOpenProfile(item) {
  const value = item?.currentOpen;

  if (value === true || value === 1 || value === '1') {
    return true;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === 'true' || normalized === 'open';
  }

  return false;
}

async function listStallProfiles(limit = 400) {
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

    items.push(...(page.Items || []));
    exclusiveStartKey = page.LastEvaluatedKey;

    if (!exclusiveStartKey) {
      break;
    }
  }

  return items.slice(0, limit);
}

async function listOpenStallProfiles(limit = 400) {
  const profiles = await listStallProfiles(limit);
  return profiles.filter(isOpenProfile);
}

async function listAllStallProfiles(limit = 400) {
  return listStallProfiles(limit);
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

module.exports = {
  listOpenStallProfiles,
  listAllStallProfiles,
  getStallProfile,
  listProductsByStallId,
};