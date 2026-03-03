'use strict';

const { route } = require('./router');
const { corsHeaders } = require('./util/http');

exports.handler = async (event) => {
  try {
    return await route(event);
  } catch (e) {
    console.log('UNHANDLED_ERROR', {
      name: e?.name,
      message: e?.message,
      status: e?.$metadata?.httpStatusCode
    });

    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({ error: { code: 'INTERNAL', message: 'Error interno' } })
    };
  }
};