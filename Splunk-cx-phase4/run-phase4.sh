#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Starting Phase 4 - Splunk UF + OTEL                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Architecture:"
echo "  App → File → Splunk UF → Splunk Cloud"
echo "            └→ OTEL → Coralogix"
echo ""
echo "Building and starting containers..."
echo ""

# Stop any existing containers
docker-compose down 2>/dev/null || true

# Build and start with explicit platform for Splunk UF
echo "Building Splunk Universal Forwarder (x86_64)..."
docker-compose build --no-cache splunk-forwarder

echo ""
echo "Building other services..."
docker-compose build

echo ""
echo "Starting all services..."
docker-compose up -d

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Phase 4 Started!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Services running:"
docker-compose ps

echo ""
echo "View logs:"
echo "  docker-compose logs -f python-app        # App logs"
echo "  docker-compose logs -f splunk-forwarder  # Splunk UF"
echo "  docker-compose logs -f otel-collector    # OTEL"
echo ""
echo "Stop:"
echo "  docker-compose down"
echo ""
echo "Verification:"
echo "  Splunk: index=main sourcetype=\"python:phase4\""
echo "  Coralogix: applicationName:\"MyApp-Phase4\""
echo ""

