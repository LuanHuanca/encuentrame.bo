'use strict';

const { ok, parseJsonBody } = require('../../shared/http/response');
const userService = require('./user.service');

async function getMe({ currentUser }) {
  const profile = await userService.getMyProfile(currentUser);
  return ok(profile);
}

async function updateMe({ event, currentUser }) {
  const body = parseJsonBody(event);
  const profile = await userService.updateMyProfile(currentUser, body);
  return ok(profile);
}

module.exports = {
  getMe,
  updateMe,
};