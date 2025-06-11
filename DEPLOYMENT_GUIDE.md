# Deployment Guide for Disability Rights Texas Chat Application

This guide provides step-by-step instructions for deploying the Disability Rights Texas Chat Application to a client's AWS account.

## Table of Contents
- [Deployment Guide for Disability Rights Texas Chat Application](#deployment-guide-for-disability-rights-texas-chat-application)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [AWS Account Setup](#aws-account-setup)
  - [Amazon Q Business Setup](#amazon-q-business-setup)
  - [Backend Deployment](#backend-deployment)
  - [Frontend Deployment](#frontend-deployment)
  - [Configuration Values to Replace](#configuration-values-to-replace)
  - [Running the Application](#running-the-application)
    - [Local Development](#local-development)
    - [Production Deployment](#production-deployment)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Logs and Monitoring](#logs-and-monitoring)

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
   - Create a file named `template.json` and upload to CloudFormation.

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