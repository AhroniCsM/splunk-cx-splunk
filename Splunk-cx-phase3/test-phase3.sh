#!/bin/bash
# Complete test of Phase 3 - shows the full flow

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Phase 3 Complete Test                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")"

# Step 1: Start OTEL Collector
echo "Step 1: Starting OTEL Collector (your infrastructure)..."
./run-otel-collector.sh

sleep 5

# Step 2: Start Customer App
echo ""
echo "Step 2: Starting Customer's App (only env var changed)..."
./run-customer-app.sh

sleep 10

# Step 3: Verify
echo ""
echo "Step 3: Verifying logs are flowing..."
echo ""

echo "=== Customer App Logs ===" 
docker logs customer-app-phase3 2>&1 | grep -E "Sending to|Successfully|RequestID" | tail -5

echo ""
echo "=== OTEL Collector Processing ===" 
docker logs otel-collector-phase3 2>&1 | grep "RequestID" | tail -3

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Phase 3 Running Successfully!                           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Verify in Splunk:                                          ║"
echo "║    index=main sourcetype=\"python:phase3\"                    ║"
echo "║                                                              ║"
echo "║  Verify in Coralogix:                                       ║"
echo "║    applicationName:\"MyApp-Phase3\"                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|phase3|otel-collector-phase3"

