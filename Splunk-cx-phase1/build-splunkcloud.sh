#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    Building Splunk Cloud Forwarder Application                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "This will:"
echo "  1. Download Splunk Universal Forwarder (~200MB)"
echo "  2. Install your Splunk Cloud credentials"
echo "  3. Configure log forwarding to Splunk Cloud"
echo ""
echo "⏱️  This may take 5-10 minutes on first build..."
echo ""

docker build \
  --platform=linux/amd64 \
  -f Dockerfile.splunkcloud \
  -t splunk-forwarder-app:splunkcloud \
  .

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               ✅ Build Complete!                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "To run the container:"
echo "  docker run -d --name splunk-forwarder splunk-forwarder-app:splunkcloud"
echo ""
echo "Or use: ./run-splunkcloud.sh"

