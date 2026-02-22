/* eslint-disable */

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  };
}

function ok(body = {}, statusCode = 200) {
  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify(body),
  };
}

function bad(statusCode = 400, code = 'ERROR', message = 'Error', details) {
  const err = { code, message };
  if (details !== undefined && details !== null && String(details).length) {
    err.details = String(details);
  }

  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify({ error: err }),
  };
}

function options() {
  return {
    statusCode: 204,
    headers: corsHeaders(),
    body: '',
  };
}

module.exports = { corsHeaders, ok, bad, options };