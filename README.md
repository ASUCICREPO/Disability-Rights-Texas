# Disability Rights Texas Chat Application

## Table of Contents
- [Disability Rights Texas Chat Application](#disability-rights-texas-chat-application)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [AWS Account Setup](#aws-account-setup)
    - [1. Create AWS Account](#1-create-aws-account)
    - [2. Set Up IAM User](#2-set-up-iam-user)
  - [Amazon Q Business Setup](#amazon-q-business-setup)
    - [1. Enable Amazon Q Business](#1-enable-amazon-q-business)
    - [2. Configure Application Settings](#2-configure-application-settings)
  - [Backend Deployment](#backend-deployment)
    - [1. Deploy CloudFormation Stack](#1-deploy-cloudformation-stack)
  - [Frontend Deployment](#frontend-deployment)
    - [1. Set Up AWS Amplify](#1-set-up-aws-amplify)
    - [2. Configure Environment Variables](#2-configure-environment-variables)
    - [3. Deploy Frontend](#3-deploy-frontend)
  - [Environment Configuration](#environment-configuration)
    - [1. Local Development Setup](#1-local-development-setup)
  - [Docker Deployment](#docker-deployment)
    - [1. Using Docker](#1-using-docker)
    - [2. Using Docker Compose](#2-using-docker-compose)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)

## Prerequisites

Before starting the deployment process, ensure you have the following:
- A modern web browser
- Basic understanding of AWS services
- Git installed on your local machine
- Node.js (v14 or later) installed
- npm (v6 or later) installed

## AWS Account Setup

### 1. Create AWS Account
1. Go to [AWS Sign Up Page](https://portal.aws.amazon.com/billing/signup)
2. Click "Create an AWS Account"
3. Follow the registration process:
   - Enter your email address
   - Choose a password
   - Provide contact information
   - Add payment information (credit card required)
   - Verify your identity

### 2. Set Up IAM User
1. Sign in to AWS Console
2. Navigate to IAM service
3. Create a new IAM user:
   - Click "Users" → "Add user"
   - Enter username (e.g., "admin-user")
   - Select "Access key - Programmatic access"
4. Attach necessary permissions:
   - AmazonQBusinessFullAccess
   - CloudFormationFullAccess
   - AmplifyFullAccess
   - LambdaFullAccess
   - APIGatewayFullAccess
5. Save the Access Key ID and Secret Access Key securely

## Amazon Q Business Setup

### 1. Enable Amazon Q Business
1. Sign in to AWS Console
2. Navigate to Amazon Q Business service
3. Click "Get Started"
4. Create a new application:
   - Name: "disability-rights-chat"
   - Description: "Chat application for Disability Rights Texas"
   - Select "Create new data source"
5. Configure data source:
   - Choose "Web Crawler"
   - Add website URLs to crawl
   - Set crawl frequency
6. Wait for initial data ingestion to complete

### 2. Configure Application Settings
1. In Amazon Q Business console:
   - Set up conversation settings
   - Configure response formatting
   - Set up content filtering
2. Note down the Application ID for later use

## Backend Deployment

### 1. Deploy CloudFormation Stack
1. Download the `template.json` file
2. Sign in to AWS Console
3. Navigate to CloudFormation service
4. Click "Create stack" → "With new resources"
5. Upload the template file
6. Configure stack parameters:
   ```
   StackName: disability-rights-backend
   ApplicationId: [Your Amazon Q Business Application ID]
   Environment: prod
   ```
7. Review and create stack
8. Wait for stack creation to complete
9. Note down the following outputs:
   - APIEndpoint
   - LambdaFunctionArn
   - Region

## Frontend Deployment

### 1. Set Up AWS Amplify
1. Sign in to AWS Console
2. Navigate to AWS Amplify service
3. Click "New app" → "Host web app"
4. Connect to your repository:
   - Choose GitHub
   - Authorize AWS Amplify
   - Select your repository
5. Configure build settings:
   ```yaml
   version: 1
   frontend:
     phases:
       build:
         commands:
           - npm install
           - npm run build
     artifacts:
       baseDirectory: build
       files:
         - '**/*'
     cache:
       paths:
         - node_modules/**/*
   ```

### 2. Configure Environment Variables
In Amplify Console:
1. Go to "Environment Variables"
2. Add the following variables:
   ```
   REACT_APP_BASE_API_ENDPOINT=[APIEndpoint from CloudFormation]
   REACT_APP_API_ENDPOINT=[APIEndpoint from CloudFormation]/chat
   REACT_APP_FEEDBACK_ENDPOINT=[APIEndpoint from CloudFormation]/applications/{applicationId}/conversations/{conversationId}/messages/{messageId}/feedback
   REACT_APP_AWS_REGION=[Region from CloudFormation]
   REACT_APP_LAMBDA_FUNCTION=[LambdaFunctionArn from CloudFormation]
   ```

### 3. Deploy Frontend
1. In Amplify Console:
   - Click "Save and deploy"
   - Wait for deployment to complete
2. Note down the generated domain name

## Environment Configuration

### 1. Local Development Setup
1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd [repository-name]
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create `.env` file by copying from the example:
   ```bash
   cp .env.example .env
   ```
4. Edit the `.env` file with your actual configuration values
5. Start development server:
   ```bash
   npm start
   ```

## Docker Deployment

### 1. Using Docker

You can build and run the application using Docker:

```bash
# Build the Docker image
docker build -t disability-rights-chat .

# Run the container
docker run -p 3000:3000 --env-file .env disability-rights-chat
```

### 2. Using Docker Compose

For a more streamlined setup, use Docker Compose:

```bash
# Start the application
docker-compose up

# Run in detached mode
docker-compose up -d

# Stop the application
docker-compose down
```

Make sure your `.env` file contains all the necessary environment variables as listed in the Environment Configuration section.

## Troubleshooting

### Common Issues

1. **API Connection Errors**
   - Verify environment variables
   - Check API Gateway endpoint
   - Ensure Lambda function is deployed

2. **Amazon Q Business Issues**
   - Verify application ID
   - Check data source status
   - Review conversation settings

3. **Deployment Failures**
   - Check CloudFormation stack events
   - Verify IAM permissions
   - Review Amplify build logs

4. **Docker Issues**
   - Ensure Docker is installed and running
   - Check if ports are already in use
   - Verify environment variables are properly passed to the container