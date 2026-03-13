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

function ensureUsersEnv() {
  if (!env.USERS_TABLE) {
    throw new AppError({
      code: 'ENV_MISSING',
      message: 'Falta USERS_TABLE',
      statusCode: 500,
    });
  }
}

function nowIso() {
  return new Date().toISOString();
}

function buildDisplayName(firstName, lastName, fallback = '') {
  const fullName = [firstName, lastName]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join(' ')
    .trim();

  return fullName || String(fallback || '').trim() || '';
}

async function ensureProfileExists(currentUser) {
  const existing = await repository.findProfileByUserId(currentUser.userId);

  if (existing) {
    return existing;
  }

  const now = nowIso();
  const newProfile = buildUserProfile({
    userId: currentUser.userId,
    email: currentUser.email || '',
    createdAt: now,
    updatedAt: now,
    isActive: true,
  });

  try {
    await repository.createProfile(newProfile);
    return newProfile;
  } catch (error) {
    if (error?.name === 'ConditionalCheckFailedException') {
      return repository.findProfileByUserId(currentUser.userId);
    }
    throw error;
  }
}

async function getMyProfile(currentUser) {
  assertAuthenticated(currentUser);
  ensureUsersEnv();

  const profile = await ensureProfileExists(currentUser);
  return toUserResponse(profile, currentUser);
}

async function updateMyProfile(currentUser, payload) {
  assertAuthenticated(currentUser);
  ensureUsersEnv();

  const existing = await ensureProfileExists(currentUser);
  const validatedChanges = validateUpdateProfileInput(payload);

  const nextFirstName =
    validatedChanges.firstName !== undefined
      ? validatedChanges.firstName
      : existing.firstName || null;

  const nextLastName =
    validatedChanges.lastName !== undefined
      ? validatedChanges.lastName
      : existing.lastName || null;

  const currentFallbackName =
    existing.displayName ||
    existing.name ||
    '';

  const nextDisplayName = buildDisplayName(
    nextFirstName,
    nextLastName,
    currentFallbackName
  );

  const changes = {
    ...validatedChanges,
    displayName: nextDisplayName || null,
    name: nextDisplayName || null,
    email: currentUser.email || existing.email || '',
    updatedAt: nowIso(),
  };

  const updatedProfile = await repository.updateProfile({
    userId: currentUser.userId,
    changes,
  });

  return toUserResponse(updatedProfile, currentUser);
}

module.exports = {
  getMyProfile,
  updateMyProfile,
};