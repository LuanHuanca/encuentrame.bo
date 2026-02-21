/* eslint-disable */
function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
  };
}
function jsonBody(event) {
  if (!event.body) return {};
  try { return JSON.parse(event.body); } catch { return {}; }
}
function res(statusCode, body) {
  return { statusCode, headers: corsHeaders(), body: JSON.stringify(body) };
}
function ok(body) { return res(200, body); }
function bad(status, code, message, details) {
  return res(status, { error: { code, message, details: details ?? null } });
}
module.exports = { corsHeaders, jsonBody, ok, bad };