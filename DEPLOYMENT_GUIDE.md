# Deployment Guide for Disability Rights Texas Chat Application

This guide provides step-by-step instructions for deploying the Disability Rights Texas Chat Application to a client's AWS account.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS Account Setup](#aws-account-setup)
3. [Amazon Q Business Setup](#amazon-q-business-setup)
4. [Backend Deployment](#backend-deployment)
5. [Frontend Deployment](#frontend-deployment)
6. [Configuration Values to Replace](#configuration-values-to-replace)
7. [Running the Application](#running-the-application)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

Before starting the deployment process, ensure you have the following:
- AWS account with administrative access
- Node.js (v14 or later) and npm (v6 or later) installed
- Git installed on your local machine
- Basic understanding of AWS services

## AWS Account Setup

1. **Create IAM User for Deployment**
   - Navigate to IAM service in AWS Console
   - Create a new user with programmatic access
   - Attach the following permissions:
     - AmazonQBusinessFullAccess
     - CloudFormationFullAccess
     - AmplifyFullAccess
     - LambdaFullAccess
     - APIGatewayFullAccess
   - Save the Access Key ID and Secret Access Key

2. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter the Access Key ID and Secret Access Key
   # Set your preferred region (e.g., us-west-2)
   # Set output format to json
   ```

## Amazon Q Business Setup

1. **Enable Amazon Q Business**
   - Sign in to AWS Console
   - Navigate to Amazon Q Business service
   - Click "Get Started"
   - Create a new application:
     - Name: "[CLIENT_NAME]-disability-rights-chat"
     - Description: "Chat application for [CLIENT_NAME] Disability Rights"

2. **Configure Data Source**
   - Choose "Web Crawler" or appropriate data source
   - Add website URLs to crawl (client's disability rights information)
   - Set crawl frequency based on how often content is updated

3. **Note the Application ID**
   - This will be needed for the backend deployment
   - The format looks like: "5a26abb5-b040-402c-9e31-83f24b7995e4"

## Backend Deployment

1. **Create CloudFormation Template**
   - Create a file named `template.json` with the following content:

   ```json
   {
     "AWSTemplateFormatVersion": "2010-09-09",
     "Description": "Disability Rights Chat Application Backend",
     "Parameters": {
       "ApplicationId": {
         "Type": "String",
         "Description": "Amazon Q Business Application ID"
       },
       "Environment": {
         "Type": "String",
         "Default": "prod",
         "Description": "Deployment environment"
       }
     },
     "Resources": {
       "ChatFunction": {
         "Type": "AWS::Lambda::Function",
         "Properties": {
           "FunctionName": {"Fn::Sub": "${AWS::StackName}-chat-function"},
           "Runtime": "nodejs16.x",
           "Handler": "index.handler",
           "Role": {"Fn::GetAtt": ["LambdaExecutionRole", "Arn"]},
           "Code": {
             "ZipFile": {
               "Fn::Join": ["\n", [
                 "const AWS = require('aws-sdk');",
                 "exports.handler = async (event) => {",
                 "  const qbusiness = new AWS.QBusiness();",
                 "  const body = JSON.parse(event.body);",
                 "  try {",
                 "    const params = {",
                 "      applicationId: process.env.APPLICATION_ID,",
                 "      text: body.message,",
                 "      conversationId: body.conversationId",
                 "    };",
                 "    if (body.parentMessageId) {",
                 "      params.parentMessageId = body.parentMessageId;",
                 "    }",
                 "    const result = await qbusiness.chatSync(params).promise();",
                 "    return {",
                 "      statusCode: 200,",
                 "      headers: {",
                 "        'Access-Control-Allow-Origin': '*',",
                 "        'Access-Control-Allow-Headers': 'Content-Type',",
                 "        'Access-Control-Allow-Methods': 'OPTIONS,POST'",
                 "      },",
                 "      body: JSON.stringify({",
                 "        systemMessage: result.systemMessage,",
                 "        systemMessageId: result.systemMessageId,",
                 "        conversationId: result.conversationId,",
                 "        userMessageId: result.userMessageId,",
                 "        sourceAttributions: result.sourceAttributions || []",
                 "      })",
                 "    };",
                 "  } catch (error) {",
                 "    console.error('Error:', error);",
                 "    return {",
                 "      statusCode: 500,",
                 "      headers: {",
                 "        'Access-Control-Allow-Origin': '*',",
                 "        'Access-Control-Allow-Headers': 'Content-Type',",
                 "        'Access-Control-Allow-Methods': 'OPTIONS,POST'",
                 "      },",
                 "      body: JSON.stringify({ error: error.message })",
                 "    };",
                 "  }",
                 "};"
               ]]
             }
           },
           "Environment": {
             "Variables": {
               "APPLICATION_ID": {"Ref": "ApplicationId"}
             }
           },
           "Timeout": 30
         }
       },
       "FeedbackFunction": {
         "Type": "AWS::Lambda::Function",
         "Properties": {
           "FunctionName": {"Fn::Sub": "${AWS::StackName}-feedback-function"},
           "Runtime": "nodejs16.x",
           "Handler": "index.handler",
           "Role": {"Fn::GetAtt": ["LambdaExecutionRole", "Arn"]},
           "Code": {
             "ZipFile": {
               "Fn::Join": ["\n", [
                 "const AWS = require('aws-sdk');",
                 "exports.handler = async (event) => {",
                 "  const qbusiness = new AWS.QBusiness();",
                 "  const pathParams = event.pathParameters;",
                 "  const body = JSON.parse(event.body);",
                 "  try {",
                 "    const params = {",
                 "      applicationId: pathParams.applicationId,",
                 "      conversationId: pathParams.conversationId,",
                 "      messageId: pathParams.messageId,",
                 "      messageUsefulness: body.messageUsefulness,",
                 "      messageCopiedAt: body.messageCopiedAt",
                 "    };",
                 "    await qbusiness.putFeedback(params).promise();",
                 "    return {",
                 "      statusCode: 200,",
                 "      headers: {",
                 "        'Access-Control-Allow-Origin': '*',",
                 "        'Access-Control-Allow-Headers': 'Content-Type',",
                 "        'Access-Control-Allow-Methods': 'OPTIONS,POST'",
                 "      },",
                 "      body: JSON.stringify({ success: true })",
                 "    };",
                 "  } catch (error) {",
                 "    console.error('Error:', error);",
                 "    return {",
                 "      statusCode: 500,",
                 "      headers: {",
                 "        'Access-Control-Allow-Origin': '*',",
                 "        'Access-Control-Allow-Headers': 'Content-Type',",
                 "        'Access-Control-Allow-Methods': 'OPTIONS,POST'",
                 "      },",
                 "      body: JSON.stringify({ error: error.message })",
                 "    };",
                 "  }",
                 "};"
               ]]
             }
           },
           "Timeout": 30
         }
       },
       "LambdaExecutionRole": {
         "Type": "AWS::IAM::Role",
         "Properties": {
           "AssumeRolePolicyDocument": {
             "Version": "2012-10-17",
             "Statement": [{
               "Effect": "Allow",
               "Principal": {"Service": ["lambda.amazonaws.com"]},
               "Action": ["sts:AssumeRole"]
             }]
           },
           "ManagedPolicyArns": [
             "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
             "arn:aws:iam::aws:policy/AmazonQBusinessFullAccess"
           ]
         }
       },
       "ApiGateway": {
         "Type": "AWS::ApiGateway::RestApi",
         "Properties": {
           "Name": {"Fn::Sub": "${AWS::StackName}-api"},
           "Description": "API for Disability Rights Chat Application"
         }
       },
       "ChatResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Fn::GetAtt": ["ApiGateway", "RootResourceId"]},
           "PathPart": "chat"
         }
       },
       "ChatMethod": {
         "Type": "AWS::ApiGateway::Method",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ResourceId": {"Ref": "ChatResource"},
           "HttpMethod": "POST",
           "AuthorizationType": "NONE",
           "Integration": {
             "Type": "AWS_PROXY",
             "IntegrationHttpMethod": "POST",
             "Uri": {"Fn::Sub": "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ChatFunction.Arn}/invocations"}
           }
         }
       },
       "ChatOptionsMethod": {
         "Type": "AWS::ApiGateway::Method",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ResourceId": {"Ref": "ChatResource"},
           "HttpMethod": "OPTIONS",
           "AuthorizationType": "NONE",
           "Integration": {
             "Type": "MOCK",
             "IntegrationResponses": [{
               "StatusCode": 200,
               "ResponseParameters": {
                 "method.response.header.Access-Control-Allow-Headers": "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'",
                 "method.response.header.Access-Control-Allow-Methods": "'OPTIONS,POST'",
                 "method.response.header.Access-Control-Allow-Origin": "'*'"
               }
             }],
             "RequestTemplates": {
               "application/json": "{\"statusCode\": 200}"
             }
           },
           "MethodResponses": [{
             "StatusCode": 200,
             "ResponseParameters": {
               "method.response.header.Access-Control-Allow-Headers": true,
               "method.response.header.Access-Control-Allow-Methods": true,
               "method.response.header.Access-Control-Allow-Origin": true
             }
           }]
         }
       },
       "ApplicationsResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Fn::GetAtt": ["ApiGateway", "RootResourceId"]},
           "PathPart": "applications"
         }
       },
       "ApplicationIdResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "ApplicationsResource"},
           "PathPart": "{applicationId}"
         }
       },
       "ConversationsResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "ApplicationIdResource"},
           "PathPart": "conversations"
         }
       },
       "ConversationIdResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "ConversationsResource"},
           "PathPart": "{conversationId}"
         }
       },
       "MessagesResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "ConversationIdResource"},
           "PathPart": "messages"
         }
       },
       "MessageIdResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "MessagesResource"},
           "PathPart": "{messageId}"
         }
       },
       "FeedbackResource": {
         "Type": "AWS::ApiGateway::Resource",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ParentId": {"Ref": "MessageIdResource"},
           "PathPart": "feedback"
         }
       },
       "FeedbackMethod": {
         "Type": "AWS::ApiGateway::Method",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ResourceId": {"Ref": "FeedbackResource"},
           "HttpMethod": "POST",
           "AuthorizationType": "NONE",
           "Integration": {
             "Type": "AWS_PROXY",
             "IntegrationHttpMethod": "POST",
             "Uri": {"Fn::Sub": "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${FeedbackFunction.Arn}/invocations"}
           }
         }
       },
       "FeedbackOptionsMethod": {
         "Type": "AWS::ApiGateway::Method",
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "ResourceId": {"Ref": "FeedbackResource"},
           "HttpMethod": "OPTIONS",
           "AuthorizationType": "NONE",
           "Integration": {
             "Type": "MOCK",
             "IntegrationResponses": [{
               "StatusCode": 200,
               "ResponseParameters": {
                 "method.response.header.Access-Control-Allow-Headers": "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'",
                 "method.response.header.Access-Control-Allow-Methods": "'OPTIONS,POST'",
                 "method.response.header.Access-Control-Allow-Origin": "'*'"
               }
             }],
             "RequestTemplates": {
               "application/json": "{\"statusCode\": 200}"
             }
           },
           "MethodResponses": [{
             "StatusCode": 200,
             "ResponseParameters": {
               "method.response.header.Access-Control-Allow-Headers": true,
               "method.response.header.Access-Control-Allow-Methods": true,
               "method.response.header.Access-Control-Allow-Origin": true
             }
           }]
         }
       },
       "ApiDeployment": {
         "Type": "AWS::ApiGateway::Deployment",
         "DependsOn": ["ChatMethod", "ChatOptionsMethod", "FeedbackMethod", "FeedbackOptionsMethod"],
         "Properties": {
           "RestApiId": {"Ref": "ApiGateway"},
           "StageName": {"Ref": "Environment"}
         }
       },
       "ChatFunctionPermission": {
         "Type": "AWS::Lambda::Permission",
         "Properties": {
           "Action": "lambda:InvokeFunction",
           "FunctionName": {"Ref": "ChatFunction"},
           "Principal": "apigateway.amazonaws.com",
           "SourceArn": {"Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*"}
         }
       },
       "FeedbackFunctionPermission": {
         "Type": "AWS::Lambda::Permission",
         "Properties": {
           "Action": "lambda:InvokeFunction",
           "FunctionName": {"Ref": "FeedbackFunction"},
           "Principal": "apigateway.amazonaws.com",
           "SourceArn": {"Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*"}
         }
       }
     },
     "Outputs": {
       "APIEndpoint": {
         "Description": "API Gateway endpoint URL",
         "Value": {"Fn::Sub": "https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/${Environment}"}
       },
       "LambdaFunctionArn": {
         "Description": "Lambda Function ARN",
         "Value": {"Fn::GetAtt": ["ChatFunction", "Arn"]}
       },
       "Region": {
         "Description": "AWS Region",
         "Value": {"Ref": "AWS::Region"}
       }
     }
   }
   ```

2. **Deploy CloudFormation Stack**
   ```bash
   aws cloudformation create-stack \
     --stack-name [CLIENT_NAME]-disability-rights-backend \
     --template-body file://template.json \
     --parameters ParameterKey=ApplicationId,ParameterValue=[YOUR_APPLICATION_ID] \
                  ParameterKey=Environment,ParameterValue=prod \
     --capabilities CAPABILITY_IAM
   ```

3. **Get Deployment Outputs**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name [CLIENT_NAME]-disability-rights-backend \
     --query "Stacks[0].Outputs"
   ```
   
   Note down the following values:
   - APIEndpoint
   - LambdaFunctionArn
   - Region

