'use strict';

const config = require('../config');
const { ok, bad, parseJsonBody } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const {
  GetCommand,
  UpdateCommand,
  PutCommand,
} = require('@aws-sdk/lib-dynamodb');

function pkUser(userId) {
  return `USER#${userId}`;
}

function callerEmail(caller) {
  return caller?.email || caller?.username || null;
}

async function me({ caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const emailFromToken = callerEmail(caller) || '';

  if (!config.USERS_TABLE) {
    return ok({
      userId,
      name: '',
      email: emailFromToken,
    });
  }

  const key = { pk: pkUser(userId), sk: 'PROFILE' };

  const response = await ddb.send(
    new GetCommand({
      TableName: config.USERS_TABLE,
      Key: key,
    })
  );

  let item = response.Item || null;

  if (!item) {
    const now = new Date().toISOString();

    item = {
      ...key,
      entityType: 'USER',
      userId,
      name: '',
      email: emailFromToken,
      createdAt: now,
      updatedAt: now,
    };

    try {
      await ddb.send(
        new PutCommand({
          TableName: config.USERS_TABLE,
          Item: item,
        })
      );
    } catch (_) {}
  }

  return ok({
    userId,
    name: item.name || '',
    email: item.email || emailFromToken || '',
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
  });
}

async function updateMe({ caller, event }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!config.USERS_TABLE) {
    return bad(500, 'ENV_MISSING', 'Falta USERS_TABLE');
  }

  const body = parseJsonBody(event);
  const name = String(body.name || '').trim();

  if (!name) return bad(400, 'VALIDATION', 'Nombre requerido');
  if (name.length < 2) return bad(400, 'VALIDATION', 'Nombre no válido');
  if (name.length > 60) return bad(400, 'VALIDATION', 'Máximo 60 caracteres');

  const email = callerEmail(caller) || null;
  const now = new Date().toISOString();

  const output = await ddb.send(
    new UpdateCommand({
      TableName: config.USERS_TABLE,
      Key: { pk: pkUser(userId), sk: 'PROFILE' },
      UpdateExpression:
        'SET entityType = if_not_exists(entityType, :type), userId = if_not_exists(userId, :uid), #name = :name, email = if_not_exists(email, :email), updatedAt = :now',
      ExpressionAttributeNames: {
        '#name': 'name',
      },
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

  const item = output.Attributes || {};

  return ok({
    userId,
    name: item.name || '',
    email: item.email || email || '',
    updatedAt: item.updatedAt || now,
  });
}

module.exports = {
  me,
  updateMe,
};