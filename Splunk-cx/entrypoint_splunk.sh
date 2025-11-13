#!/bin/bash
set -e

echo "================================================"
echo "Starting Splunk Universal Forwarder + Python App"
echo "================================================"

# Display Splunk Cloud configuration
echo "Splunk Configuration:"
echo "  Using Splunk Cloud credentials package"
echo "  Endpoint: your-instance.splunkcloud.com:9997"
echo "  SSL: Enabled (with certificates)"
echo ""

# Start Splunk Universal Forwarder (first time will accept license)
echo "Starting Splunk Universal Forwarder..."
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme

# Wait for Splunk to be fully ready
echo "Waiting for Splunk to be ready..."
sleep 15

# Check Splunk status
echo "Splunk status:"
/opt/splunkforwarder/bin/splunk status

# Show which outputs are configured
echo ""
echo "Configured outputs:"
/opt/splunkforwarder/bin/splunk list forward-server

echo "================================================"
echo "Starting Python Application..."
echo "================================================"

# Start the Python application
python3 /app/app.py &
APP_PID=$!

echo "Application started with PID: $APP_PID"
echo "================================================"
echo "System is ready. Logs are being forwarded to:"
echo "  Splunk Cloud (your-instance.splunkcloud.com:9997)"
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

