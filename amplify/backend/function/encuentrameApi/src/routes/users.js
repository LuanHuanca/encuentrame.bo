/* eslint-disable */
const { ok, bad } = require('../util/http');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const USERS_TABLE = process.env.USERS_TABLE; // asegúrate de tenerla (users-dev)

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }), {
  marshallOptions: { removeUndefinedValues: true },
});

function callerId(caller) {
  return caller?.sub || caller?.userId || caller?.identityId || caller?.cognitoIdentityId || null;
}

function pkUser(userId) { return `USER#${userId}`; }

exports.me = async ({ caller }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');

  // Si aún no configuraste USERS_TABLE, igual no rompas el app
  if (!USERS_TABLE) {
    return ok({ userId, role: '' });
  }

  const res = await ddb.send(new GetCommand({
    TableName: USERS_TABLE,
    Key: { pk: pkUser(userId), sk: 'PROFILE' },
  }));

  const item = res.Item || null;
  const role = item?.role || '';

  return ok({
    userId,
    role,
    name: item?.name || '',
    email: item?.email || '',
  });
};

// (Opcional) endpoint para setear rol desde onboarding si lo quieres luego
exports.setRole = async ({ caller, event }) => {
  const userId = callerId(caller);
  if (!userId) return bad(401, 'UNAUTHORIZED', 'No autenticado');
  if (!USERS_TABLE) return bad(500, 'ENV_MISSING', 'Falta USERS_TABLE');

  const body = event?.body ? JSON.parse(event.body) : {};
  const role = String(body.role || '').trim();
  const name = String(body.name || '').trim();

  if (!role) return bad(400, 'VALIDATION', 'role requerido');

  await ddb.send(new PutCommand({
    TableName: USERS_TABLE,
    Item: {
      pk: pkUser(userId),
      sk: 'PROFILE',
      entityType: 'USER',
      userId,
      role,
      name: name || null,
      updatedAt: new Date().toISOString(),
    },
  }));

  return ok({ ok: true, role });
};