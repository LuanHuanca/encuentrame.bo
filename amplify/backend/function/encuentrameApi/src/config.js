'use strict';

function env(name, fallback = undefined) {
  const v = process.env[name];
  return (v === undefined || v === null || String(v).trim() === '') ? fallback : v;
}

const REGION = env('AWS_REGION', env('REGION', 'us-east-1'));

module.exports = Object.freeze({
  REGION,
  ENV: env('ENV', 'dev'),

  BUCKET_NAME: env('BUCKET_NAME', ''),
  USERS_TABLE: env('USERS_TABLE', ''),
  STALLS_TABLE: env('STALLS_TABLE', ''),
  OPENINGLOGS_TABLE: env('OPENINGLOGS_TABLE', ''),
  PRODUCTS_TABLE: env('PRODUCTS_TABLE', ''),

  BEDROCK_MODEL_ID: env('BEDROCK_MODEL_ID', ''),
  LOCATION_PLACE_INDEX_NAME: env('LOCATION_PLACE_INDEX_NAME', '')
});