/* eslint-disable */
const { ok, bad } = require('../util/http');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const USERS_TABLE = process.env.USERS_TABLE;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true },
});

function callerId(caller) {
  return caller?.sub || caller?.userId || caller?.identityId || caller?.cognitoIdentityId || null;
}

function callerEmail(caller) {
  return caller?.email || null;
}

function pkUser(userId) {
  return `USER#${userId}`;
}

function jsonBody(event) {
  try {
    return event?.body ? JSON.parse(event.body) : {};
  } catch {
    return {};
  }
}

exports.me = async ({ caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const emailFromToken = callerEmail(caller) || '';

  if (!USERS_TABLE) {
    return ok({ userId, name: '', email: emailFromToken, role: '' });
  }

  const res = await ddb.send(
    new GetCommand({
      TableName: USERS_TABLE,
      Key: { pk: pkUser(userId), sk: 'PROFILE' },
    })
  );

  const item = res.Item || null;

  return ok({
    userId,
    role: item?.role || '',
    name: item?.name || '',
    email: item?.email || emailFromToken || '',
  });
};

exports.updateMe = async ({ caller, event }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!USERS_TABLE) return bad(500, 'ENV_MISSING', 'Falta USERS_TABLE');

  const body = jsonBody(event);
  const name = String(body.name || '').trim();

  if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');
  if (name.length < 2) return bad(400, 'VALIDATION', 'Nombre no válido');
  if (name.length > 60) return bad(400, 'VALIDATION', 'Máximo 60 caracteres');

  const email = callerEmail(caller) || null;
  const now = new Date().toISOString();

  const out = await ddb.send(
    new UpdateCommand({
      TableName: USERS_TABLE,
      Key: { pk: pkUser(userId), sk: 'PROFILE' },
      UpdateExpression:
        'SET entityType = if_not_exists(entityType, :type), userId = if_not_exists(userId, :uid), #name = :name, email = if_not_exists(email, :email), updatedAt = :now',
      ExpressionAttributeNames: { '#name': 'name' },
      ExpressionAttributeValues: {
        ':type': 'USER',
        ':uid': userId,
        ':name': name,
        ':email': email,
        ':now': now,
      },
      ReturnValues: 'ALL_NEW',
    })
  );

  const item = out.Attributes || {};

  return ok({
    userId,
    name: item.name || '',
    email: item.email || email || '',
    updatedAt: item.updatedAt || now,
  });
};