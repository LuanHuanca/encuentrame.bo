'use strict';

function toProductResponse(item = {}) {
  return {
    productId: item.productId,
    canonical: item.canonical,
    display: item.display,
    category: item.category ?? null,
    price: item.price ?? null,
    active: item.active ?? true,
    lastQty: item.lastQty ?? null,
    lastSeenAt: item.lastSeenAt ?? null,
  };
}

function toListResponse(products) {
  return {
    products,
  };
}

function toSimpleOk() {
  return {
    ok: true,
  };
}

module.exports = {
  toProductResponse,
  toListResponse,
  toSimpleOk,
};