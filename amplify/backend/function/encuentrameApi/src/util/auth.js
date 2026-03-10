'use strict';

function getCaller(event) {
  const claims =
    event?.requestContext?.authorizer?.claims ||
    event?.requestContext?.authorizer?.jwt?.claims ||
    null;

  if (claims) return claims;

  const identity = event?.requestContext?.identity || null;
  if (identity) return identity;

  return null;
}

function getUserId(caller) {
  return (
    caller?.sub ||
    caller?.username ||
    caller?.userId ||
    caller?.identityId ||
    caller?.cognitoIdentityId ||
    caller?._identity?.cognitoIdentityId ||
    null
  );
}

module.exports = {
  getCaller,
  getUserId,
};