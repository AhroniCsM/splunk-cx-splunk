#!/bin/bash
# Simple script to update EC2 OTEL config for Phase 6
# Run this ON YOUR EC2 machine: bash update-ec2-otel.sh

echo "Starting OTEL config update for Phase 6..."
echo ""

# Step 1: Backup
echo "Step 1: Backing up current config..."
sudo cp /etc/otelcol-contrib/config.yaml /etc/otelcol-contrib/config.yaml.backup
echo "✅ Backup created"
echo ""

# Step 2: Create new config
echo "Step 2: Creating new config with tcplog receiver..."
cat > /tmp/phase6-config.yaml <<'EOF'
receivers:
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
  attributes:
    actions:
      - key: collector
        value: ec2-otel-tcplog
        action: insert

exporters:
  splunk_hec/logs:
    token: "YOUR_SPLUNK_HEC_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
    source: "k8s-phase6-tcp"
    sourcetype: "python:phase6:k8s"
    index: "main"
    tls:
      insecure_skip_verify: true
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_PRIVATE_KEY"
    application_name: "k8s-phase6-tcp"
    subsystem_name: "kubernetes-central"
    timeout: 30s
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
EOF

echo "✅ New config created"
echo ""

# Step 3: Install config
echo "Step 3: Installing new config..."
sudo cp /tmp/phase6-config.yaml /etc/otelcol-contrib/config.yaml
echo "✅ Config installed"
echo ""

# Step 4: Reload OTEL
echo "Step 4: Reloading OTEL..."
sudo kill -HUP $(pgrep otelcol)
echo "✅ OTEL reloaded"
echo ""

# Step 5: Verify
echo "Step 5: Verifying..."
sleep 3

echo "Port 9997 status:"
sudo netstat -tlnp | grep 9997
echo ""

echo "Connections from Kubernetes:"
sudo lsof -i :9997
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ DONE!                                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Wait 2-3 minutes, then check:"
echo ""
echo "  Coralogix: application.name:\"k8s-phase6-tcp\""
echo "  Splunk:    index=main sourcetype=\"python:phase6:k8s\""
echo ""

