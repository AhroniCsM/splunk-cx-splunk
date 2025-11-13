#!/bin/bash
set -e

echo "================================================"
echo "Starting Splunk Universal Forwarder + Python App"
echo "================================================"

# Set default values if not provided
SPLUNK_FORWARDER_HOST=${SPLUNK_FORWARDER_HOST:-"localhost"}
SPLUNK_FORWARDER_PORT=${SPLUNK_FORWARDER_PORT:-"9997"}

echo "Configuration:"
echo "  Forwarding to: ${SPLUNK_FORWARDER_HOST}:${SPLUNK_FORWARDER_PORT}"

# Generate outputs.conf from template with environment variables
echo "Generating outputs.conf from template..."
sed -e "s/SPLUNK_FORWARDER_HOST/${SPLUNK_FORWARDER_HOST}/g" \
    -e "s/SPLUNK_FORWARDER_PORT/${SPLUNK_FORWARDER_PORT}/g" \
    /opt/splunkforwarder/etc/system/local/outputs.conf.template > \
    /opt/splunkforwarder/etc/system/local/outputs.conf

echo "outputs.conf generated:"
cat /opt/splunkforwarder/etc/system/local/outputs.conf

# Start Splunk Universal Forwarder
echo "Starting Splunk Universal Forwarder..."
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt

# Wait for Splunk to be ready
echo "Waiting for Splunk to be ready..."
sleep 5

# Check Splunk status
echo "Splunk status:"
/opt/splunkforwarder/bin/splunk status

echo "================================================"
echo "Starting Python Application..."
echo "================================================"

# Start the Python application
python3 /app/app.py &
APP_PID=$!

echo "Application started with PID: $APP_PID"
echo "================================================"
echo "System is ready. Logs are being forwarded to:"
echo "  ${SPLUNK_FORWARDER_HOST}:${SPLUNK_FORWARDER_PORT}"
echo "================================================"

# Function to handle shutdown
shutdown() {
    echo ""
    echo "Shutting down..."
    echo "Stopping Python application..."
    kill -TERM $APP_PID 2>/dev/null || true
    echo "Stopping Splunk Universal Forwarder..."
    /opt/splunkforwarder/bin/splunk stop
    echo "Shutdown complete."
    exit 0
}

# Trap signals
trap shutdown SIGTERM SIGINT

# Wait for the application process
wait $APP_PID

