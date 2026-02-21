/* Amplify Params - DO NOT EDIT
	ENV
	REGION
Amplify Params - DO NOT EDIT *//* eslint-disable */
const { route } = require('./router');

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

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
  };
}