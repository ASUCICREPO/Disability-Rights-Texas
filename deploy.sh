#!/usr/bin/env bash
set -euo pipefail

# Disability Rights Texas - Automated Deployment Script
# This script sets up and triggers a CodeBuild project for deployment

if [ -z "${APPLICATION_ID:-}" ]; then
  read -rp "Enter Amazon Q Business Application ID: " APPLICATION_ID
fi

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
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DescribeStacks",
        "cloudformation:CreateChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:GetTemplateSummary"
      ],
      "Resource": "*"
    },
    {
      "Sid": "APIGatewayCRUD",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:PATCH",
        "apigateway:DELETE"
      ],
      "Resource": [
        "arn:aws:apigateway:${AWS_REGION}::/restapis",
        "arn:aws:apigateway:${AWS_REGION}::/restapis/*"
      ]
    },
    {
      "Sid": "LambdaFunctionAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:GetFunction",
        "lambda:TagResource",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:PutFunctionConcurrency",
        "lambda:AddPermission"
      ],
      "Resource": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:*"
    },
    {
      "Sid": "LambdaLayerInsightsAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:GetLayerVersion"
      ],
      "Resource": "arn:aws:lambda:${AWS_REGION}:580247275435:layer:LambdaInsightsExtension:14"
    },
    {
      "Sid": "IAMRoleCreationPass",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:AttachRolePolicy",
        "iam:TagRole",
        "iam:PassRole",
        "iam:GetRole"
      ],
      "Resource": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${STACK_NAME}-*"
    },
    {
      "Sid": "AmplifyAppDeployment",
      "Effect": "Allow",
      "Action": [
        "amplify:CreateApp",
        "amplify:ListApps",
        "amplify:CreateBranch",
        "amplify:ListBranches",
        "amplify:GetBranch",
        "amplify:GetApp",
        "amplify:CreateDeployment",
        "amplify:StartDeployment",
        "amplify:StartJob",
        "amplify:GetJob",
        "amplify:ListJobs",
        "amplify:StopJob",
        "amplify:DeleteApp"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3ArtifactsAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::codebuild-*",
        "arn:aws:s3:::amplify-*"
      ]
    },
    {
      "Sid": "CodeBuildAccess",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
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
  echo "Updating IAM policy with specific permissions..."
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

  echo "Attaching custom policy with specific permissions..."
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC"

  # Attach the basic execution policy for CodeBuild
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

  echo "Waiting for IAM role to propagate..."
  sleep 10
fi

# Create buildspec.yml if it doesn't exist
BUILDSPEC_PATH="buildspec.yml"
if [ ! -f "$BUILDSPEC_PATH" ]; then
  echo "Creating buildspec.yml file..."
  cat > "$BUILDSPEC_PATH" <<EOF
version: 0.2

env:
  variables:
    STACK_NAME: "\${STACK_NAME}"
    REGION: "\${AWS_REGION}"
    AMPLIFY_BRANCH_NAME: "\${AMPLIFY_BRANCH_NAME}"
    AMPLIFY_APP_NAME: "\${AMPLIFY_APP_NAME}"
    APPLICATION_ID: "\${APPLICATION_ID}"
    ACTION: "\${ACTION}"

phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      - echo "🔧 Installing tools"
      - yum install -y jq zip
      - npm install -g aws-cli
      - npm install -g @aws-amplify/cli

  pre_build:
    commands:
      - echo "🔍 Starting \${ACTION} process"
      - |
        if [ "\${ACTION}" = "deploy" ]; then
          echo "🚀 Deploying resources"
          
          echo "🔍 Checking CloudFormation stack"
          if aws cloudformation describe-stacks --stack-name \$STACK_NAME --region \$REGION > /dev/null 2>&1; then
            echo "✅ Stack exists, updating..."
            aws cloudformation deploy \\
              --template-file template.json \\
              --stack-name \$STACK_NAME \\
              --capabilities CAPABILITY_NAMED_IAM \\
              --region \$REGION \\
              --parameter-overrides ApplicationId=\$APPLICATION_ID
          else
            echo "🆕 Stack does not exist, creating..."
            aws cloudformation deploy \\
              --template-file template.json \\
              --stack-name \$STACK_NAME \\
              --capabilities CAPABILITY_NAMED_IAM \\
              --region \$REGION \\
              --parameter-overrides ApplicationId=\$APPLICATION_ID
          fi
        elif [ "\${ACTION}" = "destroy" ]; then
          echo "🗑️ Destroying resources"
          aws cloudformation delete-stack --stack-name \$STACK_NAME --region \$REGION || true
          echo "⏳ Waiting for stack deletion..."
          aws cloudformation wait stack-delete-complete --stack-name \$STACK_NAME --region \$REGION || true
        fi

  build:
    commands:
      - |
        if [ "\${ACTION}" = "deploy" ]; then
          echo "📦 Fetching CloudFormation outputs"
          OUTPUTS=\$(aws cloudformation describe-stacks \\
            --stack-name \$STACK_NAME \\
            --region \$REGION \\
            --query "Stacks[0].Outputs" \\
            --output json)

          API_ENDPOINT=\$(echo \$OUTPUTS | jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue')
          CHAT_ENDPOINT=\$(echo \$OUTPUTS | jq -r '.[] | select(.OutputKey=="ChatEndpoint") | .OutputValue')
          FEEDBACK_ENDPOINT=\$(echo \$OUTPUTS | jq -r '.[] | select(.OutputKey=="FeedbackEndpoint") | .OutputValue')
          CHAT_LAMBDA=\$(echo \$OUTPUTS | jq -r '.[] | select(.OutputKey=="ChatLambdaFunction") | .OutputValue')
          FEEDBACK_LAMBDA=\$(echo \$OUTPUTS | jq -r '.[] | select(.OutputKey=="FeedbackLambdaFunction") | .OutputValue')

          echo "🌍 Generating .env file"
          mkdir -p frontend
          cat > frontend/.env <<EOL
REACT_APP_BASE_API_ENDPOINT=\$API_ENDPOINT
REACT_APP_API_ENDPOINT=\$CHAT_ENDPOINT
REACT_APP_FEEDBACK_ENDPOINT=\$FEEDBACK_ENDPOINT
REACT_APP_AWS_REGION=\$REGION
REACT_APP_LAMBDA_FUNCTION=\$CHAT_LAMBDA
REACT_APP_LAMBDA_FEEDBACK_FUNCTION=\$FEEDBACK_LAMBDA
REACT_APP_APPLICATION_ID=\$APPLICATION_ID
REACT_APP_DEFAULT_LANGUAGE=EN
EOL

          echo "📦 Installing frontend dependencies"
          cd frontend && npm install
          
          echo "🏗️ Building frontend"
          npm run build
          cd ..
          
          echo "📦 Creating deployment zip"
          cd frontend/build && zip -r ../../build.zip . && cd ../..
        fi

  post_build:
    commands:
      - |
        if [ "\${ACTION}" = "deploy" ]; then
          echo "🚧 Setting up Amplify app and branch"
          
          # Check if Amplify app exists
          AMPLIFY_APP_ID=\$(aws amplify list-apps --region \$REGION --query "apps[?name=='\$AMPLIFY_APP_NAME'].appId" --output text)
          
          if [ -z "\$AMPLIFY_APP_ID" ]; then
            echo "📗 Creating new Amplify app"
            AMPLIFY_APP_ID=\$(aws amplify create-app \\
              --name "\$AMPLIFY_APP_NAME" \\
              --region \$REGION \\
              --query "app.appId" --output text)
          else
            echo "✅ Using existing Amplify App ID: \$AMPLIFY_APP_ID"
          fi
          
          # Create or use existing branch
          echo "🔄 Setting up Amplify branch"
          aws amplify create-branch \\
            --app-id \$AMPLIFY_APP_ID \\
            --branch-name \$AMPLIFY_BRANCH_NAME \\
            --region \$REGION || echo "✅ Branch may already exist"
          
          # Stop any running jobs
          echo "⏹ Stopping previous deployment jobs if running"
          LAST_JOB_ID=\$(aws amplify list-jobs \\
            --app-id \$AMPLIFY_APP_ID \\
            --branch-name \$AMPLIFY_BRANCH_NAME \\
            --region \$REGION \\
            --query "jobSummaries[?status=='PENDING' || status=='PROVISIONING' || status=='RUNNING'].jobId" \\
            --output text)
          
          if [ -n "\$LAST_JOB_ID" ]; then
            aws amplify stop-job \\
              --app-id \$AMPLIFY_APP_ID \\
              --branch-name \$AMPLIFY_BRANCH_NAME \\
              --job-id \$LAST_JOB_ID \\
              --region \$REGION
          fi
          
          # Deploy to Amplify
          echo "📤 Creating deployment for Amplify app"
          DEPLOYMENT_INFO=\$(aws amplify create-deployment \\
            --app-id \$AMPLIFY_APP_ID \\
            --branch-name \$AMPLIFY_BRANCH_NAME \\
            --region \$REGION)
          
          DEPLOYMENT_URL=\$(echo \$DEPLOYMENT_INFO | jq -r '.zipUploadUrl')
          JOB_ID=\$(echo \$DEPLOYMENT_INFO | jq -r '.jobId')
          
          echo "📤 Uploading build.zip to Amplify"
          curl -T build.zip "\$DEPLOYMENT_URL"
          
          echo "🚦 Starting Amplify deployment"
          aws amplify start-deployment \\
            --app-id \$AMPLIFY_APP_ID \\
            --branch-name \$AMPLIFY_BRANCH_NAME \\
            --job-id \$JOB_ID \\
            --region \$REGION
          
          echo "🔗 Your deployed frontend will be available at:"
          echo "https://\$AMPLIFY_BRANCH_NAME.\$AMPLIFY_APP_ID.amplifyapp.com"
        elif [ "\${ACTION}" = "destroy" ]; then
          echo "🗑️ Cleaning up Amplify resources"
          
          # Find Amplify app
          AMPLIFY_APP_ID=\$(aws amplify list-apps --region \$REGION --query "apps[?name=='\$AMPLIFY_APP_NAME'].appId" --output text)
          
          if [ -n "\$AMPLIFY_APP_ID" ]; then
            echo "🗑️ Deleting Amplify app: \$AMPLIFY_APP_NAME (\$AMPLIFY_APP_ID)"
            aws amplify delete-app --app-id \$AMPLIFY_APP_ID --region \$REGION
          else
            echo "✅ No Amplify app found to delete"
          fi
        fi

artifacts:
  base-directory: frontend/build
  files:
    - "**/*"

cache:
  paths:
    - "frontend/node_modules/**/*"
EOF
fi

# Create CodeBuild project
CODEBUILD_PROJECT_NAME="${PROJECT_NAME}-deploy"
echo "Creating CodeBuild project: $CODEBUILD_PROJECT_NAME"

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
  "image": "aws/codebuild/amazonlinux2-x86_64-standard:4.0",
  "computeType": "BUILD_GENERAL1_SMALL",
  "environmentVariables": $ENV_VARS
}
EOF
)

