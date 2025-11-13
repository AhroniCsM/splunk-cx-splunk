#!/bin/bash
# Deploy Phase 4 to send logs to EC2 OTEL collector

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Deploy Phase 4 → EC2 OTEL Collector                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if outputs-hec-ec2.conf is configured
if ! grep -q "YOUR_EC2_IP_HERE" outputs-hec-ec2.conf 2>/dev/null; then
    echo "✅ EC2 configuration found"
else
    echo "⚠️  EC2 not configured yet!"
    echo ""
    echo "Please run first:"
    echo "  ./configure-ec2.sh"
    echo ""
    exit 1
fi

# Create Dockerfile that uses EC2 config
cat > Dockerfile.splunk-ec2 << 'EOF_DOCKERFILE'
# Splunk Universal Forwarder - configured for EC2 OTEL
FROM --platform=linux/amd64 debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    wget \
    procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget -O splunkforwarder.tgz \
    "https://download.splunk.com/products/universalforwarder/releases/9.3.1/linux/splunkforwarder-9.3.1-0b8d769cb912-Linux-x86_64.tgz" \
    && tar -xzf splunkforwarder.tgz -C /opt \
    && rm splunkforwarder.tgz

ENV SPLUNK_HOME=/opt/splunkforwarder
ENV PATH=$SPLUNK_HOME/bin:$PATH

COPY inputs.conf /opt/splunkforwarder/etc/system/local/inputs.conf
COPY outputs-hec-ec2.conf /opt/splunkforwarder/etc/system/local/outputs.conf

RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting Splunk Universal Forwarder..."\n\
echo "Sending to EC2 OTEL Collector"\n\
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt\n\
echo "Splunk Universal Forwarder started successfully"\n\
tail -f /opt/splunkforwarder/var/log/splunk/splunkd.log\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8089
CMD ["/entrypoint.sh"]
EOF_DOCKERFILE

# Create docker-compose for EC2 deployment
cat > docker-compose.ec2.yaml << 'EOF_COMPOSE'
version: '3.8'

services:
  python-app:
    build:
      context: .
      dockerfile: Dockerfile.app
    container_name: python-app-phase4-ec2
    environment:
      - LOG_FILE=/var/log/myapp/application.log
      - LOG_INTERVAL_SECONDS=30
    volumes:
      - app-logs:/var/log/myapp
    networks:
      - phase4-ec2-network
    restart: unless-stopped

  splunk-forwarder:
    build:
      context: .
      dockerfile: Dockerfile.splunk-ec2
      platforms:
        - linux/amd64
    platform: linux/amd64
    container_name: splunk-uf-phase4-ec2
    volumes:
      - app-logs:/var/log/myapp:ro
    networks:
      - phase4-ec2-network
    restart: unless-stopped
    depends_on:
      - python-app

volumes:
  app-logs:

networks:
  phase4-ec2-network:
    driver: bridge
EOF_COMPOSE

echo "✅ Deployment files created"
echo ""

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "⚠️  WARNING: Running on $ARCH architecture"
    echo "   Splunk UF requires x86_64"
    echo "   Build will work, but UF may not run on ARM Mac"
    echo ""
fi

echo "Building containers..."
docker compose -f docker-compose.ec2.yaml build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo ""
echo "Starting Phase 4 containers..."
docker compose -f docker-compose.ec2.yaml up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Phase 4 Started!                                              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    docker compose -f docker-compose.ec2.yaml ps
    echo ""

    # Get EC2 endpoint from config
    EC2_ENDPOINT=$(grep "^uri =" outputs-hec-ec2.conf | awk '{print $3}')
    echo "Sending logs to: $EC2_ENDPOINT"
    echo ""

    echo "Monitor logs:"
    echo "  docker logs -f python-app-phase4-ec2"
    echo "  docker logs -f splunk-uf-phase4-ec2"
    echo ""

    echo "Verify on EC2:"
    echo "  docker logs -f otel-collector-ec2"
    echo ""

    echo "Stop:"
    echo "  docker compose -f docker-compose.ec2.yaml down"
    echo ""
else
    echo "❌ Failed to start containers"
    exit 1
fi

