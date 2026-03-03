'use strict';

function getCaller(event) {
  const claims =
    event?.requestContext?.authorizer?.claims ||
    event?.requestContext?.authorizer?.jwt?.claims ||
    null;

  const identity = event?.requestContext?.identity || null;

  if (claims) return { ...claims, _identity: identity };
  if (event?.requestContext?.authorizer) return { ...event.requestContext.authorizer, _identity: identity };
  if (identity) return identity;

  return null;
}

function getUserId(caller) {
  return (
    caller?.sub ||
    caller?.userId ||
    caller?.identityId ||
    caller?.cognitoIdentityId ||
    caller?._identity?.cognitoIdentityId ||
    null
  );
}

module.exports = { getCaller, getUserId };