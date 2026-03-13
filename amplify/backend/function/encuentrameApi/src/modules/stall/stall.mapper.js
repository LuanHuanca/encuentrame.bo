'use strict';

function toListMineResponse(stalls) {
  return {
    stalls,
  };
}

function toCreateResponse(stall) {
  return {
    stall,
  };
}

function toGetResponse(stall) {
  return {
    stall,
  };
}

function toSimpleOk() {
  return {
    ok: true,
  };
}

function toGetCurrentResponse({ stall, opening }) {
  return {
    stall,
    opening,
  };
}

function toListOpeningsResponse(openings) {
  return {
    openings,
  };
}

function toOpenResponse({
  stallId,
  openingKey,
  status,
  location,
  inventory,
}) {
  return {
    stallId,
    openingKey,
    status,
    location,
    inventory,
  };
}

module.exports = {
  toListMineResponse,
  toCreateResponse,
  toGetResponse,
  toSimpleOk,
  toGetCurrentResponse,
  toListOpeningsResponse,
  toOpenResponse,
};