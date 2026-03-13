'use strict';

function toNullableString(value) {
  const text = String(value || '').trim();
  return text || null;
}

function toProductResponse(item = {}) {
  const stock = Number.isFinite(Number(item.lastQty)) ? Number(item.lastQty) : 0;

  return {
    productId: item.productId || '',
    stallId: item.stallId || '',
    canonical: item.canonical || '',
    display: item.display || '',
    category: toNullableString(item.category),
    description: toNullableString(item.description),
    photoKey: toNullableString(item.photoKey),
    price: item.price ?? null,
    active: item.active !== false,
    stock,
    lastQty: stock,
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
    lastSeenAt: item.lastSeenAt || null,
  };
}

function toListResponse(products) {
  return {
    products,
    count: products.length,
  };
}

function toCreateResponse(product) {
  return {
    ok: true,
    product,
  };
}

function toUpdateResponse(product) {
  return {
    ok: true,
    product,
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
  toCreateResponse,
  toUpdateResponse,
  toSimpleOk,
};