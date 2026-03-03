'use strict';

const config = require('../config');
const { ok, bad } = require('../util/http');
const { getUserId } = require('../util/auth');
const { ddb } = require('../services/aws');
const { GetCommand } = require('@aws-sdk/lib-dynamodb');

function pkUser(userId) { return `USER#${userId}`; }

async function me({ caller }) {
  const userId = getUserId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  if (!config.USERS_TABLE) {
    return ok({ userId, name: '', email: '' });
  }

  const res = await ddb.send(new GetCommand({
    TableName: config.USERS_TABLE,
    Key: { pk: pkUser(userId), sk: 'PROFILE' }
  }));

  const item = res.Item || null;

  return ok({
    userId,
    name: item?.name || '',
    email: item?.email || ''
  });
}

module.exports = { me };