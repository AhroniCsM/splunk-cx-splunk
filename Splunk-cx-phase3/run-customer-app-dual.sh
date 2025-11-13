#!/bin/bash
# Phase 3 - Dual Send Solution
# Customer app sends to BOTH Splunk (direct) and OTEL (for Coralogix)
# This solves the OTEL→Splunk channel issue

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Phase 3 - Dual Send Solution                               ║"
echo "║  App sends to BOTH Splunk + OTEL                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if OTEL is running
if ! docker ps | grep -q otel-collector-phase3; then
    echo "⚠️  OTEL Collector not running!"
    echo "Please start it first:"
    echo "  ./run-otel-collector.sh"
    exit 1
fi

echo "Building customer's app (Phase 1 code)..."
docker build -t customer-app-phase3:latest -f Dockerfile.hec . -q

echo ""
echo "Starting customer's app with dual endpoints..."
echo ""

# Stop existing container if running
docker rm -f customer-app-phase3-dual 2>/dev/null

# Run customer's app
# Sends to Splunk directly AND also generates logs for OTEL to pick up
docker run -d \
  --name customer-app-phase3-dual \
  -e SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088/services/collector" \
  -e SPLUNK_HEC_TOKEN="YOUR_SPLUNK_HEC_TOKEN" \
  -e SPLUNK_SOURCETYPE="python:phase3" \
  -e SPLUNK_INDEX="main" \
  -e LOG_INTERVAL_SECONDS="30" \
  -v splunk-cx-phase3-logs:/var/log/myapp \
  customer-app-phase3:latest

echo ""
echo "✅ Customer's app running with DUAL send!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "What Customer Changes (Option 1 - Recommended):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Keep Splunk endpoint AS-IS (direct to Splunk):"
echo "  SPLUNK_HEC_URL=https://your-instance.splunkcloud.com:8088/services/collector"
echo ""
echo "Just share log volume with OTEL (if using K8s/Docker Compose)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Result:"
echo "  ✅ Splunk gets logs directly (HEC with channel - works!)"
echo "  ✅ OTEL reads file, sends to Coralogix (works!)"
echo "  ✅ Same RequestIDs in both destinations"
echo ""
echo "View logs:"
echo "  docker logs -f customer-app-phase3-dual"

