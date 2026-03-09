/* Amplify Params - DO NOT EDIT
	ENV
	REGION
	STORAGE_DYNAMO324F6F26_ARN
	STORAGE_DYNAMO324F6F26_NAME
	STORAGE_DYNAMO324F6F26_STREAMARN
	STORAGE_DYNAMO800BFC2B_ARN
	STORAGE_DYNAMO800BFC2B_NAME
	STORAGE_DYNAMO800BFC2B_STREAMARN
	STORAGE_DYNAMO81BC09DC_ARN
	STORAGE_DYNAMO81BC09DC_NAME
	STORAGE_DYNAMO81BC09DC_STREAMARN
	STORAGE_DYNAMOF7A7B9AA_ARN
	STORAGE_DYNAMOF7A7B9AA_NAME
	STORAGE_DYNAMOF7A7B9AA_STREAMARN
	STORAGE_S39E8AB6E7_BUCKETNAME
Amplify Params - DO NOT EDIT */'use strict';

const { route } = require('./router');
const { corsHeaders } = require('./util/http');

exports.handler = async (event) => {
  try {
    return await route(event);
  } catch (error) {
    console.log('UNHANDLED_ERROR', {
      name: error?.name,
      message: error?.message,
      stack: error?.stack,
      status: error?.$metadata?.httpStatusCode,
    });

    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({
        error: {
          code: 'INTERNAL',
          message: 'Error interno',
          details:
            process.env.ENV === 'dev'
              ? String(error?.message || 'Unknown error')
              : undefined,
        },
      }),
    };
  }
};