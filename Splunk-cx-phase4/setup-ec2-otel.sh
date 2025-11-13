#!/bin/bash
# Setup OTEL Collector on EC2 (like Phase 3)
# Run this ON YOUR EC2 INSTANCE

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Setup OTEL Collector on EC2 (Phase 3 Configuration)          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Create directory for OTEL config
mkdir -p ~/otel-collector
cd ~/otel-collector

# Create OTEL config (same as Phase 3)
cat > otel-collector-config.yaml << 'EOF_CONFIG'
receivers:
  # Splunk HEC Receiver - receives logs from Splunk UF
  splunk_hec:
    endpoint: 0.0.0.0:8088
    access_token_passthrough: true

processors:
  batch:
    timeout: 10s
    send_batch_size: 100
  resource:
    attributes:
      - key: environment
        value: production
        action: insert
      - key: source
        value: "ec2-otel"
        action: insert
  attributes:
    actions:
      - key: collector
        value: ec2-otel-collector
        action: insert

exporters:
  # Splunk HEC Exporter - forward to Splunk Cloud
  splunk_hec/logs:
    token: "${SPLUNK_HEC_TOKEN}"
    endpoint: "${SPLUNK_HEC_URL}"
    source: "ec2-otel"
    sourcetype: "python:phase4:production"
    index: "main"
    disable_compression: false
    timeout: 30s
    tls:
      insecure_skip_verify: true

  # Coralogix Exporter
  coralogix:
    domain: "${CORALOGIX_DOMAIN}"
    private_key: "${CORALOGIX_PRIVATE_KEY}"
    application_name: "${CORALOGIX_APPLICATION_NAME}"
    subsystem_name: "${CORALOGIX_SUBSYSTEM_NAME}"
    timeout: 30s

  # Debug exporter
  debug:
    verbosity: normal
    sampling_initial: 5
    sampling_thereafter: 200

service:
  pipelines:
    logs:
      receivers: [splunk_hec]
      processors: [batch, resource, attributes]
      exporters: [splunk_hec/logs, coralogix, debug]

  telemetry:
    logs:
      level: info
EOF_CONFIG

# Create docker-compose file
cat > docker-compose.yaml << 'EOF_COMPOSE'
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector-ec2
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml
    ports:
      - "8088:8088"   # HEC receiver (for Splunk UF)
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP  
      - "8888:8888"   # Prometheus metrics
    environment:
      - SPLUNK_HEC_TOKEN=YOUR_SPLUNK_HEC_TOKEN
      - SPLUNK_HEC_URL=https://your-instance.splunkcloud.com:8088
      - CORALOGIX_DOMAIN=eu2.coralogix.com
      - CORALOGIX_PRIVATE_KEY=YOUR_CORALOGIX_PRIVATE_KEY
      - CORALOGIX_APPLICATION_NAME=MyApp-Phase4-Production
      - CORALOGIX_SUBSYSTEM_NAME=EC2-OTEL
    restart: unless-stopped
EOF_COMPOSE

echo "✅ OTEL configuration files created:"
echo "   - otel-collector-config.yaml"
echo "   - docker-compose.yaml"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker is not installed!"
    echo ""
    echo "Install Docker:"
    echo "  sudo yum install -y docker  # Amazon Linux"
    echo "  sudo systemctl start docker"
    echo "  sudo systemctl enable docker"
    echo "  sudo usermod -aG docker \$USER"
    exit 1
fi

echo "Docker is installed ✅"
echo ""

# Start OTEL Collector
echo "Starting OTEL Collector..."
docker compose up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  OTEL Collector Started Successfully!                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "OTEL is now listening on:"
    echo "  • HEC:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8088/services/collector"
    echo "  • OTLP: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):4317"
    echo ""
    echo "⚠️  IMPORTANT: Update EC2 Security Group to allow:"
    echo "   • Inbound TCP port 8088 (HEC)"
    echo "   • Inbound TCP port 4317 (OTLP gRPC)"
    echo "   • Inbound TCP port 4318 (OTLP HTTP)"
    echo ""
    echo "Monitor logs:"
    echo "  docker logs -f otel-collector-ec2"
    echo ""
    echo "Stop:"
    echo "  docker compose down"
    echo ""
else
    echo "❌ Failed to start OTEL Collector"
    exit 1
fi

