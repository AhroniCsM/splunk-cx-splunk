#!/bin/bash
set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-splunk-forwarder-hec}"
LOG_INTERVAL="${LOG_INTERVAL_SECONDS:-30}"
SPLUNK_HEC_TOKEN="${SPLUNK_HEC_TOKEN:-}"
SPLUNK_HEC_URL="${SPLUNK_HEC_URL:-https://your-instance.splunkcloud.com:8088/services/collector/event}"
SPLUNK_INDEX="${SPLUNK_INDEX:-main}"
SPLUNK_SOURCETYPE="${SPLUNK_SOURCETYPE:-python:app}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      Starting Splunk HEC Forwarder Container                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if HEC token is provided
if [ -z "$SPLUNK_HEC_TOKEN" ]; then
    echo "❌ ERROR: SPLUNK_HEC_TOKEN is required!"
    echo ""
    echo "Usage:"
    echo "  SPLUNK_HEC_TOKEN=<your-token> ./run-hec.sh"
    echo ""
    echo "Or:"
    echo "  export SPLUNK_HEC_TOKEN=<your-token>"
    echo "  ./run-hec.sh"
    echo ""
    echo "To get your HEC token:"
    echo "  1. Log in to Splunk Cloud: https://prd-p-vl1fl.splunkcloud.com"
    echo "  2. Go to Settings > Data Inputs > HTTP Event Collector"
    echo "  3. Click 'New Token' or use existing token"
    echo ""
    exit 1
fi

echo "Configuration:"
echo "  Container Name: ${CONTAINER_NAME}"
echo "  HEC URL:        ${SPLUNK_HEC_URL}"
echo "  Index:          ${SPLUNK_INDEX}"
echo "  Sourcetype:     ${SPLUNK_SOURCETYPE}"
echo "  Log Interval:   ${LOG_INTERVAL} seconds"
echo "  HEC Token:      ${SPLUNK_HEC_TOKEN:0:10}... (hidden)"
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
  -e LOG_INTERVAL_SECONDS=${LOG_INTERVAL} \
  -e SPLUNK_HEC_TOKEN=${SPLUNK_HEC_TOKEN} \
  -e SPLUNK_HEC_URL=${SPLUNK_HEC_URL} \
  -e SPLUNK_INDEX=${SPLUNK_INDEX} \
  -e SPLUNK_SOURCETYPE=${SPLUNK_SOURCETYPE} \
  splunk-forwarder-app:hec

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               ✅ Container Started!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Useful commands:"
echo "  View logs:           docker logs -f ${CONTAINER_NAME}"
echo "  View app logs:       docker exec -it ${CONTAINER_NAME} tail -f /var/log/myapp/application.log"
echo "  Stop container:      docker stop ${CONTAINER_NAME}"
echo "  Remove container:    docker rm ${CONTAINER_NAME}"
echo ""
echo "Showing initial logs (Ctrl+C to exit):"
echo "════════════════════════════════════════════════════════════════"
sleep 3
docker logs -f ${CONTAINER_NAME}

