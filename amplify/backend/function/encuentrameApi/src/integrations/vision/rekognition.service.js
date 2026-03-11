'use strict';

const {
  RekognitionClient,
  DetectLabelsCommand,
  DetectModerationLabelsCommand,
} = require('@aws-sdk/client-rekognition');

const { env } = require('../../shared/config/env');
const { candidateKeys } = require('../storage/s3-paths');

const client = new RekognitionClient({
  region: env.REGION,
});

function isResourceNotFound(error) {
  return (
    error?.name === 'ResourceNotFoundException' ||
    error?.$metadata?.httpStatusCode === 404
  );
}

async function detectLabelsFromS3Key(s3Key) {
  const tries = candidateKeys(s3Key);
  let lastError;

  for (const key of tries) {
    try {
      const out = await client.send(
        new DetectLabelsCommand({
          Image: {
            S3Object: {
              Bucket: env.BUCKET_NAME,
              Name: key,
            },
          },
          MaxLabels: 20,
          MinConfidence: 80,
        })
      );

      return {
        keyUsed: key,
        labels: (out.Labels || []).map((label) => ({
          name: label.Name,
          confidence: Math.round((label.Confidence || 0) * 10) / 10,
        })),
      };
    } catch (error) {
      lastError = error;
      if (isResourceNotFound(error)) continue;
      throw error;
    }
  }

  throw lastError;
}

async function detectModerationFromS3Key(s3Key) {
  const tries = candidateKeys(s3Key);
  let lastError;

  for (const key of tries) {
    try {
      const out = await client.send(
        new DetectModerationLabelsCommand({
          Image: {
            S3Object: {
              Bucket: env.BUCKET_NAME,
              Name: key,
            },
          },
          MinConfidence: 75,
        })
      );

      return {
        keyUsed: key,
        moderation: (out.ModerationLabels || []).map((label) => ({
          name: label.Name,
          confidence: Math.round((label.Confidence || 0) * 10) / 10,
        })),
      };
    } catch (error) {
      lastError = error;
      if (isResourceNotFound(error)) continue;
      throw error;
    }
  }

  throw lastError;
}

module.exports = {
  isResourceNotFound,
  detectLabelsFromS3Key,
  detectModerationFromS3Key,
};