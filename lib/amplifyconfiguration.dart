const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "apic45634fb": {
                    "endpointType": "REST",
                    "endpoint": "https://emt1twi7p5.execute-api.us-east-1.amazonaws.com/dev",
                    "region": "us-east-1",
                    "authorizationType": "AWS_IAM"
                }
            }
        }
    },
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "us-east-1:78186498-d5f7-481f-91a1-0d9832c3c9e0",
                            "Region": "us-east-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-east-1_Z69J9ykrs",
                        "AppClientId": "68vf546dc5jqn55m6ana54svcr",
                        "Region": "us-east-1"
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "USER_SRP_AUTH",
                        "mfaConfiguration": "OFF",
                        "mfaTypes": [
                            "SMS"
                        ],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "signupAttributes": [
                            "EMAIL"
                        ],
                        "socialProviders": [],
                        "usernameAttributes": [
                            "EMAIL"
                        ],
                        "verificationMechanisms": [
                            "EMAIL"
                        ]
                    }
                },
                "DynamoDBObjectMapper": {
                    "Default": {
                        "Region": "us-east-1"
                    }
                },
                "S3TransferUtility": {
                    "Default": {
                        "Bucket": "encuentrameboe3902bbf321844389a4773fb8a5ee198f3550-dev",
                        "Region": "us-east-1"
                    }
                }
            }
        }
    },
    "storage": {
        "plugins": {
            "awsDynamoDbStoragePlugin": {
                "partitionKeyName": "pk",
                "sortKeyName": "sk",
                "sortKeyType": "S",
                "region": "us-east-1",
                "arn": "arn:aws:dynamodb:us-east-1:941570845580:table/products-dev-dev",
                "streamArn": "arn:aws:dynamodb:us-east-1:941570845580:table/products-dev-dev/stream/2026-02-22T01:54:39.573",
                "partitionKeyType": "S",
                "name": "products-dev-dev"
            },
            "awsS3StoragePlugin": {
                "bucket": "encuentrameboe3902bbf321844389a4773fb8a5ee198f3550-dev",
                "region": "us-east-1",
                "defaultAccessLevel": "guest"
            }
        }
    }
}''';
