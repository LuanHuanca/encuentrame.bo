'use strict';

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
const { env } = require('../../shared/config/env');

const documentClient = DynamoDBDocumentClient.from(
  new DynamoDBClient({ region: env.REGION }),
  {
    marshallOptions: {
      removeUndefinedValues: true,
    },
  }
);

module.exports = {
  documentClient,
};