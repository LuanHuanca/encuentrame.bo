'use strict';

function env(name, fallback = undefined) {
  const value = process.env[name];
  return value == null || String(value).trim() === '' ? fallback : value;
}

const REGION = env('AWS_REGION', env('REGION', 'us-east-1'));

module.exports = Object.freeze({
  REGION,
  ENV: env('ENV', 'dev'),

  BUCKET_NAME: env('BUCKET_NAME', env('STORAGE_S39E8AB6E7_BUCKETNAME', '')),
  USERS_TABLE: env('USERS_TABLE', env('STORAGE_DYNAMO324F6F26_NAME', '')),
  STALLS_TABLE: env('STALLS_TABLE', env('STORAGE_DYNAMO800BFC2B_NAME', '')),
  OPENINGLOGS_TABLE: env(
    'OPENINGLOGS_TABLE',
    env('STORAGE_DYNAMO81BC09DC_NAME', '')
  ),
  PRODUCTS_TABLE: env(
    'PRODUCTS_TABLE',
    env('STORAGE_DYNAMOF7A7B9AA_NAME', '')
  ),

  LOCATION_PLACE_INDEX_NAME: env('LOCATION_PLACE_INDEX_NAME', ''),
  BEDROCK_MODEL_ID: env('BEDROCK_MODEL_ID', ''),
});