/* eslint-disable */
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || 'us-east-1';
const USERS_TABLE = process.env.USERS_TABLE;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true },
});

async function getUser(Key) {
  const out = await ddb.send(new GetCommand({ TableName: USERS_TABLE, Key }));
  return out.Item || null;
}

async function putUser(Item) {
  await ddb.send(new PutCommand({ TableName: USERS_TABLE, Item }));
}

async function updateUser({ Key, UpdateExpression, ExpressionAttributeNames, ExpressionAttributeValues }) {
  const out = await ddb.send(new UpdateCommand({
    TableName: USERS_TABLE,
    Key,
    UpdateExpression,
    ExpressionAttributeNames,
    ExpressionAttributeValues,
    ReturnValues: 'ALL_NEW',
  }));
  return out.Attributes;
}

module.exports = { getUser, putUser, updateUser };