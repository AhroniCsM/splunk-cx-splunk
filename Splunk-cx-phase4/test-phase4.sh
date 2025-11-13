#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Testing Phase 4 with ECR Images                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Starting Phase 4 with ECR images..."
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin 104013952213.dkr.ecr.us-east-1.amazonaws.com

# Stop any existing containers
docker compose -f docker-compose.ecr.yaml down 2>/dev/null || true

# Start with ECR images
docker compose -f docker-compose.ecr.yaml up -d

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   Phase 4 Started!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Containers:"
docker compose -f docker-compose.ecr.yaml ps
echo ""
echo "Waiting 10 seconds for logs to generate..."
sleep 10
echo ""
echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase4 --tail 20
echo ""
echo "═══════════════════ Splunk UF Logs ═══════════════════"
docker logs splunk-forwarder-phase4 --tail 20
echo ""
echo "═══════════════════ OTEL Logs ═══════════════════"
docker logs otel-collector-phase4 --tail 20
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Verification:"
echo "  Splunk: index=main sourcetype=\"python:phase4\""
echo "  Coralogix: applicationName:\"MyApp-Phase4\""
echo ""
echo "View logs:"
echo "  docker logs -f python-app-phase4"
echo "  docker logs -f splunk-forwarder-phase4"
echo "  docker logs -f otel-collector-phase4"
echo ""
echo "Stop:"
echo "  docker compose -f docker-compose.ecr.yaml down"
echo ""

