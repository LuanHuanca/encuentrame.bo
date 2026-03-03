'use strict';

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
const { RekognitionClient } = require('@aws-sdk/client-rekognition');
const { BedrockRuntimeClient } = require('@aws-sdk/client-bedrock-runtime');
const { LocationClient } = require('@aws-sdk/client-location');

const config = require('../config');

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: config.REGION }), {
  marshallOptions: { removeUndefinedValues: true }
});

const rekognition = new RekognitionClient({ region: config.REGION });
const bedrock = new BedrockRuntimeClient({ region: config.REGION });
const location = new LocationClient({ region: config.REGION });

module.exports = { ddb, rekognition, bedrock, location };