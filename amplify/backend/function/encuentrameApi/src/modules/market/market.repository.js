'use strict';

const { QueryCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const { documentClient } = require('../../integrations/dynamodb/dynamo-client');
const { env } = require('../../shared/config/env');

function pkStall(stallId) {
  return `STALL#${stallId}`;
}

async function listOpenStallProfiles(limit = 400) {
  const items = [];
  let exclusiveStartKey;

  while (items.length < limit) {
    const page = await documentClient.send(
      new QueryCommand({
        TableName: env.STALLS_TABLE,
        IndexName: 'gsi1',
        KeyConditionExpression: 'gsi1pk = :partition',
        ExpressionAttributeValues: {
          ':partition': 'OPEN',
        },
        ScanIndexForward: false,
        Limit: Math.min(100, limit - items.length),
        ExclusiveStartKey: exclusiveStartKey,
      })
    );

    items.push(...(page.Items || []));
    exclusiveStartKey = page.LastEvaluatedKey;

    if (!exclusiveStartKey) break;
  }

  return items;
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
  getStallProfile,
  listProductsByStallId,
};