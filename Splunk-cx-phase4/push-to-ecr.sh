#!/bin/bash
# Script to push Phase 4 images to AWS ECR
# Use this if building on ARM Mac is problematic

set -e

# Configuration - UPDATE THESE
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="104013952213"
ECR_REPO_APP="splunk-phase4-app"
ECR_REPO_UF="splunk-phase4-forwarder"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Push Phase 4 Images to ECR                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if AWS_ACCOUNT_ID is set
if [ "$AWS_ACCOUNT_ID" == "YOUR_AWS_ACCOUNT_ID" ]; then
    echo "❌ Error: Please set AWS_ACCOUNT_ID in this script"
    echo ""
    echo "Get your AWS Account ID:"
    echo "  aws sts get-caller-identity --query Account --output text"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  ECR Registry: $ECR_REGISTRY"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

# Create repositories if they don't exist
echo ""
echo "Creating ECR repositories if needed..."
aws ecr describe-repositories --repository-names $ECR_REPO_APP --region $AWS_REGION 2>/dev/null || \
    aws ecr create-repository --repository-name $ECR_REPO_APP --region $AWS_REGION

aws ecr describe-repositories --repository-names $ECR_REPO_UF --region $AWS_REGION 2>/dev/null || \
    aws ecr create-repository --repository-name $ECR_REPO_UF --region $AWS_REGION

# Build and push App image
echo ""
echo "Building Python App image..."
docker build \
    -t $ECR_REPO_APP:latest \
    -f Dockerfile.app \
    .

echo "Tagging and pushing App image..."
docker tag $ECR_REPO_APP:latest $ECR_REGISTRY/$ECR_REPO_APP:latest
docker push $ECR_REGISTRY/$ECR_REPO_APP:latest

# Build and push Splunk UF image (x86_64)
echo ""
echo "Building Splunk UF image (x86_64)..."
docker build \
    --platform linux/amd64 \
    -t $ECR_REPO_UF:latest \
    -f Dockerfile.splunk \
    .

echo "Tagging and pushing Splunk UF image..."
docker tag $ECR_REPO_UF:latest $ECR_REGISTRY/$ECR_REPO_UF:latest
docker push $ECR_REGISTRY/$ECR_REPO_UF:latest

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Push Complete!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Images pushed:"
echo "  $ECR_REGISTRY/$ECR_REPO_APP:latest"
echo "  $ECR_REGISTRY/$ECR_REPO_UF:latest"
echo ""
echo "Update docker-compose.yaml to use these images:"
echo ""
echo "  python-app:"
echo "    image: $ECR_REGISTRY/$ECR_REPO_APP:latest"
echo ""
echo "  splunk-forwarder:"
echo "    image: $ECR_REGISTRY/$ECR_REPO_UF:latest"
echo "    platform: linux/amd64"
echo ""

