'use strict';

const {
  QueryCommand,
  GetCommand,
  UpdateCommand,
  DeleteCommand,
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

function skProduct(productId) {
  return `PROD#${productId}`;
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

async function listByStallId(stallId) {
  const result = await documentClient.send(
    new QueryCommand({
      TableName: env.PRODUCTS_TABLE,
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: {
        ':pk': pkStall(stallId),
        ':prefix': 'PROD#',
      },
      ScanIndexForward: true,
    })
  );

  return result.Items || [];
}

async function updateProduct({ stallId, productId, changes }) {
  const sets = [];
  const names = {};
  const values = {};

  if (changes.display !== undefined) {
    names['#display'] = 'display';
    values[':display'] = changes.display;
    sets.push('#display = :display');
  }

  if (changes.price !== undefined) {
    names['#price'] = 'price';
    values[':price'] = changes.price;
    sets.push('#price = :price');
  }

  if (changes.active !== undefined) {
    names['#active'] = 'active';
    values[':active'] = changes.active;
    sets.push('#active = :active');
  }

  if (changes.lastQty !== undefined) {
    names['#lastQty'] = 'lastQty';
    values[':lastQty'] = changes.lastQty;
    sets.push('#lastQty = :lastQty');
  }

  const result = await documentClient.send(
    new UpdateCommand({
      TableName: env.PRODUCTS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skProduct(productId),
      },
      UpdateExpression: `SET ${sets.join(', ')}`,
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values,
      ConditionExpression: 'attribute_exists(pk) AND attribute_exists(sk)',
      ReturnValues: 'ALL_NEW',
    })
  );

  return result.Attributes || null;
}

async function deleteProduct(stallId, productId) {
  await documentClient.send(
    new DeleteCommand({
      TableName: env.PRODUCTS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skProduct(productId),
      },
    })
  );
}

module.exports = {
  userOwnsStall,
  listByStallId,
  updateProduct,
  deleteProduct,
};