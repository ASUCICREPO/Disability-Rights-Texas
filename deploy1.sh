#!/usr/bin/env bash
set -euo pipefail

# Disability Rights Texas - Automated Deployment Script
# This script sets up and triggers a CodeBuild project for deployment

# Get GitHub repository URL
if [ -z "${GITHUB_URL:-}" ]; then
  # Try to get the GitHub URL from git config
  GITHUB_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
  if [ -z "$GITHUB_URL" ]; then
    read -rp "Enter GitHub repository URL (e.g., https://github.com/OWNER/REPO): " GITHUB_URL
  else
    echo "Detected GitHub URL: $GITHUB_URL"
  fi
fi

# Clean up the GitHub URL
clean_url=${GITHUB_URL%.git}
clean_url=${clean_url%/}

# Get project parameters
if [ -z "${PROJECT_NAME:-}" ]; then
  read -rp "Enter project name [default: disability-rights-texas]: " PROJECT_NAME
  PROJECT_NAME=${PROJECT_NAME:-disability-rights-texas}
fi

if [ -z "${STACK_NAME:-}" ]; then
  read -rp "Enter CloudFormation stack name [default: ${PROJECT_NAME}-api-stack]: " STACK_NAME
  STACK_NAME=${STACK_NAME:-${PROJECT_NAME}-api-stack}
fi

if [ -z "${AMPLIFY_APP_NAME:-}" ]; then
  read -rp "Enter Amplify app name [default: DisabilityRightsTexas]: " AMPLIFY_APP_NAME
  AMPLIFY_APP_NAME=${AMPLIFY_APP_NAME:-DisabilityRightsTexas}
fi

if [ -z "${AMPLIFY_BRANCH_NAME:-}" ]; then
  read -rp "Enter Amplify branch name [default: main]: " AMPLIFY_BRANCH_NAME
  AMPLIFY_BRANCH_NAME=${AMPLIFY_BRANCH_NAME:-main}
fi

if [ -z "${AWS_REGION:-}" ]; then
  read -rp "Enter AWS region [default: us-west-2]: " AWS_REGION
  AWS_REGION=${AWS_REGION:-us-west-2}
fi

if [ -z "${AWS_ACCOUNT_ID:-}" ]; then
  # Try to get the AWS account ID automatically
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "")
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    read -rp "Enter AWS account ID: " AWS_ACCOUNT_ID
  else
    echo "Detected AWS Account ID: $AWS_ACCOUNT_ID"
  fi
fi

# Auto-create Q Business application
APPLICATION_ID="create"

if [ -z "${ACTION:-}" ]; then
  read -rp "Enter action [deploy/destroy]: " ACTION
  ACTION=$(printf '%s' "$ACTION" | tr '[:upper:]' '[:lower:]')
fi

if [[ "$ACTION" != "deploy" && "$ACTION" != "destroy" ]]; then
  echo "Invalid action: '$ACTION'. Choose 'deploy' or 'destroy'."
  exit 1
fi

# Create IAM role for CodeBuild
ROLE_NAME="${PROJECT_NAME}-codebuild-service-role"
POLICY_NAME="${PROJECT_NAME}-deployment-policy"
echo "Checking for IAM role: $ROLE_NAME"

