/* Amplify Params - DO NOT EDIT
	ENV
	REGION
Amplify Params - DO NOT EDIT */
/* eslint-disable */
const { route } = require('./router');
const { corsHeaders } = require('./util/http');

exports.handler = async (event) => {
  try {
    return await route(event);
  } catch (e) {
    console.log('UNHANDLED_ERROR', e);
    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({ error: { code: 'INTERNAL', message: 'Error interno', details: String(e) } }),
    };
  }
};