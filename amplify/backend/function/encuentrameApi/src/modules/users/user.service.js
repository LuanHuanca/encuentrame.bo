'use strict';

const { env } = require('../../shared/config/env');
const { AppError } = require('../../shared/errors/app-error');
const { buildUserProfile } = require('./user.model');
const { toUserResponse } = require('./user.mapper');
const { validateUpdateProfileInput } = require('./user.validator');
const repository = require('./user.repository');

function assertAuthenticated(currentUser) {
  if (!currentUser?.userId) {
    throw new AppError({
      code: 'UNAUTHORIZED',
      message: 'No autenticado',
      statusCode: 401,
    });
  }
}

async function getMyProfile(currentUser) {
  assertAuthenticated(currentUser);

  const userId = currentUser.userId;
  const email = currentUser.email || '';

  if (!env.USERS_TABLE) {
    return {
      userId,
      name: '',
      email,
      createdAt: null,
      updatedAt: null,
    };
  }

  let profile = await repository.findProfileByUserId(userId);

  if (!profile) {
    const now = new Date().toISOString();

    profile = buildUserProfile({
      userId,
      name: '',
      email,
      createdAt: now,
      updatedAt: now,
    });

    await repository.createProfile(profile);
  }

  return toUserResponse(profile);
}

async function updateMyProfile(currentUser, payload) {
  assertAuthenticated(currentUser);

  if (!env.USERS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta USERS_TABLE',
      statusCode: 500,
    });
  }

  const { name } = validateUpdateProfileInput(payload);
  const userId = currentUser.userId;
  const email = currentUser.email || null;
  const updatedAt = new Date().toISOString();

  const profile = await repository.upsertProfileBasics({
    userId,
    name,
    email,
    updatedAt,
  });

  return toUserResponse(profile);
}

module.exports = {
  getMyProfile,
  updateMyProfile,
};