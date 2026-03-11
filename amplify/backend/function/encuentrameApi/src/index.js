'use strict';

const { route } = require('./app/router');
const { toErrorResponse } = require('./shared/http/response');
const { logger } = require('./shared/logging/logger');

exports.handler = async (event) => {
  try {
    return await route(event);
  } catch (error) {
    logger.error('UNHANDLED_ERROR', {
      name: error?.name,
      message: error?.message,
      stack: error?.stack,
      statusCode: error?.statusCode,
      requestId: event?.requestContext?.requestId || null,
    });

    return toErrorResponse(error);
  }
};