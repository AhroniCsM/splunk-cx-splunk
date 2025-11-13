#!/bin/bash
# Configure Phase 4 to point to your EC2 OTEL collector

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Configure Phase 4 to Send to EC2 OTEL Collector              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Prompt for EC2 information
read -p "Enter your EC2 IP address or hostname: " EC2_HOST

if [ -z "$EC2_HOST" ]; then
    echo "❌ Error: EC2 host cannot be empty"
    exit 1
fi

# Ask for port (default 8088)
read -p "Enter OTEL HEC receiver port [8088]: " OTEL_PORT
OTEL_PORT=${OTEL_PORT:-8088}

echo ""
echo "Configuration:"
echo "  EC2 Host: $EC2_HOST"
echo "  OTEL Port: $OTEL_PORT"
echo "  Full URL: http://$EC2_HOST:$OTEL_PORT/services/collector"
echo ""

# Update outputs.conf
cat > outputs-hec-ec2.conf << EOF_CONF
# Splunk Universal Forwarder - HEC Output to EC2 OTEL
# Configured for: $EC2_HOST:$OTEL_PORT

[default]
defaultGroup = ec2_otel

# Send via HEC to EC2 OTEL Collector
[httpout:ec2_otel]
uri = http://$EC2_HOST:$OTEL_PORT/services/collector
token = YOUR_SPLUNK_HEC_TOKEN

# Disable compression for better compatibility
compressed = false

# Retry settings
maxConnectionsPerHost = 2
EOF_CONF

echo "✅ Configuration file updated: outputs-hec-ec2.conf"
echo ""

# Test connectivity
echo "Testing connectivity to EC2 OTEL..."
if curl -s -o /dev/null -w "%{http_code}" "http://$EC2_HOST:$OTEL_PORT/services/collector" | grep -q "400\|401"; then
    echo "✅ EC2 OTEL is reachable!"
else
    echo "⚠️  Warning: Cannot reach EC2 OTEL at http://$EC2_HOST:$OTEL_PORT"
    echo "   Make sure:"
    echo "   1. EC2 OTEL is running"
    echo "   2. Security group allows port $OTEL_PORT"
    echo "   3. Firewall allows inbound traffic"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Next Steps                                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Make sure your EC2 OTEL is configured (see: setup-ec2-otel.sh)"
echo ""
echo "2. Deploy Phase 4 using the EC2 configuration:"
echo "   ./deploy-phase4-to-ec2-otel.sh"
echo ""
echo "3. Verify logs arrive in Splunk and Coralogix"
echo ""