# Create custom policy document with specific permissions
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFormationFull",
      "Effect": "Allow",
      "Action": [
        "cloudformation:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "APIGatewayCRUD",
      "Effect": "Allow",
      "Action": [
        "apigateway:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaFunctionAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMRoleCreationPass",
      "Effect": "Allow",
      "Action": [
        "iam:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AmplifyAppDeployment",
      "Effect": "Allow",
      "Action": [
        "amplify:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3ArtifactsAccess",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CodeBuildAccess",
      "Effect": "Allow",
      "Action": [
        "codebuild:*",
        "logs:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CodeConnectionsAccess",
      "Effect": "Allow",
      "Action": [
        "codeconnections:*",
        "codestar-connections:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "QBusinessAccess",
      "Effect": "Allow",
      "Action": [
        "qbusiness:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "✓ IAM role exists"
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
  
  # Update the policy with the specific permissions
  echo "Updating IAM policy..."
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC"
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

  ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_DOC" \
    --query 'Role.Arn' --output text)

  echo "Attaching custom policy..."
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC"

  echo "Waiting for IAM role to propagate..."
  sleep 10
fi

# Q Business Setup Automation
echo "=== Setting up Q Business Application ==="
if [ "$APPLICATION_ID" = "create" ]; then
  # Create Q Business application with anonymous access
  echo "Creating Q Business application..."
  APP_RESPONSE=$(aws qbusiness create-application \
    --display-name "DisabilityRightsTexas" \
    --identity-type "ANONYMOUS" \
    --region $AWS_REGION \
    --output json)
  
  APPLICATION_ID=$(echo $APP_RESPONSE | jq -r '.applicationId')
  echo "✓ Created Q Business Application: $APPLICATION_ID"
  
  # Wait for application to be active
  echo "Waiting for application to be active..."
  while true; do
    STATUS=$(aws qbusiness get-application --application-id $APPLICATION_ID --region $AWS_REGION --query 'status' --output text)
    if [ "$STATUS" = "ACTIVE" ]; then
      break
    fi
    echo "Status: $STATUS, waiting..."
    sleep 10
  done
  
  # Create index
  echo "Creating Q Business index..."
  INDEX_RESPONSE=$(aws qbusiness create-index \
    --application-id $APPLICATION_ID \
    --display-name "DisabilityRightsIndex" \
    --type "STARTER" \
    --region $AWS_REGION \
    --output json)
  
  INDEX_ID=$(echo $INDEX_RESPONSE | jq -r '.indexId')
  echo "✓ Created Index: $INDEX_ID"
  
  # Wait for index to be active
  echo "Waiting for index to be active..."
  while true; do
    STATUS=$(aws qbusiness get-index --application-id $APPLICATION_ID --index-id $INDEX_ID --region $AWS_REGION --query 'status' --output text)
    if [ "$STATUS" = "ACTIVE" ]; then
      break
    fi
    echo "Index status: $STATUS, waiting..."
    sleep 15
  done
  
  # Create IAM role for Q Business
  QBUSINESS_ROLE_NAME="${PROJECT_NAME}-qbusiness-role"
  echo "Creating IAM role for Q Business: $QBUSINESS_ROLE_NAME"
  
  QBUSINESS_TRUST_DOC='{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "qbusiness.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
  
  QBUSINESS_POLICY_DOC='{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        "Resource": "*"
      }
    ]
  }'
  
  # Create or update the role
  if aws iam get-role --role-name "$QBUSINESS_ROLE_NAME" >/dev/null 2>&1; then
    echo "✓ Q Business IAM role exists"
    QBUSINESS_ROLE_ARN=$(aws iam get-role --role-name "$QBUSINESS_ROLE_NAME" --query 'Role.Arn' --output text)
    
    # Update the trust relationship
    aws iam update-assume-role-policy \
      --role-name "$QBUSINESS_ROLE_NAME" \
      --policy-document "$QBUSINESS_TRUST_DOC"
      
    # Update the policy
    aws iam put-role-policy \
      --role-name "$QBUSINESS_ROLE_NAME" \
      --policy-name "${PROJECT_NAME}-qbusiness-policy" \
      --policy-document "$QBUSINESS_POLICY_DOC"
  else
    echo "✱ Creating Q Business IAM role: $QBUSINESS_ROLE_NAME"
    QBUSINESS_ROLE_ARN=$(aws iam create-role \
      --role-name "$QBUSINESS_ROLE_NAME" \
      --assume-role-policy-document "$QBUSINESS_TRUST_DOC" \
      --query 'Role.Arn' --output text)
    
    # Attach policy
    aws iam put-role-policy \
      --role-name "$QBUSINESS_ROLE_NAME" \
      --policy-name "${PROJECT_NAME}-qbusiness-policy" \
      --policy-document "$QBUSINESS_POLICY_DOC"
    
    echo "Waiting for IAM role to propagate..."
    sleep 10
  fi
  
  # Create Web Crawler data source
  echo "Creating Web Crawler data source..."
  WEB_DS_RESPONSE=$(aws qbusiness create-data-source \
    --application-id $APPLICATION_ID \
    --index-id $INDEX_ID \
    --display-name "WebCrawler-DisabilityRightsTX" \
    --configuration '{"type":"WEBCRAWLERV2","connectionConfiguration":{"repositoryEndpointMetadata":{"siteMapUrls":["https://disabilityrightstx.org/en/home/"]}},"repositoryConfigurations":{"webPage":{"fieldMappings":[{"indexFieldName":"web_crawler_url","indexFieldType":"STRING","dataSourceFieldName":"url"}]}},"additionalProperties":{"crawlDepth":3,"crawlSubDomains":true,"crawlAllDomains":false},"syncMode":"FULL_CRAWL"}' \
    --role-arn "$QBUSINESS_ROLE_ARN" \
    --region $AWS_REGION \
    --output json)
  
  WEB_DS_ID=$(echo $WEB_DS_RESPONSE | jq -r '.dataSourceId')
  echo "✓ Created Web Crawler Data Source: $WEB_DS_ID"
  
  echo "📋 Q Business Setup Complete:"
  echo "   Application ID: $APPLICATION_ID"
  echo "   Index ID: $INDEX_ID"
  echo "   Web Crawler Data Source ID: $WEB_DS_ID"
  echo ""
  echo "📝 Next Steps:"
  echo "   1. Sync web crawler data source in Q Business console"
  echo "   2. Configure web experience for anonymous access"
fi

# Create CodeBuild project
CODEBUILD_PROJECT_NAME="${PROJECT_NAME}-deploy"
echo "Creating CodeBuild project: $CODEBUILD_PROJECT_NAME"
echo "Using Q Business Application ID: $APPLICATION_ID"

ENV_VARS=$(cat <<EOF
[
  {"name": "STACK_NAME", "value": "$STACK_NAME", "type": "PLAINTEXT"},
  {"name": "AWS_REGION", "value": "$AWS_REGION", "type": "PLAINTEXT"},
  {"name": "ACTION", "value": "$ACTION", "type": "PLAINTEXT"},
  {"name": "AMPLIFY_APP_NAME", "value": "$AMPLIFY_APP_NAME", "type": "PLAINTEXT"},
  {"name": "AMPLIFY_BRANCH_NAME", "value": "$AMPLIFY_BRANCH_NAME", "type": "PLAINTEXT"},
  {"name": "APPLICATION_ID", "value": "$APPLICATION_ID", "type": "PLAINTEXT"}
]
EOF
)

ENVIRONMENT=$(cat <<EOF
{
  "type": "LINUX_CONTAINER",
  "image": "aws/codebuild/standard:7.0",
  "computeType": "BUILD_GENERAL1_MEDIUM",
  "environmentVariables": $ENV_VARS
}
EOF
)

ARTIFACTS='{"type":"NO_ARTIFACTS"}'

# Delete any existing CodeConnections that might interfere
echo "Checking for existing connections..."
aws codeconnections list-connections --provider-type GitHub --query 'Connections[?ConnectionStatus==`AVAILABLE`].ConnectionArn' --output text 2>/dev/null || true

# Configure source for public GitHub repository - no auth needed
SOURCE=$(cat <<EOF
{
  "type": "GITHUB",
  "location": "$GITHUB_URL",
  "buildspec": "buildspec.yml",
  "gitCloneDepth": 1
}
EOF
)

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

if [ $? -eq 0 ]; then
  echo "✓ CodeBuild project '$CODEBUILD_PROJECT_NAME' created."
else
  echo "✗ Failed to create CodeBuild project."
  exit 1
fi

echo "Starting deployment build..."
BUILD_ID=$(aws codebuild start-build \
  --project-name "$CODEBUILD_PROJECT_NAME" \
  --query 'build.id' \
  --output text)

if [ $? -eq 0 ]; then
  echo "✓ Build started with ID: $BUILD_ID"
  echo "You can monitor the build progress in the AWS Console:"
  echo "https://console.aws.amazon.com/codesuite/codebuild/projects/$CODEBUILD_PROJECT_NAME/build/$BUILD_ID"
else
  echo "✗ Failed to start build."
  exit 1
fi