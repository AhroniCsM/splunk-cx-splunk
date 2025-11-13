#!/bin/bash

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Phase 6 - EXPERIMENTAL TCP with tcplog Receiver           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This is experimental!"
echo "⚠️  tcplog is for generic TCP, not Splunk's proprietary protocol"
echo "⚠️  May not work as expected"
echo ""
echo "Architecture:"
echo "  App → File → Splunk UF → TCP:9997 → OTEL tcplog → [Splunk, Coralogix]"
echo ""

# Stop any existing containers
echo "Stopping existing Phase 6 containers..."
docker compose down 2>/dev/null || true
echo ""

# Build and start
echo "Building and starting containers..."
docker compose up -d
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   Phase 6 Started!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Show container status
echo "Container Status:"
docker compose ps
echo ""

# Wait for startup
echo "Waiting 15 seconds for services to start..."
sleep 15
echo ""

# Show logs
echo "═══════════════════ Python App Logs ═══════════════════"
docker logs python-app-phase6 --tail 10
echo ""

echo "═══════════════════ OTEL Logs (IMPORTANT!) ═══════════════════"
echo "Look for TCP connections and parsing..."
docker logs otel-collector-phase6 --tail 20 2>&1
echo ""

echo "═══════════════════ Splunk UF Logs ═══════════════════"
docker logs splunk-uf-phase6-tcp --tail 15 2>&1
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  IMPORTANT: Monitor OTEL logs for errors!"
echo ""
echo "Watch OTEL logs in real-time:"
echo "  docker logs -f otel-collector-phase6"
echo ""
echo "If you see errors or garbled data:"
echo "  → tcplog cannot handle Splunk TCP protocol"
echo "  → Use Phase 4 (HEC) instead ✅"
echo ""
echo "Verification:"
echo "  Splunk: index=main sourcetype=\"python:phase6:tcp\""
echo "  Coralogix: applicationName:\"MyApp-Phase6-TCP-Experimental\""
echo ""
echo "Stop:"
echo "  docker compose down"
echo ""

