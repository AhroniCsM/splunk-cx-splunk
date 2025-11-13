#!/bin/bash
# Fix EC2 OTEL to receive Phase 6 TCP logs from Kubernetes
# Run this on EC2: bash fix-ec2-otel.sh

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Phase 6 EC2 OTEL Fix Script                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Find OTEL process
echo "Step 1: Finding OTEL process..."
OTEL_PID=$(pgrep -f otelcol || echo "")

if [ -z "$OTEL_PID" ]; then
    echo -e "${RED}❌ OTEL process not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ OTEL found (PID: $OTEL_PID)${NC}"

# Step 2: Find config file
echo ""
echo "Step 2: Finding OTEL config file..."
CONFIG_FILE=$(cat /proc/$OTEL_PID/cmdline | tr '\0' '\n' | grep "config" | sed 's/--config=//' | grep -v "^--" || echo "")

if [ -z "$CONFIG_FILE" ]; then
    # Try common locations
    if [ -f "/etc/otelcol-contrib/config.yaml" ]; then
        CONFIG_FILE="/etc/otelcol-contrib/config.yaml"
    elif [ -f "/opt/otel/config.yaml" ]; then
        CONFIG_FILE="/opt/otel/config.yaml"
    else
        echo -e "${RED}❌ Cannot find OTEL config file${NC}"
        echo "Please specify manually: export CONFIG_FILE=/path/to/config.yaml"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Config file: $CONFIG_FILE${NC}"

# Step 3: Check if tcplog is configured
echo ""
echo "Step 3: Checking if tcplog receiver is configured..."
if grep -q "tcplog:" "$CONFIG_FILE"; then
    echo -e "${GREEN}✅ tcplog receiver is configured!${NC}"

    # Check for connections
    echo ""
    echo "Step 4: Checking for K8s connections..."
    CONNECTIONS=$(lsof -i :9997 2>/dev/null | grep ESTABLISHED || echo "")

    if [ -n "$CONNECTIONS" ]; then
        echo -e "${GREEN}✅ Active connections found:${NC}"
        lsof -i :9997
        echo ""
        echo -e "${GREEN}🎉 Everything looks good!${NC}"
        echo "Logs should be appearing in:"
        echo "  - Coralogix: application.name:\"k8s-phase6-tcp\""
        echo "  - Splunk: index=main sourcetype=\"python:phase6:k8s\""
        echo ""
        echo "If you don't see logs, check OTEL logs for parsing errors."
    else
        echo -e "${YELLOW}⚠️  Port 9997 is listening but no connections yet${NC}"
        echo ""
        echo "Possible issues:"
        echo "  1. K8s Splunk UF hasn't connected yet (wait 1-2 minutes)"
        echo "  2. Network/firewall blocking connection"
        echo "  3. Splunk UF not configured correctly"
        echo ""
        echo "Port status:"
        netstat -tlnp | grep 9997
    fi
else
    echo -e "${RED}❌ tcplog receiver NOT configured!${NC}"
    echo ""
    echo "Need to add tcplog receiver to config."
    echo ""

    # Backup config
    echo "Step 4: Backing up current config..."
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✅ Backup created: ${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)${NC}"

    # Create new config with tcplog
    echo ""
    echo "Step 5: Creating new config with tcplog receiver..."

    cat > /tmp/otel-config-phase6.yaml << 'YAML'
receivers:
  # tcplog receiver for Kubernetes Splunk UF
  tcplog:
    listen_address: "0.0.0.0:9997"
    max_log_size: 1MiB

processors:
  batch:
    timeout: 10s
    send_batch_size: 100

  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
      - key: phase
        value: "6-k8s-tcp"
        action: upsert
      - key: source
        value: kubernetes
        action: upsert

  attributes:
    actions:
      - key: collector
        value: ec2-otel-tcplog
        action: insert

exporters:
  # Splunk HEC Exporter
  splunk_hec/logs:
    token: "YOUR_SPLUNK_HEC_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
    source: "k8s-phase6-tcp"
    sourcetype: "python:phase6:k8s"
    index: "main"
    disable_compression: false
    timeout: 30s
    tls:
      insecure_skip_verify: true

  # Coralogix Exporter
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_PRIVATE_KEY"
    application_name: "k8s-phase6-tcp"
    subsystem_name: "kubernetes-central"
    timeout: 30s

  # Debug exporter
  debug:
    verbosity: detailed
    sampling_initial: 10
    sampling_thereafter: 100

service:
  pipelines:
    logs:
      receivers: [tcplog]
      processors: [batch, resource, attributes]
      exporters: [splunk_hec/logs, coralogix, debug]

  telemetry:
    logs:
      level: info
YAML

    echo -e "${GREEN}✅ New config created: /tmp/otel-config-phase6.yaml${NC}"
    echo ""
    echo "Step 6: Replacing config file..."
    sudo cp /tmp/otel-config-phase6.yaml "$CONFIG_FILE"
    echo -e "${GREEN}✅ Config replaced${NC}"

    # Restart OTEL
    echo ""
    echo "Step 7: Restarting OTEL..."
    echo -e "${YELLOW}⚠️  Attempting to restart OTEL process...${NC}"

    # Try different restart methods
    if systemctl is-active otel-collector &>/dev/null; then
        sudo systemctl restart otel-collector
        echo -e "${GREEN}✅ Restarted via systemctl${NC}"
    elif systemctl is-active otelcol-contrib &>/dev/null; then
        sudo systemctl restart otelcol-contrib
        echo -e "${GREEN}✅ Restarted via systemctl${NC}"
    else
        echo -e "${RED}❌ Cannot restart automatically (not a systemd service)${NC}"
        echo ""
        echo "Manual restart required:"
        echo "  1. Find how OTEL was started (check screen/tmux/nohup)"
        echo "  2. Kill process: sudo kill $OTEL_PID"
        echo "  3. Restart with: sudo /usr/local/bin/otelcol-contrib --config=$CONFIG_FILE &"
        echo ""
        echo "Or simply:"
        echo "  sudo kill -HUP $OTEL_PID  # Send reload signal"
    fi

    echo ""
    echo "Step 8: Waiting for OTEL to start..."
    sleep 5

    # Check if port is listening
    if netstat -tlnp | grep -q 9997; then
        echo -e "${GREEN}✅ Port 9997 is listening!${NC}"
        netstat -tlnp | grep 9997
    else
        echo -e "${RED}❌ Port 9997 is not listening after restart${NC}"
        echo "Check OTEL logs for errors"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Next Steps                                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Check for connections from K8s pod (172.31.5.184):"
echo "   lsof -i :9997"
echo ""
echo "2. Check OTEL logs (if available):"
echo "   tail -f /var/log/otel/* (or wherever OTEL logs are)"
echo ""
echo "3. Check Coralogix for logs:"
echo "   application.name:\"k8s-phase6-tcp\""
echo ""
echo "4. Check Splunk for logs:"
echo "   index=main sourcetype=\"python:phase6:k8s\""
echo ""
echo "If no logs appear within 2-3 minutes, check OTEL logs for errors."
echo ""

