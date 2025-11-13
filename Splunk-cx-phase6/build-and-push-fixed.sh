#!/bin/bash

# Build and push FIXED Splunk UF image for Phase 6
# This version uses full Debian base with all required dependencies

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Building FIXED Splunk UF Image for Phase 6                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="104013952213"
APP_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/splunk-phase6-app"
FORWARDER_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/splunk-phase6-forwarder-tcp"

echo "📦 Building images..."
echo ""

# Build app image (unchanged)
echo "1️⃣  Building Python app image..."
docker build --platform linux/amd64 -f Dockerfile.app -t ${APP_REPO}:latest -t ${APP_REPO}:fixed .
echo "✅ App image built"
echo ""

# Build FIXED Splunk forwarder image
echo "2️⃣  Building FIXED Splunk forwarder image (with full dependencies)..."
docker build --platform linux/amd64 -f Dockerfile.splunk-k8s-fixed -t ${FORWARDER_REPO}:latest -t ${FORWARDER_REPO}:fixed .
echo "✅ Forwarder image built"
echo ""

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
echo "✅ Logged in to ECR"
echo ""

# Push images
echo "⬆️  Pushing images to ECR..."
echo ""

echo "Pushing app image..."
docker push ${APP_REPO}:latest
docker push ${APP_REPO}:fixed
echo "✅ App image pushed"
echo ""

echo "Pushing FIXED forwarder image..."
docker push ${FORWARDER_REPO}:latest
docker push ${FORWARDER_REPO}:fixed
echo "✅ Forwarder image pushed"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ FIXED Images Built and Pushed Successfully!                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Images:"
echo "  📱 App:       ${APP_REPO}:fixed"
echo "  📡 Forwarder: ${FORWARDER_REPO}:fixed"
echo ""
echo "Next steps:"
echo "1. Update K8s deployment to use :fixed tag"
echo "2. Delete existing pod to force recreation"
echo "3. Check logs to verify Splunk is running"
echo ""
echo "Commands:"
echo "  kubectl set image deployment/splunk-phase6-app \\"
echo "    splunk-forwarder=${FORWARDER_REPO}:fixed"
echo "  kubectl delete pod -l app=splunk-phase6"
echo "  kubectl logs -f -l app=splunk-phase6 -c splunk-forwarder"
echo ""