ARTIFACTS='{"type":"NO_ARTIFACTS"}'

# Get the GitHub repository URL
if [ -z "${GITHUB_URL:-}" ]; then
  # Try to get the GitHub URL from git config
  GITHUB_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
  if [ -z "$GITHUB_URL" ]; then
    read -rp "Enter GitHub repository URL: " GITHUB_URL
  else
    echo "Detected GitHub URL: $GITHUB_URL"
  fi
fi

# Define SOURCE configuration for GitHub - using NO_SOURCE to avoid connection issues
SOURCE="{\"type\":\"NO_SOURCE\"}"

# Create or update CodeBuild project
if aws codebuild batch-get-projects --names "$CODEBUILD_PROJECT_NAME" --query 'projects[0].name' --output text 2>/dev/null | grep -q "$CODEBUILD_PROJECT_NAME"; then
  echo "Updating existing CodeBuild project..."
  aws codebuild update-project \
    --name "$CODEBUILD_PROJECT_NAME" \
    --source "$SOURCE" \
    --artifacts "$ARTIFACTS" \
    --environment "$ENVIRONMENT" \
    --service-role "$ROLE_ARN" \
    --output json \
    --no-cli-pager
else
  echo "Creating new CodeBuild project..."
  aws codebuild create-project \
    --name "$CODEBUILD_PROJECT_NAME" \
    --source "$SOURCE" \
    --artifacts "$ARTIFACTS" \
    --environment "$ENVIRONMENT" \
    --service-role "$ROLE_ARN" \
    --output json \
    --no-cli-pager
fi

if [ $? -eq 0 ]; then
  echo "✓ CodeBuild project '$CODEBUILD_PROJECT_NAME' created/updated."
else
  echo "✗ Failed to create/update CodeBuild project."
  exit 1
fi

echo "Starting deployment build..."
BUILD_ID=$(aws codebuild start-build \
  --project-name "$CODEBUILD_PROJECT_NAME" \
  --source-type-override NO_SOURCE \
  --buildspec-override "$(cat buildspec.yml)" \
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

echo ""
echo "=== Deployment Information ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Amplify App Name: $AMPLIFY_APP_NAME"
echo "Amplify Branch Name: $AMPLIFY_BRANCH_NAME"
echo "Region: $AWS_REGION"
echo "Action: $ACTION"
echo "Build ID: $BUILD_ID"
echo ""
echo "🚀 The deployment will:"
echo "1. Deploy backend via CloudFormation"
echo "2. Create/update Amplify app with name '$AMPLIFY_APP_NAME' and branch '$AMPLIFY_BRANCH_NAME'"
echo "3. Build and deploy frontend to Amplify hosting"
echo ""
echo "⏱️ Total deployment time: ~10-15 minutes"
echo "📊 Monitor progress in CodeBuild console"

exit 0