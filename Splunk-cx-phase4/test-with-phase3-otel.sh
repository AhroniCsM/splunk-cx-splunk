#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Phase 4: Splunk UF → Phase 3 OTEL → Splunk + Coralogix      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Phase 3 OTEL is running
echo "Checking if Phase 3 OTEL is running on port 8089..."
if ! curl -s http://localhost:8089/services/collector -o /dev/null -w "%{http_code}" | grep -q "400\|401"; then
    echo "❌ Error: Phase 3 OTEL is not running on port 8089"
    echo ""
    echo "Please start Phase 3 OTEL first:"
    echo "  cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase3"
    echo "  docker compose up -d otel-collector"
    echo ""
    exit 1
fi

echo "✅ Phase 3 OTEL is running on port 8089"
echo ""

echo "Architecture:"
echo "  Phase 4 App → File → Splunk UF → HEC → Phase 3 OTEL"
echo "                                            ↓"
echo "                              Splunk + Coralogix"
echo ""

# Stop any existing Phase 4 containers
echo "Stopping any existing Phase 4 containers..."
docker compose -f docker-compose.with-phase3-otel.yaml down 2>/dev/null || true

echo ""
echo "Building Phase 4 containers..."
echo "⚠️  WARNING: Splunk UF build may fail on ARM Mac (expected)"
echo "   Building for x86_64 architecture..."
echo ""

docker compose -f docker-compose.with-phase3-otel.yaml build

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to build containers"
    exit 1
fi

echo ""
echo "Starting Phase 4 containers..."
docker compose -f docker-compose.with-phase3-otel.yaml up -d

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to start containers"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   Containers Started!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Container Status:"
docker compose -f docker-compose.with-phase3-otel.yaml ps
echo ""

echo "Waiting 10 seconds for initialization..."
sleep 10

echo ""
echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase4-uf --tail 10
echo ""

echo "═══════════════════ Splunk UF Logs ═══════════════════"
docker logs splunk-uf-phase4 --tail 20 2>&1 || echo "⚠️  Splunk UF may have failed (ARM Mac limitation)"
echo ""

echo "═══════════════════ Phase 3 OTEL Logs ═══════════════════"
docker logs otel-collector-phase3 --tail 15 2>&1 || echo "Phase 3 OTEL not found as Docker container"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Verification                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Splunk UF is running
if docker ps | grep -q "splunk-uf-phase4"; then
    echo "✅ Splunk UF: Running"
    
    # Check for errors
    UF_ERRORS=$(docker logs splunk-uf-phase4 2>&1 | grep -i "error" | grep -v "0 error" | head -3)
    if [ -n "$UF_ERRORS" ]; then
        echo "⚠️  Splunk UF errors:"
        echo "$UF_ERRORS"
    fi
else
    echo "❌ Splunk UF: Not running (expected on ARM Mac)"
    echo "   This will work on x86_64 (EC2/ECS/EKS)"
fi

echo ""
echo "Check in Splunk:"
echo "  index=main sourcetype=\"python:phase3\""
echo "  (Logs will have RequestID from Phase 4 app)"
echo ""
echo "Check in Coralogix:"
echo "  applicationName:\"MyApp-Phase3\""
echo "  (Same RequestIDs as Splunk)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Monitor logs:"
echo "  docker logs -f python-app-phase4-uf"
echo "  docker logs -f splunk-uf-phase4"
echo "  docker logs -f otel-collector-phase3"
echo ""
echo "Stop:"
echo "  docker compose -f docker-compose.with-phase3-otel.yaml down"
echo ""

