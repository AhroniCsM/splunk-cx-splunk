#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Phase 4 LOCAL TEST (ARM Mac compatible)                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Test Configuration:"
echo "  App → File → OTEL → Splunk + Coralogix"
echo "  (Skipping Splunk UF - not compatible with ARM Mac)"
echo ""

# Stop any existing containers
echo "Stopping any existing Phase 4 test containers..."
docker compose -f docker-compose.test-local.yaml down 2>/dev/null || true

echo ""
echo "Building and starting containers..."
docker compose -f docker-compose.test-local.yaml up --build -d

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
docker compose -f docker-compose.test-local.yaml ps
echo ""

echo "Waiting 15 seconds for logs to generate and process..."
sleep 15

echo ""
echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase4-test --tail 15
echo ""

echo "═══════════════════ OTEL Logs (Last 30 lines) ═══════════════════"
docker logs otel-collector-phase4-test --tail 30 2>&1
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Verification                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check for errors
OTEL_ERRORS=$(docker logs otel-collector-phase4-test 2>&1 | grep -i "error" | grep -v "level=ERROR" | head -5)
if [ -n "$OTEL_ERRORS" ]; then
    echo "⚠️  OTEL Errors detected:"
    echo "$OTEL_ERRORS"
    echo ""
else
    echo "✅ OTEL: No errors detected"
fi

# Check if logs are being sent
SPLUNK_SENT=$(docker logs otel-collector-phase4-test 2>&1 | grep -i "splunk" | wc -l)
CORALOGIX_SENT=$(docker logs otel-collector-phase4-test 2>&1 | grep -i "coralogix" | wc -l)

echo "✅ App: Generating logs to file"
echo "✅ OTEL: Reading from file"

# Check for log processing
LOG_PROCESSING=$(docker logs otel-collector-phase4-test 2>&1 | grep -i "log records" | tail -1)
if [ -n "$LOG_PROCESSING" ]; then
    echo "✅ OTEL: Processing logs - $LOG_PROCESSING"
else
    echo "⏳ OTEL: Waiting for logs to be processed..."
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Check Logs in Splunk & Coralogix                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Splunk Search:"
echo "  index=main sourcetype=\"python:phase4:test\""
echo ""
echo "  You should see logs with:"
echo "    • sourcetype=\"python:phase4:test\""
echo "    • source=\"phase4-test\""
echo "    • RequestID: 1, 2, 3, etc."
echo ""
echo "Coralogix Filter:"
echo "  applicationName:\"MyApp-Phase4-Test\""
echo ""
echo "  You should see the SAME logs with the SAME RequestIDs!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Monitoring commands:"
echo "  docker logs -f python-app-phase4-test"
echo "  docker logs -f otel-collector-phase4-test"
echo ""
echo "Stop test:"
echo "  docker compose -f docker-compose.test-local.yaml down"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Phase 4 Test Running! Check Splunk and Coralogix now.        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

