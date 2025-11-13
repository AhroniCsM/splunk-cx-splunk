#!/bin/bash
# Deploy Phase 4 on EC2 (x86_64) instance

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Phase 4 Deployment - x86_64 Environment                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on x86_64
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "❌ Error: This script requires x86_64 architecture"
    echo "   Current architecture: $ARCH"
    echo ""
    echo "   Please run this on:"
    echo "   - EC2 x86_64 instance"
    echo "   - ECS x86_64 task"
    echo "   - Any x86_64 Linux host"
    exit 1
fi

echo "✅ Architecture check: $ARCH (OK)"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo ""
    echo "Install Docker:"
    echo "  sudo yum install -y docker  # Amazon Linux/RHEL"
    echo "  sudo apt install -y docker.io  # Ubuntu/Debian"
    exit 1
fi

echo "✅ Docker installed"
echo ""

# Check AWS credentials for ECR
if ! aws sts get-caller-identity &> /dev/null; then
    echo "⚠️  Warning: AWS CLI not configured or no credentials"
    echo "   You may need to configure AWS credentials to pull from ECR"
    echo ""
fi

# Login to ECR
echo "Logging in to ECR..."
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="104013952213"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to login to ECR"
    echo "   Check AWS credentials and permissions"
    exit 1
fi

echo "✅ ECR login successful"
echo ""

# Pull images
echo "Pulling images from ECR..."
docker pull ${ECR_REGISTRY}/splunk-phase4-app:latest
docker pull ${ECR_REGISTRY}/splunk-phase4-forwarder:latest

echo "✅ Images pulled successfully"
echo ""

# Check if docker-compose.ecr.yaml exists
if [ ! -f "docker-compose.ecr.yaml" ]; then
    echo "❌ Error: docker-compose.ecr.yaml not found"
    echo "   Make sure you're in the deployment directory"
    exit 1
fi

# Stop any existing containers
echo "Stopping any existing Phase 4 containers..."
docker compose -f docker-compose.ecr.yaml down 2>/dev/null || true

echo ""
echo "Starting Phase 4 containers..."
docker compose -f docker-compose.ecr.yaml up -d

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to start containers"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                Phase 4 Deployed Successfully!                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Waiting 10 seconds for containers to initialize..."
sleep 10

echo ""
echo "Container Status:"
docker compose -f docker-compose.ecr.yaml ps
echo ""

echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase4 --tail 10
echo ""

echo "═══════════════════ Splunk UF Logs ═══════════════════"
docker logs splunk-forwarder-phase4 --tail 15
echo ""

echo "═══════════════════ OTEL Logs ═══════════════════"
docker logs otel-collector-phase4 --tail 10 2>&1 | grep -v "debug"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Verification                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check for errors in Splunk UF
SPLUNK_ERRORS=$(docker logs splunk-forwarder-phase4 2>&1 | grep -i "error" | grep -v "0 errors" | head -5)
if [ -n "$SPLUNK_ERRORS" ]; then
    echo "⚠️  Splunk UF warnings/errors detected:"
    echo "$SPLUNK_ERRORS"
    echo ""
    echo "Check full logs: docker logs splunk-forwarder-phase4"
    echo ""
else
    echo "✅ Splunk UF: No critical errors"
fi

# Check for errors in OTEL
OTEL_ERRORS=$(docker logs otel-collector-phase4 2>&1 | grep -i "error" | head -5)
if [ -n "$OTEL_ERRORS" ]; then
    echo "⚠️  OTEL warnings/errors detected:"
    echo "$OTEL_ERRORS"
    echo ""
    echo "Check full logs: docker logs otel-collector-phase4"
    echo ""
else
    echo "✅ OTEL: No errors detected"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                Next Steps                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Verify logs in Splunk:"
echo "   index=main sourcetype=\"python:phase4\""
echo ""
echo "2. Verify logs in Coralogix:"
echo "   applicationName:\"MyApp-Phase4\""
echo ""
echo "3. Monitor logs:"
echo "   docker logs -f python-app-phase4"
echo "   docker logs -f splunk-forwarder-phase4"
echo "   docker logs -f otel-collector-phase4"
echo ""
echo "4. Stop deployment:"
echo "   docker compose -f docker-compose.ecr.yaml down"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️  IMPORTANT: Check Splunk Cloud TCP Port 9997             ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  If logs don't appear in Splunk:                              ║"
echo "║  1. Enable TCP port 9997 in Splunk Cloud                      ║"
echo "║  2. Settings → Forwarding and receiving → Configure receiving ║"
echo "║  3. Add port 9997                                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

