'use strict';

const { ok } = require('../../shared/http/response');
const { parseJsonBody } = require('../../shared/http/response');
const stallService = require('./stall.service');

async function listMine({ currentUser }) {
  const data = await stallService.listMine(currentUser);
  return ok(data);
}

async function create({ currentUser, event }) {
  const body = parseJsonBody(event);
  const data = await stallService.create(currentUser, body);
  return ok(data);
}

async function get({ currentUser, stallId }) {
  const data = await stallService.get(currentUser, stallId);
  return ok(data);
}

async function update({ currentUser, stallId, event }) {
  const body = parseJsonBody(event);
  const data = await stallService.update(currentUser, stallId, body);
  return ok(data);
}

async function remove({ currentUser, stallId }) {
  const data = await stallService.remove(currentUser, stallId);
  return ok(data);
}

async function open({ currentUser, event }) {
  const body = parseJsonBody(event);
  const data = await stallService.open(currentUser, body);
  return ok(data);
}

async function getCurrent({ currentUser, stallId }) {
  const data = await stallService.getCurrent(currentUser, stallId);
  return ok(data);
}

async function close({ currentUser, stallId }) {
  const data = await stallService.close(currentUser, stallId);
  return ok(data);
}

async function listOpenings({ currentUser, stallId, event }) {
  const data = await stallService.listOpenings(
    currentUser,
    stallId,
    event?.queryStringParameters || {}
  );
  return ok(data);
}

async function getMy({ currentUser }) {
  const data = await stallService.getMy(currentUser);
  return ok(data);
}

module.exports = {
  listMine,
  create,
  get,
  update,
  remove,
  open,
  getCurrent,
  close,
  listOpenings,
  getMy,
};