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

function toPublicStallDetailResponse({ stall, vendor, opening, products }) {
  return {
    stall,
    vendor,
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

function toPublicVendorResponse({ vendor, stalls }) {
  return {
    vendor,
    stalls,
    countStalls: Number(vendor?.stallCount || stalls.length),
  };
}

module.exports = {
  toCategoryResponse,
  toOpenStallsResponse,
  toProductSearchResponse,
  toPublicStallDetailResponse,
  toPublicStallProductsResponse,
  toPublicVendorResponse,
};