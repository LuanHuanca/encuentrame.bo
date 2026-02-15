const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand
} = require("@aws-sdk/lib-dynamodb");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const USERS_TABLE = process.env.USERS_TABLE;

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

// ✅ Soporta 2 escenarios:
// 1) User Pool authorizer (claims.sub)
// 2) AWS_IAM + Identity Pool (cognitoIdentityId / cognitoAuthenticationProvider)
function getUserId(event) {
  // Caso 1: si algún día usas authorizer con JWT (UserPool)
  const claims = event?.requestContext?.authorizer?.claims;
  if (claims?.sub) return claims.sub;

  // Caso 2: AWS_IAM (Amplify REST típico)
  const id = event?.requestContext?.identity || {};

  // A veces trae el sub aquí: "...:CognitoSignIn:<SUB>,..."
  const provider = id.cognitoAuthenticationProvider || "";
  const marker = "CognitoSignIn:";
  const idx = provider.indexOf(marker);
  if (idx >= 0) {
    const sub = provider.substring(idx + marker.length).split(",")[0].trim();
    if (sub) return sub;
  }

  // Fallback estable: Identity Pool ID
  if (id.cognitoIdentityId) return id.cognitoIdentityId;

  throw new Error("Missing identity (unauthorized?)");
}

exports.handler = async (event) => {
  try {
    const method = event.httpMethod;
    const path = event.path;

    // Health check
    if (method === "GET" && path === "/api") {
      return json(200, { ok: true, message: "encuentrame API up" });
    }

    // POST /api/me/bootstrap
    if (method === "POST" && path === "/api/me/bootstrap") {
      if (!USERS_TABLE) {
        return json(500, { error: "USERS_TABLE env var is missing" });
      }

      const userId = getUserId(event);
      const body = event.body ? JSON.parse(event.body) : {};

      const role = body.role; // SELLER | BUYER
      const displayName = body.displayName || "";

      if (!["SELLER", "BUYER"].includes(role)) {
        return json(400, { error: "role must be SELLER or BUYER" });
      }

      const pk = `USER#${userId}`;

      const existing = await ddb.send(
        new GetCommand({
          TableName: USERS_TABLE,
          Key: { pk },
        })
      );

      if (existing.Item) {
        return json(200, { created: false, user: existing.Item });
      }

      const userItem = {
        pk,
        role,
        displayName,
        createdAt: new Date().toISOString(),
      };

      await ddb.send(
        new PutCommand({
          TableName: USERS_TABLE,
          Item: userItem,
          ConditionExpression: "attribute_not_exists(pk)",
        })
      );

      return json(201, { created: true, user: userItem });
    }

    return json(404, { error: "Not found", method, path });
  } catch (err) {
    return json(500, { error: String(err?.message || err) });
  }
};
