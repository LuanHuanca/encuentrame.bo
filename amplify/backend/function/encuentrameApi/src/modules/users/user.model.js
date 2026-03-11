'use strict';

function buildUserProfile({
  userId,
  name = '',
  email = '',
  createdAt,
  updatedAt,
}) {
  return {
    pk: `USER#${userId}`,
    sk: 'PROFILE',
    entityType: 'USER',
    userId,
    name,
    email,
    createdAt,
    updatedAt,
  };
}

module.exports = {
  buildUserProfile,
};