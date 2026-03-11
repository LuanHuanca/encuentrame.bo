'use strict';

function getEnv(name, fallback = undefined) {
  const value = process.env[name];
  if (value === undefined || value === null || String(value).trim() === '') {
    return fallback;
  }
  return value;
}

const env = Object.freeze({
  REGION: getEnv('AWS_REGION', getEnv('REGION', 'us-east-1')),
  ENV: getEnv('ENV', 'dev'),

  USERS_TABLE: getEnv('USERS_TABLE', getEnv('STORAGE_DYNAMO324F6F26_NAME', '')),
  STALLS_TABLE: getEnv('STALLS_TABLE', getEnv('STORAGE_DYNAMO800BFC2B_NAME', '')),
  OPENINGLOGS_TABLE: getEnv(
    'OPENINGLOGS_TABLE',
    getEnv('STORAGE_DYNAMO81BC09DC_NAME', '')
  ),
  PRODUCTS_TABLE: getEnv('PRODUCTS_TABLE', getEnv('STORAGE_DYNAMOF7A7B9AA_NAME', '')),
  BUCKET_NAME: getEnv('BUCKET_NAME', getEnv('STORAGE_S39E8AB6E7_BUCKETNAME', '')),

  LOCATION_PLACE_INDEX_NAME: getEnv('LOCATION_PLACE_INDEX_NAME', ''),
  BEDROCK_MODEL_ID: getEnv('BEDROCK_MODEL_ID', ''),
});

module.exports = {
  env,
};