'use strict';

const { route } = require('./router');
const { corsHeaders } = require('./util/http');

exports.handler = async (event) => {
  try {
    return await route(event);
  } catch (error) {
    console.log('UNHANDLED_ERROR', {
      name: error?.name,
      message: error?.message,
      stack: error?.stack,
      status: error?.$metadata?.httpStatusCode,
    });

    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({
        error: {
          code: 'INTERNAL',
          message: 'Error interno',
          details:
            process.env.ENV === 'dev'
              ? String(error?.message || 'Unknown error')
              : undefined,
        },
      }),
    };
  }
};