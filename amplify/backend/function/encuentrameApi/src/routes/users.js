/* eslint-disable */
const { ok, bad, jsonBody } = require('../util/http');
const { getUser, putUser, updateUser } = require('../util/ddb');

function nowIso() { return new Date().toISOString(); }

async function getMe({ caller }) {
  if (!caller) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  // Diseño en tu tabla users-dev:
  // pk = USER#<cognitoSub>
  // sk = PROFILE
  const Key = { pk: `USER#${caller.userId}`, sk: 'PROFILE' };
  let profile = await getUser(Key);

  if (!profile) {
    profile = {
      ...Key,
      entityType: 'USER',
      userId: caller.userId,
      email: caller.email,
      role: null,
      name: null,
      phone: null,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    await putUser(profile);
  }

  return ok({
    userId: profile.userId,
    email: profile.email,
    role: profile.role,
    name: profile.name,
    phone: profile.phone,
  });
}

async function putMe({ event, caller }) {
  if (!caller) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  const body = jsonBody(event);
  const role = body.role ?? null;
  const name = body.name ?? null;
  const phone = body.phone ?? null;

  if (role && !['VENDOR', 'BUYER'].includes(role)) {
    return bad(400, 'VALIDATION', 'role inválido (VENDOR|BUYER)');
  }

  const Key = { pk: `USER#${caller.userId}`, sk: 'PROFILE' };
  const updated = await updateUser({
    Key,
    UpdateExpression:
      'SET #role=:role, #name=:name, #phone=:phone, #email=if_not_exists(#email,:email), #userId=if_not_exists(#userId,:userId), #updatedAt=:updatedAt, #createdAt=if_not_exists(#createdAt,:createdAt), #entityType=:entityType',
    ExpressionAttributeNames: {
      '#role': 'role',
      '#name': 'name',
      '#phone': 'phone',
      '#email': 'email',
      '#userId': 'userId',
      '#updatedAt': 'updatedAt',
      '#createdAt': 'createdAt',
      '#entityType': 'entityType',
    },
    ExpressionAttributeValues: {
      ':role': role,
      ':name': name,
      ':phone': phone,
      ':email': caller.email,
      ':userId': caller.userId,
      ':updatedAt': nowIso(),
      ':createdAt': nowIso(),
      ':entityType': 'USER',
    },
  });

  return ok({
    userId: updated.userId,
    email: updated.email,
    role: updated.role,
    name: updated.name,
    phone: updated.phone,
  });
}

module.exports = { getMe, putMe };