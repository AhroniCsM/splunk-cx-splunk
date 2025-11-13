#!/bin/bash

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Starting Phase 5 - TCP Dual Path                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Architecture:"
echo "  App → File → ┬→ Splunk UF → TCP:9997 → Splunk Cloud"
echo "               └→ OTEL → OTLP → Coralogix"
echo ""

# Stop any existing containers
echo "Stopping existing Phase 5 containers..."
docker compose down 2>/dev/null || true
echo ""

# Build and start
echo "Building and starting containers..."
docker compose up -d
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   Phase 5 Started!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Show container status
echo "Container Status:"
docker compose ps
echo ""

# Wait for logs
echo "Waiting 10 seconds for logs to generate..."
sleep 10
echo ""

# Show logs
echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase5 --tail 10
echo ""

echo "═══════════════════ Splunk UF Logs ═══════════════════"
docker logs splunk-uf-phase5-tcp --tail 15 2>&1
echo ""

echo "═══════════════════ OTEL Logs ═══════════════════"
docker logs otel-collector-phase5 --tail 10
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Verification:"
echo "  Splunk: index=main sourcetype=\"python:phase5:tcp\""
echo "  Coralogix: applicationName:\"MyApp-Phase5-TCP\""
echo ""
echo "Monitor logs:"
echo "  docker logs -f python-app-phase5"
echo "  docker logs -f splunk-uf-phase5-tcp"
echo "  docker logs -f otel-collector-phase5"
echo ""
echo "Stop:"
echo "  docker compose down"
echo ""

