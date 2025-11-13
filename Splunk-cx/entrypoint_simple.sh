#!/bin/bash
set -e

echo "================================================"
echo "Starting Simple Log Forwarder + Python App"
echo "================================================"

# Set default values if not provided
SPLUNK_FORWARDER_HOST=${SPLUNK_FORWARDER_HOST:-"localhost"}
SPLUNK_FORWARDER_PORT=${SPLUNK_FORWARDER_PORT:-"9997"}

echo "Configuration:"
echo "  Forwarding to: ${SPLUNK_FORWARDER_HOST}:${SPLUNK_FORWARDER_PORT}"
echo "  Note: Using simple netcat forwarder for testing"
echo "================================================"

# Start the log forwarder in background
/app/simple_forwarder.sh &
FORWARDER_PID=$!

echo "Log forwarder started with PID: $FORWARDER_PID"

# Start the Python application
echo "Starting Python Application..."
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
    echo "Stopping log forwarder..."
    kill -TERM $FORWARDER_PID 2>/dev/null || true
    echo "Shutdown complete."
    exit 0
}

# Trap signals
trap shutdown SIGTERM SIGINT

# Wait for the application process
wait $APP_PID

