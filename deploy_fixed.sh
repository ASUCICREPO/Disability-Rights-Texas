#!/usr/bin/env bash
# Disable strict error handling to prevent script from exiting on expected errors
set +e

# Get project parameters
read -rp "Enter project name [default: disability-rights-texas]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-disability-rights-texas}

read -rp "Enter CloudFormation stack name [default: ${PROJECT_NAME}-api-stack]: " STACK_NAME
STACK_NAME=${STACK_NAME:-${PROJECT_NAME}-api-stack}

read -rp "Enter Amplify app name [default: DisabilityRightsTexas]: " AMPLIFY_APP_NAME
AMPLIFY_APP_NAME=${AMPLIFY_APP_NAME:-DisabilityRightsTexas}

read -rp "Enter Amplify branch name [default: main]: " AMPLIFY_BRANCH_NAME
AMPLIFY_BRANCH_NAME=${AMPLIFY_BRANCH_NAME:-main}

# Get AWS region
read -rp "Enter AWS region [default: us-west-2]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-west-2}

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
echo "Detected AWS Account ID: $AWS_ACCOUNT_ID"

# Get action
read -rp "Enter action [deploy/destroy]: " ACTION
ACTION=$(printf '%s' "$ACTION" | tr '[:upper:]' '[:lower:]')

# Create IAM role for CodeBuild
ROLE_NAME="${PROJECT_NAME}-codebuild-service-role"
POLICY_NAME="${PROJECT_NAME}-deployment-policy"
echo "Checking for IAM role: $ROLE_NAME"

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "✓ IAM role exists: $ROLE_NAME"
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
else
  echo "✱ Creating IAM role: $ROLE_NAME"
  TRUST_DOC='{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"codebuild.amazonaws.com"},
      "Action":"sts:AssumeRole"
    }]
  }'
  
  # Try to create the role
  CREATE_RESULT=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_DOC" 2>&1)
  
  # Check if role was created or already exists
  if echo "$CREATE_RESULT" | grep -q "EntityAlreadyExists"; then
    echo "✓ IAM role already exists: $ROLE_NAME"
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
  elif echo "$CREATE_RESULT" | grep -q "arn:aws:iam"; then
    echo "✓ Created IAM role: $ROLE_NAME"
    ROLE_ARN=$(echo "$CREATE_RESULT" | grep -o 'arn:aws:iam::[0-9]*:role/[a-zA-Z0-9_-]*')
  else
    echo "✗ Failed to create IAM role: $ROLE_NAME"
    echo "Error: $CREATE_RESULT"
    exit 1
  fi
fi

# Attach policy to role
POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "apigateway:*",
        "lambda:*",
        "iam:*",
        "amplify:*",
        "s3:*",
        "codebuild:*",
        "logs:*",
        "codeconnections:*",
        "codestar-connections:*",
        "qbusiness:*"
      ],
      "Resource": "*"
    }
  ]
}'

echo "Attaching policy to IAM role..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "$POLICY_DOC"

echo "✓ Policy attached to IAM role"
echo "Role ARN: $ROLE_ARN"

# Continue with the rest of the script
echo "=== PHASE 3: Q Business Application Setup ==="

# Check for existing Q Business application
EXISTING_APP_ID=$(aws qbusiness list-applications --region "$AWS_REGION" --query 'applications[?displayName==`DisabilityRightsTexas`].applicationId' --output text)
if [ -n "$EXISTING_APP_ID" ] && [ "$EXISTING_APP_ID" != "None" ]; then
  echo "✓ Found existing Q Business Application: $EXISTING_APP_ID"
  APPLICATION_ID="$EXISTING_APP_ID"
  
  # Get existing index ID
  EXISTING_INDEX_ID=$(aws qbusiness list-indices --application-id "$APPLICATION_ID" --region "$AWS_REGION" --query 'indices[?displayName==`DisabilityRightsIndex`].indexId' --output text)
  if [ -n "$EXISTING_INDEX_ID" ] && [ "$EXISTING_INDEX_ID" != "None" ]; then
    echo "✓ Found existing Index: $EXISTING_INDEX_ID"
    INDEX_ID="$EXISTING_INDEX_ID"
  fi
else
  echo "Creating Q Business application..."
  APP_RESPONSE=$(aws qbusiness create-application \
    --display-name "DisabilityRightsTexas" \
    --identity-type "ANONYMOUS" \
    --region "$AWS_REGION" \
    --output json 2>&1)
  
  APPLICATION_ID=$(echo "$APP_RESPONSE" | jq -r '.applicationId')
  echo "✓ Created Q Business Application: $APPLICATION_ID"
  
  echo "Waiting for application to be active..."
  while true; do
    STATUS=$(aws qbusiness get-application --application-id "$APPLICATION_ID" --region "$AWS_REGION" --query 'status' --output text)
    if [ "$STATUS" = "ACTIVE" ]; then
      echo "Application is ACTIVE"
      break
    fi
    echo "Status: $STATUS, waiting..."
    sleep 10
  done
