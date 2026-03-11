'use strict';

function toUserResponse(item = {}) {
  return {
    userId: item.userId || '',
    name: item.name || '',
    email: item.email || '',
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
  };
}

module.exports = {
  toUserResponse,
};