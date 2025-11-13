#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="104013952213"
ECR_REPO_APP="splunk-phase6-app"
ECR_REPO_UF="splunk-phase6-forwarder-tcp"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Push Phase 6 Images to ECR                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  ECR Registry: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo "✅ Login Succeeded"
echo ""

# Create ECR repositories if they don't exist
echo "Creating ECR repositories if needed..."
aws ecr describe-repositories --repository-names $ECR_REPO_APP --region $AWS_REGION > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name $ECR_REPO_APP --region $AWS_REGION
aws ecr describe-repositories --repository-names $ECR_REPO_UF --region $AWS_REGION > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name $ECR_REPO_UF --region $AWS_REGION
echo "✅ Repositories ready"
echo ""

# Build and push Python App image (multi-arch)
echo "Building Python App image (multi-arch)..."
docker buildx build --platform linux/amd64,linux/arm64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_APP:latest \
    -f Dockerfile.app \
    --push .
echo "✅ App image pushed"
echo ""

# Build and push Splunk UF image (x86_64 only)
echo "Building Splunk UF image (x86_64)..."
docker buildx build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_UF:latest \
    -f Dockerfile.splunk-k8s \
    --push .
echo "✅ Splunk UF image pushed"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Push Complete!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Images pushed:"
echo "  ✅ $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_APP:latest"
echo "  ✅ $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_UF:latest"
echo ""
echo "Next: Deploy to Kubernetes"
echo "  cd k8s"
echo "  kubectl apply -f ."
echo ""

