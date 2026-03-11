'use strict';

function toCategoryResponse(categories) {
  return {
    categories,
    count: categories.length,
  };
}

function toOpenStallsResponse({ radiusKm, stalls }) {
  return {
    radiusKm,
    count: stalls.length,
    stalls,
  };
}

function toProductSearchResponse({ q, radiusKm, results }) {
  return {
    q,
    radiusKm,
    count: results.length,
    results,
  };
}

function toPublicStallDetailResponse({ stall, opening, products }) {
  return {
    stall,
    opening,
    products,
    countProducts: products.length,
  };
}

function toPublicStallProductsResponse({ stallId, products }) {
  return {
    stallId,
    count: products.length,
    products,
  };
}

module.exports = {
  toCategoryResponse,
  toOpenStallsResponse,
  toProductSearchResponse,
  toPublicStallDetailResponse,
  toPublicStallProductsResponse,
};