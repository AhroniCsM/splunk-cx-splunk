#!/bin/bash
set -e

echo "Building Splunk Forwarder Application Docker Image..."
echo "This may take a few minutes as it downloads Splunk Universal Forwarder..."
echo ""

docker build -t splunk-forwarder-app:latest .

echo ""
echo "✅ Build complete!"
echo ""
echo "To run the container, use:"
echo "  docker run -d \\"
echo "    --name splunk-forwarder \\"
echo "    -e SPLUNK_FORWARDER_HOST=<your-endpoint> \\"
echo "    -e SPLUNK_FORWARDER_PORT=<your-port> \\"
echo "    splunk-forwarder-app:latest"
echo ""
echo "Or use the run.sh script with your endpoints configured."

