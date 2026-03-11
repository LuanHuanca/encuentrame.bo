'use strict';

function getClaims(event) {
  return (
    event?.requestContext?.authorizer?.claims ||
    event?.requestContext?.authorizer?.jwt?.claims ||
    null
  );
}

function getIdentity(event) {
  return event?.requestContext?.identity || null;
}

function getCurrentUser(event) {
  const claims = getClaims(event);
  const identity = getIdentity(event);

  const source = claims || identity || {};

  return {
    raw: source,
    userId:
      source?.sub ||
      source?.username ||
      source?.userId ||
      source?.identityId ||
      source?.cognitoIdentityId ||
      null,
    email: source?.email || source?.username || null,
  };
}

module.exports = {
  getCurrentUser,
};