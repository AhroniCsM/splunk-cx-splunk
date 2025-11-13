#!/bin/bash
set -e

# Configuration - MODIFY THESE VALUES
OTEL_HOST="${OTEL_HOST:-localhost}"
OTEL_PORT="${OTEL_PORT:-9997}"
CONTAINER_NAME="${CONTAINER_NAME:-splunk-forwarder}"

echo "================================================"
echo "Starting Splunk Forwarder Container"
echo "================================================"
echo "Configuration:"
echo "  Container Name: ${CONTAINER_NAME}"
echo "  Forwarding to:  ${OTEL_HOST}:${OTEL_PORT}"
echo "================================================"
echo ""

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '${CONTAINER_NAME}' already exists."
    read -p "Do you want to remove it and start fresh? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and removing existing container..."
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
    else
        echo "Exiting without changes."
        exit 0
    fi
fi

# Run the container
echo "Starting container..."
docker run -d \
  --name ${CONTAINER_NAME} \
  -e SPLUNK_FORWARDER_HOST=${OTEL_HOST} \
  -e SPLUNK_FORWARDER_PORT=${OTEL_PORT} \
  splunk-forwarder-app:latest

echo ""
echo "✅ Container started successfully!"
echo ""
echo "Useful commands:"
echo "  View logs:           docker logs -f ${CONTAINER_NAME}"
echo "  View app logs:       docker exec -it ${CONTAINER_NAME} tail -f /var/log/myapp/application.log"
echo "  Check status:        docker exec -it ${CONTAINER_NAME} /opt/splunkforwarder/bin/splunk status"
echo "  Stop container:      docker stop ${CONTAINER_NAME}"
echo "  Remove container:    docker rm ${CONTAINER_NAME}"
echo ""
echo "Showing initial logs (Ctrl+C to exit):"
echo "================================================"
sleep 2
docker logs -f ${CONTAINER_NAME}

