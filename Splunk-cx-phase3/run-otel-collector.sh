#!/bin/bash
# Start OTEL Collector (runs independently)
# This is deployed by YOU (not the customer)

echo "Starting OTEL Collector Phase 3..."
echo "This acts as an HEC proxy that forwards to Splunk + Coralogix"
echo ""

cd "$(dirname "$0")"

docker compose up -d

echo ""
echo "✅ OTEL Collector running on port 8089"
echo "Customers should point their SPLUNK_HEC_URL to:"
echo "  http://localhost:8089/services/collector  (for local testing)"
echo "  http://your-server-ip:8089/services/collector  (for production)"
echo ""
echo "View logs:"
echo "  docker logs -f otel-collector-phase3"