fi

# Create index if needed
if [ -z "${INDEX_ID:-}" ]; then
  echo "Creating Q Business index..."
  INDEX_RESPONSE=$(aws qbusiness create-index \
    --application-id "$APPLICATION_ID" \
    --display-name "DisabilityRightsIndex" \
    --type "STARTER" \
    --region "$AWS_REGION" \
    --output json)
  
  INDEX_ID=$(echo "$INDEX_RESPONSE" | jq -r '.indexId')
  echo "✓ Created Index: $INDEX_ID"
  
  echo "Waiting for index to be active..."
  while true; do
    STATUS=$(aws qbusiness get-index --application-id "$APPLICATION_ID" --index-id "$INDEX_ID" --region "$AWS_REGION" --query 'status' --output text)
    if [ "$STATUS" = "ACTIVE" ]; then
      echo "Index is ACTIVE"
      break
    fi
    echo "Index status: $STATUS, waiting..."
    sleep 15
  done
fi

echo "=== PHASE 4: Web Experience Setup ==="

# Check for existing web experience
EXISTING_WEB_EXPERIENCE_ID=$(aws qbusiness list-web-experiences --application-id "$APPLICATION_ID" --region "$AWS_REGION" --query 'webExperiences[?displayName==`DisabilityRightsWeb`].webExperienceId' --output text)
if [ -n "$EXISTING_WEB_EXPERIENCE_ID" ] && [ "$EXISTING_WEB_EXPERIENCE_ID" != "None" ]; then
  echo "✓ Found existing Web Experience: $EXISTING_WEB_EXPERIENCE_ID"
  WEB_EXPERIENCE_ID="$EXISTING_WEB_EXPERIENCE_ID"
else
  echo "Creating Web Experience..."
  WEB_EXPERIENCE_RESPONSE=$(aws qbusiness create-web-experience \
    --application-id "$APPLICATION_ID" \
    --display-name "DisabilityRightsWeb" \
    --region "$AWS_REGION" \
    --output json 2>&1)
  
  WEB_EXPERIENCE_ID=$(echo "$WEB_EXPERIENCE_RESPONSE" | jq -r '.webExperienceId')
  echo "✓ Created Web Experience: $WEB_EXPERIENCE_ID"
fi

# Wait for web experience to be active
if [ -n "$WEB_EXPERIENCE_ID" ]; then
  echo "Waiting for web experience to be active..."
  while true; do
    WEB_STATUS=$(aws qbusiness get-web-experience --application-id "$APPLICATION_ID" --web-experience-id "$WEB_EXPERIENCE_ID" --region "$AWS_REGION" --query 'status' --output text)
    if [ "$WEB_STATUS" = "ACTIVE" ]; then
      echo "Web experience is ACTIVE"
      break
    fi
    echo "Web experience status: $WEB_STATUS, waiting..."
    sleep 10
  done
  
  # Output the web experience URL
  WEB_URL=$(aws qbusiness get-web-experience --application-id "$APPLICATION_ID" --web-experience-id "$WEB_EXPERIENCE_ID" --region "$AWS_REGION" --query 'defaultDomain' --output text)
  echo "Web Experience URL: $WEB_URL"
fi

echo "=== PHASE 5: S3 Data Source Setup ==="

# Create S3 bucket
S3_BUCKET_NAME="${PROJECT_NAME}-docs-bucket"
echo "Checking for S3 bucket: $S3_BUCKET_NAME"
if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
  echo "✓ S3 bucket exists: $S3_BUCKET_NAME"
else
  echo "✱ Creating S3 bucket: $S3_BUCKET_NAME"
  aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
  echo "✓ S3 bucket created: $S3_BUCKET_NAME"
fi

echo "Uploading files from /docs to S3 bucket: $S3_BUCKET_NAME"
aws s3 sync "$(dirname "$0")/docs" "s3://$S3_BUCKET_NAME/" --region "$AWS_REGION"
echo "✓ Files uploaded to S3 bucket: $S3_BUCKET_NAME"

# Check for existing S3 data source
S3_DATA_SOURCE_NAME="DisabilityRightsS3DataSource"
EXISTING_DATA_SOURCE_ID=$(aws qbusiness list-data-sources --application-id "$APPLICATION_ID" --index-id "$INDEX_ID" --region "$AWS_REGION" --query 'dataSources[?displayName==`'$S3_DATA_SOURCE_NAME'`].dataSourceId' --output text)

if [ -n "$EXISTING_DATA_SOURCE_ID" ] && [ "$EXISTING_DATA_SOURCE_ID" != "None" ]; then
  echo "✓ Found existing S3 data source: $EXISTING_DATA_SOURCE_ID"
  S3_DATA_SOURCE_ID="$EXISTING_DATA_SOURCE_ID"
