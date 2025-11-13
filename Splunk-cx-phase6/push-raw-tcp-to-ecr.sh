#!/bin/bash

# Script to build and push Phase 6 RAW TCP images to ECR
# With sendCookedData=false for OTEL compatibility

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Building Phase 6 RAW TCP Images                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="104013952213"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build Splunk Forwarder with RAW TCP (sendCookedData=false)
echo ""
echo "Building Splunk Forwarder (RAW TCP mode)..."
docker build --platform linux/amd64 \
  -f Dockerfile.splunk-raw \
  -t ${ECR_REGISTRY}/splunk-phase6-forwarder-raw:latest \
  -t ${ECR_REGISTRY}/splunk-phase6-forwarder-raw:raw-tcp \
  .

# Push images
echo ""
echo "Pushing Splunk Forwarder to ECR..."
docker push ${ECR_REGISTRY}/splunk-phase6-forwarder-raw:latest
docker push ${ECR_REGISTRY}/splunk-phase6-forwarder-raw:raw-tcp

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Images pushed successfully!                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Images:"
echo "  - ${ECR_REGISTRY}/splunk-phase6-app:latest (reusing existing)"
echo "  - ${ECR_REGISTRY}/splunk-phase6-forwarder-raw:latest"
echo ""
echo "Next steps:"
echo "  1. Deploy to K8s: kubectl apply -f k8s/deployment-raw-tcp.yaml"
echo "  2. Wait 2-3 minutes for logs to flow"
echo "  3. Check Coralogix: application.name:\"k8s-phase6-tcp\""
echo "  4. Check Splunk: index=main sourcetype=\"python:phase6:k8s\""
echo "  5. Verify logs are CLEAN (not corrupted)!"

