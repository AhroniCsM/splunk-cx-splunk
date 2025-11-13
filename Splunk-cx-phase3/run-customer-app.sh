#!/bin/bash
# Phase 3: Customer runs their app EXACTLY like Phase 1
# ONLY CHANGE: SPLUNK_HEC_URL points to OTEL instead of Splunk

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Customer's App - Phase 3                                   ║"
echo "║  EXACT same code as Phase 1                                 ║"
echo "║  ONLY CHANGE: SPLUNK_HEC_URL env var                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if OTEL is running
if ! docker ps | grep -q otel-collector-phase3; then
    echo "⚠️  OTEL Collector not running!"
    echo "Please start it first:"
    echo "  ./run-otel-collector.sh"
    exit 1
fi

echo "Building customer's app (Phase 1 code, unchanged)..."
docker build -t customer-app-phase3:latest -f Dockerfile.hec . -q

echo ""
echo "Starting customer's app with ONE env var changed..."
echo ""

# Stop existing containers if running
docker rm -f customer-app-phase3 customer-app-phase3-dual 2>/dev/null

# Run customer's app - ONLY endpoint changed!
docker run -d \
  --name customer-app-phase3 \
  -e SPLUNK_HEC_URL="http://host.docker.internal:8089/services/collector" \
  -e SPLUNK_HEC_TOKEN="YOUR_SPLUNK_HEC_TOKEN" \
  -e SPLUNK_SOURCETYPE="python:phase3" \
  -e SPLUNK_INDEX="main" \
  -e LOG_INTERVAL_SECONDS="30" \
  customer-app-phase3:latest

echo ""
echo "✅ Customer's app running!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "What Changed for Customer: ONE ENV VAR!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "BEFORE (Phase 1):"
echo "  SPLUNK_HEC_URL=https://your-instance.splunkcloud.com:8088/services/collector"
echo ""
echo "AFTER (Phase 3):"
echo "  SPLUNK_HEC_URL=http://your-otel-server:8089/services/collector"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Result:"
echo "  ✅ App sends HEC to OTEL (instead of Splunk)"
echo "  ✅ OTEL forwards to Coralogix (works!)"
echo "  ⚠️  OTEL forwards to Splunk (may have 400 errors)"
echo "  ✅ Customer code unchanged!"
echo ""
echo "Note: OTEL→Splunk may fail due to channel requirement."
echo "      But Coralogix will always work!"
echo ""
echo "View logs:"
echo "  docker logs -f customer-app-phase3"
echo ""
echo "View OTEL processing:"
echo "  docker logs -f otel-collector-phase3"