else
  echo "Adding S3 bucket as a data source to Q Business application..."
  S3_DATA_SOURCE_CONFIG='{
    "type": "S3",
    "syncMode": "FULL_SYNC",
    "connectionConfiguration": {
      "bucketName": "'$S3_BUCKET_NAME'",
      "region": "'$AWS_REGION'"
    },
    "repositoryConfigurations": {
      "s3": {
        "fieldMappings": [
          {
            "indexFieldName": "FileName",
            "indexFieldType": "STRING",
            "dataSourceFieldName": "key"
          },
          {
            "indexFieldName": "FileContent",
            "indexFieldType": "STRING",
            "dataSourceFieldName": "content"
          }
        ]
      }
    },
    "version": "1.0.0"
  }'

  S3_DATA_SOURCE_RESPONSE=$(aws qbusiness create-data-source \
    --application-id "$APPLICATION_ID" \
    --index-id "$INDEX_ID" \
    --display-name "$S3_DATA_SOURCE_NAME" \
    --configuration "$S3_DATA_SOURCE_CONFIG" \
    --role-arn "$ROLE_ARN" \
    --region "$AWS_REGION" \
    --output json 2>&1)
  
  S3_DATA_SOURCE_ID=$(echo "$S3_DATA_SOURCE_RESPONSE" | jq -r '.dataSourceId')
  echo "✓ S3 data source added with ID: $S3_DATA_SOURCE_ID"
fi

echo "📋 Q Business Setup Updated:"
echo "   Application ID: $APPLICATION_ID"
echo "   Index ID: $INDEX_ID"
echo "   S3 Data Source ID: $S3_DATA_SOURCE_ID"

echo "=== PHASE 6: CodeBuild Project Setup ==="

# Create CodeBuild project
CODEBUILD_PROJECT_NAME="${PROJECT_NAME}-deploy"
echo "Creating CodeBuild project: $CODEBUILD_PROJECT_NAME"
echo "Using Q Business Application ID: $APPLICATION_ID"

ENV_VARS='[
  {"name": "STACK_NAME", "value": "'$STACK_NAME'", "type": "PLAINTEXT"},
  {"name": "AWS_REGION", "value": "'$AWS_REGION'", "type": "PLAINTEXT"},
  {"name": "ACTION", "value": "'$ACTION'", "type": "PLAINTEXT"},
  {"name": "AMPLIFY_APP_NAME", "value": "'$AMPLIFY_APP_NAME'", "type": "PLAINTEXT"},
  {"name": "AMPLIFY_BRANCH_NAME", "value": "'$AMPLIFY_BRANCH_NAME'", "type": "PLAINTEXT"},
  {"name": "APPLICATION_ID", "value": "'$APPLICATION_ID'", "type": "PLAINTEXT"}
]'

ENVIRONMENT='{
  "type": "LINUX_CONTAINER",
  "image": "aws/codebuild/standard:7.0",
  "computeType": "BUILD_GENERAL1_MEDIUM",
  "environmentVariables": '$ENV_VARS'
}'

ARTIFACTS='{"type":"NO_ARTIFACTS"}'

# Get GitHub repository URL
if [ -z "${GITHUB_URL:-}" ]; then
  # Try to get the GitHub URL from git config
  GITHUB_URL=$(git config --get remote.origin.url 2>/dev/null || echo "https://github.com/aws-samples/disability-rights-texas")
  echo "Using GitHub URL: $GITHUB_URL"
fi

# Configure source for public GitHub repository
SOURCE='{
  "type": "GITHUB",
  "location": "'$GITHUB_URL'",
  "buildspec": "buildspec.yml",
  "gitCloneDepth": 1
}'

# Delete existing project if it exists
if aws codebuild batch-get-projects --names "$CODEBUILD_PROJECT_NAME" --query 'projects[0].name' --output text 2>/dev/null | grep -q "$CODEBUILD_PROJECT_NAME"; then
  echo "Deleting existing CodeBuild project..."
  aws codebuild delete-project --name "$CODEBUILD_PROJECT_NAME"
  sleep 5
fi

# Create new CodeBuild project
echo "Creating new CodeBuild project..."
aws codebuild create-project \
  --name "$CODEBUILD_PROJECT_NAME" \
  --source "$SOURCE" \
  --artifacts "$ARTIFACTS" \
  --environment "$ENVIRONMENT" \
  --service-role "$ROLE_ARN" \
  --output json \
  --no-cli-pager

echo "Starting deployment build..."
BUILD_ID=$(aws codebuild start-build \
  --project-name "$CODEBUILD_PROJECT_NAME" \
  --query 'build.id' \
  --output text)

echo "✓ Build started with ID: $BUILD_ID"
echo "You can monitor the build progress in the AWS Console:"
echo "https://console.aws.amazon.com/codesuite/codebuild/projects/$CODEBUILD_PROJECT_NAME/build/$BUILD_ID"