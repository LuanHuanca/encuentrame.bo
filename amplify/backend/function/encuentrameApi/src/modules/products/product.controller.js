'use strict';

const { ok, parseJsonBody } = require('../../shared/http/response');
const productService = require('./product.service');

async function create({ currentUser, stallId, event }) {
  const body = parseJsonBody(event);
  const data = await productService.create(currentUser, stallId, body);
  return ok(data);
}

async function list({ currentUser, stallId }) {
  const data = await productService.list(currentUser, stallId);
  return ok(data);
}

async function update({ currentUser, stallId, productId, event }) {
  const body = parseJsonBody(event);
  const data = await productService.update(currentUser, stallId, productId, body);
  return ok(data);
}

async function remove({ currentUser, stallId, productId }) {
  const data = await productService.remove(currentUser, stallId, productId);
  return ok(data);
}

module.exports = {
  create,
  list,
  update,
  remove,
};