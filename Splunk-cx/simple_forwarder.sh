#!/bin/bash
# Simple log forwarder using tail and netcat (for testing purposes)
# This simulates Splunk Universal Forwarder behavior

FORWARDER_HOST=${SPLUNK_FORWARDER_HOST:-localhost}
FORWARDER_PORT=${SPLUNK_FORWARDER_PORT:-9997}
LOG_FILE="/var/log/myapp/application.log"

echo "Simple log forwarder starting..."
echo "Forwarding logs from $LOG_FILE to ${FORWARDER_HOST}:${FORWARDER_PORT}"

# Wait for log file to be created
while [ ! -f "$LOG_FILE" ]; do
    echo "Waiting for log file to be created..."
    sleep 1
done

# Continuously tail and forward logs
tail -F "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
    echo "Forwarding: $line"
    # Try to send to endpoint (will fail if endpoint not available, but that's OK for testing)
    echo "$line" | nc -w 1 "$FORWARDER_HOST" "$FORWARDER_PORT" 2>/dev/null || true
done

