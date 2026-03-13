'use strict';

const { ok } = require('../../shared/http/response');
const marketService = require('./market.service');

async function listCategories({ currentUser }) {
  const data = await marketService.listCategories(currentUser);
  return ok(data);
}

async function listOpenStallsNear({ event, currentUser }) {
  const data = await marketService.listOpenStallsNear({
    currentUser,
    query: event?.queryStringParameters || {},
  });

  return ok(data);
}

async function searchProductsNear({ event, currentUser }) {
  const data = await marketService.searchProductsNear({
    currentUser,
    query: event?.queryStringParameters || {},
  });

  return ok(data);
}

async function getPublicStallDetail({ event, currentUser, stallId }) {
  const data = await marketService.getPublicStallDetail({
    currentUser,
    stallId,
    query: event?.queryStringParameters || {},
  });

  return ok(data);
}

async function listPublicStallProducts({ currentUser, stallId, event }) {
  const data = await marketService.listPublicStallProducts({
    currentUser,
    stallId,
    query: event?.queryStringParameters || {},
  });

  return ok(data);
}

async function getPublicVendorProfile({ currentUser, userId, event }) {
  const data = await marketService.getPublicVendorProfile({
    currentUser,
    userId,
    query: event?.queryStringParameters || {},
  });

  return ok(data);
}

module.exports = {
  listCategories,
  listOpenStallsNear,
  searchProductsNear,
  getPublicStallDetail,
  listPublicStallProducts,
  getPublicVendorProfile,
};