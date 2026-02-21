/* eslint-disable */
function getCaller(event) {
  const claims =
    event?.requestContext?.authorizer?.claims ||
    event?.requestContext?.authorizer?.jwt?.claims ||
    null;

  if (claims?.sub) {
    return { userId: claims.sub, email: claims.email || null };
  }

  // fallback IAM identity id (si algún día lo usas)
  const identityId = event?.requestContext?.identity?.cognitoIdentityId || null;
  if (identityId) return { userId: identityId, email: null };

  return null;
}

module.exports = { getCaller };