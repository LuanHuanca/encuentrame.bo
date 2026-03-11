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
    })
  );

  return item;
}

async function upsertProfileBasics({
  userId,
  name,
  email,
  updatedAt,
}) {
  const result = await documentClient.send(
    new UpdateCommand({
      TableName: env.USERS_TABLE,
      Key: getProfileKey(userId),
      UpdateExpression:
        'SET entityType = if_not_exists(entityType, :entityType), userId = if_not_exists(userId, :userId), #name = :name, email = if_not_exists(email, :email), updatedAt = :updatedAt',
      ExpressionAttributeNames: {
        '#name': 'name',
      },
      ExpressionAttributeValues: {
        ':entityType': 'USER',
        ':userId': userId,
        ':name': name,
        ':email': email,
        ':updatedAt': updatedAt,
      },
      ReturnValues: 'ALL_NEW',
    })
  );

  return result.Attributes || null;
}

module.exports = {
  findProfileByUserId,
  createProfile,
  upsertProfileBasics,
};