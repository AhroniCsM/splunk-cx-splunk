#!/bin/bash
# Debug script for Phase 6 OTEL on EC2
# Run this on EC2 to diagnose why logs aren't appearing

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Phase 6 Debug - OTEL tcplog Receiver                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== 1. Checking OTEL Process ==="
OTEL_PID=$(pgrep otelcol)
if [ -n "$OTEL_PID" ]; then
    echo -e "${GREEN}✅ OTEL is running (PID: $OTEL_PID)${NC}"
    ps -fp $OTEL_PID
else
    echo -e "${RED}❌ OTEL is not running!${NC}"
    exit 1
fi
echo ""

echo "=== 2. Checking Port 9997 ==="
if netstat -tlnp 2>/dev/null | grep -q 9997; then
    echo -e "${GREEN}✅ Port 9997 is listening${NC}"
    netstat -tlnp | grep 9997
else
    echo -e "${RED}❌ Port 9997 is NOT listening!${NC}"
fi
echo ""

echo "=== 3. Checking for K8s Connections ==="
CONNECTIONS=$(lsof -i :9997 2>/dev/null | grep ESTABLISHED || echo "")
if [ -n "$CONNECTIONS" ]; then
    echo -e "${GREEN}✅ Active connection found:${NC}"
    lsof -i :9997
else
    echo -e "${YELLOW}⚠️  No ESTABLISHED connections (Splunk UF may not be connected)${NC}"
    echo "All connections on port 9997:"
    lsof -i :9997 2>/dev/null || echo "None"
fi
echo ""

echo "=== 4. Checking OTEL Config ==="
CONFIG_FILE=$(cat /proc/$OTEL_PID/cmdline 2>/dev/null | tr '\0' '\n' | grep "config" | sed 's/--config=//' | grep -v "^--" || echo "/etc/otelcol-contrib/config.yaml")
echo "Config file: $CONFIG_FILE"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✅ Config file exists${NC}"
    echo ""
    echo "tcplog receiver configuration:"
    grep -A 5 "tcplog:" "$CONFIG_FILE" || echo -e "${RED}❌ No tcplog receiver found!${NC}"
else
    echo -e "${RED}❌ Config file not found!${NC}"
fi
echo ""

echo "=== 5. Checking if TCP Data is Being Received ==="
echo "Capturing 10 seconds of TCP traffic on port 9997..."
echo "(Looking for data from K8s pod 172.31.5.184)"
timeout 10 tcpdump -i any port 9997 -c 20 -nn 2>/dev/null | tee /tmp/tcpdump.log || echo "tcpdump not available or no traffic"
echo ""

if grep -q "172.31.5" /tmp/tcpdump.log 2>/dev/null; then
    echo -e "${GREEN}✅ TCP packets detected from K8s pod!${NC}"
else
    echo -e "${YELLOW}⚠️  No TCP packets from K8s pod detected${NC}"
fi
echo ""

echo "=== 6. Finding OTEL Logs ==="
# Try to find where OTEL is logging
echo "Searching for OTEL log files..."
OTEL_LOGS=$(find /var/log -name "*otel*" -type f 2>/dev/null)
if [ -n "$OTEL_LOGS" ]; then
    echo -e "${GREEN}✅ Found OTEL log files:${NC}"
    echo "$OTEL_LOGS"
    echo ""
    echo "Last 30 lines of OTEL logs:"
    tail -30 $(echo "$OTEL_LOGS" | head -1)
else
    echo -e "${YELLOW}⚠️  No OTEL log files found in /var/log${NC}"
    echo ""
    echo "Checking system logs for OTEL messages:"
    journalctl --since "10 minutes ago" 2>/dev/null | grep -i otel | tail -20 || echo "No journalctl logs"
fi
echo ""

echo "=== 7. Checking OTEL Process Output ==="
echo "If OTEL is running in foreground/screen/tmux, check that terminal"
echo "Process command line:"
cat /proc/$OTEL_PID/cmdline 2>/dev/null | tr '\0' ' '
echo ""
echo ""

echo "=== 8. Testing OTEL Exporters ==="
echo "Checking if Splunk endpoint is reachable:"
timeout 5 curl -k -s -o /dev/null -w "%{http_code}" https://your-instance.splunkcloud.com:8088/services/collector/health || echo "Cannot reach Splunk"
echo ""

echo "Checking if Coralogix endpoint is reachable:"
timeout 5 curl -s -o /dev/null -w "%{http_code}" https://api.eu2.coralogix.com || echo "Cannot reach Coralogix"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Debug Summary                                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Summary
if [ -n "$OTEL_PID" ]; then
    echo -e "${GREEN}✅ OTEL is running${NC}"
else
    echo -e "${RED}❌ OTEL is not running${NC}"
fi

if netstat -tlnp 2>/dev/null | grep -q 9997; then
    echo -e "${GREEN}✅ Port 9997 is listening${NC}"
else
    echo -e "${RED}❌ Port 9997 is NOT listening${NC}"
fi

if [ -n "$CONNECTIONS" ]; then
    echo -e "${GREEN}✅ K8s pod is connected${NC}"
else
    echo -e "${YELLOW}⚠️  No active connection from K8s pod${NC}"
fi

if grep -q "172.31.5" /tmp/tcpdump.log 2>/dev/null; then
    echo -e "${GREEN}✅ TCP data is being received${NC}"
else
    echo -e "${YELLOW}⚠️  No TCP data detected${NC}"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Analysis                                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if grep -q "172.31.5" /tmp/tcpdump.log 2>/dev/null; then
    echo -e "${YELLOW}LIKELY ISSUE:${NC}"
    echo "TCP data IS being received, but tcplog receiver CANNOT parse it."
    echo ""
    echo "Why: tcplog is designed for plain-text TCP syslog."
    echo "     Splunk UF uses a proprietary binary TCP protocol."
    echo "     OTEL tcplog doesn't understand this protocol."
    echo ""
    echo -e "${GREEN}SOLUTION: Use Phase 4 with HEC (HTTP) instead of TCP!${NC}"
    echo "Phase 4 uses standard HTTP (HEC) which OTEL fully supports."
    echo ""
else
    echo -e "${YELLOW}POSSIBLE ISSUES:${NC}"
    echo "1. K8s Splunk UF is not sending to EC2"
    echo "2. Network/firewall blocking connection"
    echo "3. Splunk UF not configured correctly"
    echo ""
    echo "Check K8s pod logs: kubectl logs -l app=splunk-phase6-official -c splunk-forwarder"
fi

echo ""
echo "Copy this entire output and send it for analysis."
echo ""

# Cleanup
rm -f /tmp/tcpdump.log

