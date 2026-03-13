'use strict';

const {
  GetCommand,
  PutCommand,
  UpdateCommand,
} = require('@aws-sdk/lib-dynamodb');

const { documentClient } = require('../../integrations/dynamodb/dynamo-client');
const { env } = require('../../shared/config/env');

function getProfileKey(userId) {
  return {
    pk: `USER#${userId}`,
    sk: 'PROFILE',
  };
}

async function findProfileByUserId(userId) {
  const result = await documentClient.send(
    new GetCommand({
      TableName: env.USERS_TABLE,
      Key: getProfileKey(userId),
    })
  );

  return result.Item || null;
}

async function createProfile(item) {
  await documentClient.send(
    new PutCommand({
      TableName: env.USERS_TABLE,
      Item: item,
      ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
    })
  );

  return item;
}

async function updateProfile({ userId, changes }) {
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

  const updatableFields = [
    'firstName',
    'lastName',
    'displayName',
    'name',
    'phone',
    'gender',
    'city',
    'zone',
    'birthDate',
    'photoKey',
  ];

  for (const field of updatableFields) {
    if (!(field in changes)) {
      continue;
    }

    const value = changes[field];

    if (value === null) {
      removeField(field, field);
      continue;
    }

    setField(field, value, field);
  }

  if ('email' in changes && changes.email) {
    setField('email', changes.email, 'email');
  }

  if ('isActive' in changes && typeof changes.isActive === 'boolean') {
    setField('isActive', changes.isActive, 'isActive');
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
      TableName: env.USERS_TABLE,
      Key: getProfileKey(userId),
      UpdateExpression: expressions.join(' '),
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values,
      ConditionExpression: 'attribute_exists(pk) AND attribute_exists(sk)',
      ReturnValues: 'ALL_NEW',
    })
  );

  return result.Attributes || null;
}

module.exports = {
  findProfileByUserId,
  createProfile,
  updateProfile,
};