'use strict';

const {
  QueryCommand,
  GetCommand,
  PutCommand,
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

async function getProduct(stallId, productId) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.PRODUCTS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skProduct(productId),
      },
    })
  );

  return result.Item || null;
}

async function createProduct(item) {
  await documentClient.send(
    new PutCommand({
      TableName: env.PRODUCTS_TABLE,
      Item: item,
      ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
    })
  );

  return item;
}

async function updateProduct({ stallId, productId, changes }) {
  const setExpressions = [];
  const removeExpressions = [];
  const names = {};
  const values = {};

  function setField(attributeName, value, alias = attributeName) {
    names[`#${alias}`] = attributeName;
    values[`:${alias}`] = value;
    setExpressions.push(`#${alias} = :${alias}`);
  }

  function removeField(attributeName, alias = attributeName) {
    names[`#${alias}`] = attributeName;
    removeExpressions.push(`#${alias}`);
  }

  setField('updatedAt', changes.updatedAt, 'updatedAt');

  const nullableFields = ['category', 'description', 'photoKey', 'price'];
  for (const field of nullableFields) {
    if (!(field in changes)) {
      continue;
    }

    if (changes[field] === null) {
      removeField(field, field);
      continue;
    }

    setField(field, changes[field], field);
  }

  const directFields = ['canonical', 'display', 'active', 'lastQty', 'lastSeenAt'];
  for (const field of directFields) {
    if (!(field in changes)) {
      continue;
    }

    setField(field, changes[field], field);
  }

  const expressions = [];
  if (setExpressions.length) {
    expressions.push(`SET ${setExpressions.join(', ')}`);
  }

  if (removeExpressions.length) {
    expressions.push(`REMOVE ${removeExpressions.join(', ')}`);
  }

  const result = await documentClient.send(
    new UpdateCommand({
      TableName: env.PRODUCTS_TABLE,
      Key: {
        pk: pkStall(stallId),
        sk: skProduct(productId),
      },
      UpdateExpression: expressions.join(' '),
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
  getProduct,
  createProduct,
  updateProduct,
  deleteProduct,
};