## Frontend Deployment

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-organization/disability-rights-chat.git
   cd disability-rights-chat
   ```

2. **Create Environment File**
   Create a `.env` file with the following content:
   ```
   REACT_APP_BASE_API_ENDPOINT=[APIEndpoint from CloudFormation]
   REACT_APP_API_ENDPOINT=[APIEndpoint from CloudFormation]/chat
   REACT_APP_FEEDBACK_ENDPOINT=[APIEndpoint from CloudFormation]/applications/{applicationId}/conversations/{conversationId}/messages/{messageId}/feedback
   REACT_APP_AWS_REGION=[Region from CloudFormation]
   REACT_APP_LAMBDA_FUNCTION=[LambdaFunctionArn from CloudFormation]
   REACT_APP_TRANSLATION_API_KEY=[Your Google Translation API Key]
   ```

3. **Install Dependencies and Build**
   ```bash
   npm install
   npm run build
   ```

4. **Deploy to AWS Amplify**
   ```bash
   # Install Amplify CLI if not already installed
   npm install -g @aws-amplify/cli
   
   # Initialize Amplify
   amplify init
   
   # Add hosting
   amplify add hosting
   
   # Publish
   amplify publish
   ```

## Configuration Values to Replace

When deploying to a client's account, you need to replace the following values:

1. **API Endpoints**
   - In `src/config.js`, replace:
     ```javascript
     baseEndpoint: process.env.REACT_APP_BASE_API_ENDPOINT || 'https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod',
     endpoint: process.env.REACT_APP_API_ENDPOINT || 'https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/chat',
     feedbackEndpoint: process.env.REACT_APP_FEEDBACK_ENDPOINT || 'https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/applications/{applicationId}/conversations/{conversationId}/messages/{messageId}/feedback',
     ```
   - With the new endpoints from your CloudFormation stack

2. **AWS Region**
   - In `src/config.js`, replace:
     ```javascript
     region: process.env.REACT_APP_AWS_REGION || 'us-west-2',
     ```
   - With the client's preferred AWS region

3. **Lambda Function ARN**
   - In `src/config.js`, replace:
     ```javascript
     lambdaFunction: process.env.REACT_APP_LAMBDA_FUNCTION || 'arn:aws:lambda:us-west-2:216989103356:function:amazonQBusinessFunctionNew3'
     ```
   - With the new Lambda function ARN from your CloudFormation stack

4. **Application ID**
   - In `src/services/amazonQService.js`, replace:
     ```javascript
     const applicationId = '5a26abb5-b040-402c-9e31-83f24b7995e4';
     ```
   - With the client's Amazon Q Business Application ID

5. **Translation API Key**
   - In `src/config.js`, replace:
     ```javascript
     apiKey: process.env.REACT_APP_TRANSLATION_API_KEY || '',
     ```
   - With the client's Google Translation API key (if translation is needed)

## Running the Application

### Local Development

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Start Development Server**
   ```bash
   npm start
   ```

3. **Access the Application**
   Open a browser and navigate to `http://localhost:3000`

### Production Deployment

1. **Access the Deployed Application**
   - If deployed with AWS Amplify, use the provided domain
   - If deployed with other methods, use the appropriate URL

2. **Verify Functionality**
   - Test chat functionality
   - Verify language switching (if enabled)
   - Test feedback submission

## Troubleshooting

### Common Issues

1. **API Connection Errors**
   - Verify environment variables are correctly set
   - Check API Gateway CORS settings
   - Ensure Lambda function has proper permissions

2. **Amazon Q Business Issues**
   - Verify application ID is correct
   - Check data source status in Amazon Q Business console
   - Review conversation settings

3. **Translation Issues**
   - Verify Google Translation API key is valid
   - Check translation service configuration
   - Ensure translation is enabled in config

### Logs and Monitoring

1. **CloudWatch Logs**
   ```bash
   aws logs get-log-events \
     --log-group-name /aws/lambda/[CLIENT_NAME]-disability-rights-backend-chat-function \
     --log-stream-name [LOG_STREAM_NAME]
   ```

2. **API Gateway Logs**
   - Enable CloudWatch logging for API Gateway
   - Monitor request/response patterns

3. **Frontend Logs**
   - Check browser console for JavaScript errors
   - Review network requests for API call issues