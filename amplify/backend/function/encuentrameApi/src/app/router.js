'use strict';

const {
  options,
  notFound,
  methodNotAllowed,
  ok,
} = require('../shared/http/response');
const { getCurrentUser } = require('../shared/auth/current-user');
const usersController = require('../modules/users/user.controller');
const marketController = require('../modules/market/market.controller');
const stallsController = require('../modules/stall/stall.controller');
const productsController = require('../modules/products/product.controller');

function pathParts(path) {
  return String(path || '')
    .split('?')[0]
    .split('/')
    .filter(Boolean);
}

function stripApiPrefix(parts) {
  const apiIndex = parts.indexOf('api');
  return apiIndex >= 0 ? parts.slice(apiIndex + 1) : parts;
}

async function route(event) {
  const method = String(event?.httpMethod || '').toUpperCase();
  const parts = stripApiPrefix(pathParts(event?.path));
  const currentUser = getCurrentUser(event);

  if (method === 'OPTIONS') {
    return options();
  }

  if (parts[0] === 'health' && parts.length === 1) {
    if (method === 'GET') {
      return ok({
        ok: true,
        service: 'encuentrame-api',
      });
    }

    return methodNotAllowed();
  }

  // USERS
  if (parts[0] === 'users' && parts[1] === 'me' && parts.length === 2) {
    if (method === 'GET') {
      return usersController.getMe({ event, currentUser });
    }

    if (method === 'PUT') {
      return usersController.updateMe({ event, currentUser });
    }

    return methodNotAllowed();
  }

  // MARKET
  if (parts[0] === 'market' && parts[1] === 'categories' && parts.length === 2) {
    if (method === 'GET') {
      return marketController.listCategories({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (parts[0] === 'market' && parts[1] === 'open-stalls' && parts.length === 2) {
    if (method === 'GET') {
      return marketController.listOpenStallsNear({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'products' &&
    parts[2] === 'search' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return marketController.searchProductsNear({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'vendors' &&
    parts[2] &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return marketController.getPublicVendorProfile({
        event,
        currentUser,
        userId: parts[2],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'stalls' &&
    parts[2] &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return marketController.getPublicStallDetail({
        event,
        currentUser,
        stallId: parts[2],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'market' &&
    parts[1] === 'stalls' &&
    parts[2] &&
    parts[3] === 'products' &&
    parts.length === 4
  ) {
    if (method === 'GET') {
      return marketController.listPublicStallProducts({
        event,
        currentUser,
        stallId: parts[2],
      });
    }

    return methodNotAllowed();
  }

  // STALLS
  if (parts[0] === 'stalls' && parts.length === 1) {
    if (method === 'GET') {
      return stallsController.listMine({ event, currentUser });
    }

    if (method === 'POST') {
      return stallsController.create({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (parts[0] === 'stalls' && parts[1] === 'my' && parts.length === 2) {
    if (method === 'GET') {
      return stallsController.getMy({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (parts[0] === 'stalls' && parts[1] === 'open' && parts.length === 2) {
    if (method === 'POST') {
      return stallsController.open({ event, currentUser });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'products' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return productsController.list({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    if (method === 'POST') {
      return productsController.create({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'products' &&
    parts[3] &&
    parts.length === 4
  ) {
    if (method === 'PUT') {
      return productsController.update({
        event,
        currentUser,
        stallId: parts[1],
        productId: parts[3],
      });
    }

    if (method === 'DELETE') {
      return productsController.remove({
        event,
        currentUser,
        stallId: parts[1],
        productId: parts[3],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'current' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return stallsController.getCurrent({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'close' &&
    parts.length === 3
  ) {
    if (method === 'POST') {
      return stallsController.close({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    return methodNotAllowed();
  }

  if (
    parts[0] === 'stalls' &&
    parts[1] &&
    parts[2] === 'openings' &&
    parts.length === 3
  ) {
    if (method === 'GET') {
      return stallsController.listOpenings({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    return methodNotAllowed();
  }

  if (parts[0] === 'stalls' && parts[1] && parts.length === 2) {
    if (method === 'GET') {
      return stallsController.get({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    if (method === 'PUT') {
      return stallsController.update({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    if (method === 'DELETE') {
      return stallsController.remove({
        event,
        currentUser,
        stallId: parts[1],
      });
    }

    return methodNotAllowed();
  }

  return notFound();
}

module.exports = {
  route,
};