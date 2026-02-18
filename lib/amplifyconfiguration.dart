const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "apic45634fb": {
                    "endpointType": "REST",
                    "endpoint": "https://9ilni7uqm7.execute-api.us-east-1.amazonaws.com/dev",
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
                            "PoolId": "us-east-1:e9120653-4b98-4ec2-9292-540f9f341885",
                            "Region": "us-east-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-east-1_nmOspS3Fx",
                        "AppClientId": "47l8pj0gjan9g23k2chgj7kgce",
                        "Region": "us-east-1"
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "USER_SRP_AUTH",
                        "socialProviders": [],
                        "usernameAttributes": [
                            "EMAIL"
                        ],
                        "signupAttributes": [
                            "EMAIL"
                        ],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "mfaConfiguration": "OFF",
                        "mfaTypes": [
                            "SMS"
                        ],
                        "verificationMechanisms": [
                            "EMAIL"
                        ]
                    }
                },
                "S3TransferUtility": {
                    "Default": {
                        "Bucket": "encuentrameboe3902bbf321844389a4773fb8a5ee198f3550-dev",
                        "Region": "us-east-1"
                    }
                },
                "DynamoDBObjectMapper": {
                    "Default": {
                        "Region": "us-east-1"
                    }
                }
            }
        }
    },
    "storage": {
        "plugins": {
            "awsS3StoragePlugin": {
                "bucket": "encuentrameboe3902bbf321844389a4773fb8a5ee198f3550-dev",
                "region": "us-east-1",
                "defaultAccessLevel": "guest"
            },
            "awsDynamoDbStoragePlugin": {
                "partitionKeyName": "pk",
                "sortKeyName": "sk",
                "sortKeyType": "S",
                "region": "us-east-1",
                "arn": "arn:aws:dynamodb:us-east-1:941570845580:table/stalls-dev",
                "streamArn": "arn:aws:dynamodb:us-east-1:941570845580:table/stalls-dev/stream/2026-02-18T17:20:38.384",
                "partitionKeyType": "S",
                "name": "stalls-dev"
            }
        }
    }
}''';
