#!/bin/bash
set -e

CONTAINER_NAME="${CONTAINER_NAME:-splunk-forwarder}"
# Control log generation rate (seconds between logs)
# 30 = ~2,880 logs/day (~0.5 MB/day)
# 60 = ~1,440 logs/day (~0.25 MB/day)
# 120 = ~720 logs/day (~0.12 MB/day)
LOG_INTERVAL="${LOG_INTERVAL_SECONDS:-30}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      Starting Splunk Cloud Forwarder Container                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Container Name: ${CONTAINER_NAME}"
echo "Target: Splunk Cloud (your-instance.splunkcloud.com:9997)"
echo "Log Interval: ${LOG_INTERVAL} seconds between logs"
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
  splunk-forwarder-app:splunkcloud

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               ✅ Container Started!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Useful commands:"
echo "  View logs:           docker logs -f ${CONTAINER_NAME}"
echo "  View app logs:       docker exec -it ${CONTAINER_NAME} tail -f /var/log/myapp/application.log"
echo "  Check Splunk status: docker exec -it ${CONTAINER_NAME} /opt/splunkforwarder/bin/splunk status"
echo "  List forwarders:     docker exec -it ${CONTAINER_NAME} /opt/splunkforwarder/bin/splunk list forward-server"
echo "  Stop container:      docker stop ${CONTAINER_NAME}"
echo ""
echo "Showing initial logs (Ctrl+C to exit):"
echo "════════════════════════════════════════════════════════════════"
sleep 5
docker logs -f ${CONTAINER_NAME}

