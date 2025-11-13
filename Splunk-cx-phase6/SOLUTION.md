# Phase 6 Solution: Fix EC2 OTEL to Receive K8s TCP Logs

## Problem
- ✅ K8s Splunk UF is running and configured
- ✅ EC2 port 9997 is listening
- ❌ No logs appearing as "k8s-phase6-tcp"
- ❌ Only seeing old Phase 5 logs

**Root Cause:** EC2 OTEL config doesn't have the `tcplog` receiver configured.

---

## Solution: 3 Options

### Option 1: Automated Script (EASIEST) ⭐

Copy and run the fix script on EC2:

```bash
# On your local machine
scp Splunk-cx-phase6/fix-ec2-otel.sh ec2-user@YOUR_OTEL_IP:/tmp/

# SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# Run the fix script
sudo bash /tmp/fix-ec2-otel.sh
```

**The script will:**
1. ✅ Find your OTEL process
2. ✅ Find your OTEL config file
3. ✅ Check if tcplog is configured
4. ✅ Backup your current config
5. ✅ Install the tcplog config
6. ✅ Restart OTEL
7. ✅ Verify port is listening

---

### Option 2: Manual Config Update

**Step 1: Find OTEL config**
```bash
# SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# Find OTEL process
ps aux | grep otelcol

# Find config file
cat /proc/$(pgrep otelcol)/cmdline | tr '\0' '\n' | grep config
```

**Step 2: Backup current config**
```bash
sudo cp /etc/otelcol-contrib/config.yaml /etc/otelcol-contrib/config.yaml.backup
```

**Step 3: Update config**
```bash
sudo nano /etc/otelcol-contrib/config.yaml
```

Replace or merge with this config:

```yaml
receivers:
  tcplog:
    listen_address: "0.0.0.0:9997"
    max_log_size: 1MiB

processors:
  batch:
    timeout: 10s
    send_batch_size: 100
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
      - key: phase
        value: "6-k8s-tcp"
        action: upsert
  attributes:
    actions:
      - key: collector
        value: ec2-otel-tcplog
        action: insert

exporters:
  splunk_hec/logs:
    token: "YOUR_SPLUNK_HEC_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
    source: "k8s-phase6-tcp"
    sourcetype: "python:phase6:k8s"
    index: "main"
    tls:
      insecure_skip_verify: true
  
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_PRIVATE_KEY"
    application_name: "k8s-phase6-tcp"
    subsystem_name: "kubernetes-central"
    timeout: 30s
  
  debug:
    verbosity: detailed

service:
  pipelines:
    logs:
      receivers: [tcplog]
      processors: [batch, resource, attributes]
      exporters: [splunk_hec/logs, coralogix, debug]
  telemetry:
    logs:
      level: info
```

**Step 4: Restart OTEL**

Find how OTEL is running and restart it:

```bash
# If it's a systemd service
sudo systemctl restart otel-collector
# OR
sudo systemctl restart otelcol-contrib

# If it's a direct process, send reload signal
sudo kill -HUP $(pgrep otelcol)

# Or kill and restart
sudo kill $(pgrep otelcol)
sudo /usr/local/bin/otelcol-contrib --config=/etc/otelcol-contrib/config.yaml &
```

**Step 5: Verify**
```bash
# Check port is listening
sudo netstat -tlnp | grep 9997

# Check for connections
sudo lsof -i :9997
```

---

### Option 3: Copy Config File Directly

**From local machine:**
```bash
# Copy the pre-made config to EC2
scp Splunk-cx-phase6/ec2-otel-tcplog-config.yaml ec2-user@YOUR_OTEL_IP:/tmp/

# SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# Backup and replace
sudo cp /etc/otelcol-contrib/config.yaml /etc/otelcol-contrib/config.yaml.backup
sudo cp /tmp/ec2-otel-tcplog-config.yaml /etc/otelcol-contrib/config.yaml

# Restart OTEL (see Step 4 above)
```

---

## Verification

After updating the config and restarting OTEL:

### 1. Check Port is Listening
```bash
sudo netstat -tlnp | grep 9997
```
**Expected:** `tcp6  0  0 :::9997  :::*  LISTEN  <PID>/otelcol-contr`

### 2. Check for K8s Connections
```bash
sudo lsof -i :9997
```
**Expected:** See connection from `172.31.5.184` (K8s pod IP)

**Example output:**
```
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
otelcol-c 23976 root    8u  IPv6  12345      0t0  TCP *:9997 (LISTEN)
otelcol-c 23976 root   12u  IPv6  12346      0t0  TCP ip-172-31-25-140:9997->172.31.5.184:45678 (ESTABLISHED)
```

### 3. Check Coralogix (within 2-3 minutes)
Search for:
```
application.name:"k8s-phase6-tcp"
```

**Expected:** See logs with:
- Application: `k8s-phase6-tcp`
- Subsystem: `kubernetes-central`
- RequestID, Method, Endpoint fields

### 4. Check Splunk (within 2-3 minutes)
Search for:
```
index=main sourcetype="python:phase6:k8s"
```

**Expected:** See logs with sourcetype `python:phase6:k8s`

---

## Troubleshooting

### No Logs After 5 Minutes

**Check OTEL logs:**
```bash
# Find log location
ps aux | grep otelcol

# Common locations
tail -f /var/log/otel/*.log
tail -f /var/log/syslog | grep otelcol
journalctl -xe | grep otel
```

**Look for:**
- ❌ Errors parsing TCP data → `tcplog` might not support Splunk's protocol
- ❌ Connection errors → Network/firewall issue
- ❌ Export errors → Splunk/Coralogix credentials wrong

### Still No Connections from K8s

**Test connectivity from K8s pod:**
```bash
# On local machine
POD_NAME=$(kubectl get pod -l app=splunk-phase6-official -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD_NAME -c splunk-forwarder -- sh -c "
  timeout 5 nc -zv YOUR_OTEL_IP 9997 2>&1 || 
  echo 'Connection failed - check EC2 security group'
"
```

**If connection fails:**
1. Check EC2 security group allows port 9997 from K8s
2. Check K8s network policies
3. Verify EC2 IP is correct

### tcplog Cannot Parse Splunk's TCP Protocol

This is a known limitation. If OTEL receives data but can't parse it correctly:

**Solution: Use Phase 4 with HEC instead!**
- Phase 4 uses standard HTTP (HEC) protocol
- OTEL fully supports HEC
- Already proven to work
- See: `../Splunk-cx-phase4/`

---

## Summary

**Quick Fix:**
1. Run `fix-ec2-otel.sh` on EC2
2. Wait 2-3 minutes
3. Check Coralogix and Splunk for `k8s-phase6-tcp` logs

**If tcplog doesn't work:** Switch to Phase 4 (HEC) - it's more reliable! ✅

