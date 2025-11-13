# Deploy tcplog Config to EC2 OTEL

## Problem

You're seeing Phase 5 data (`myapp-phase5-tcp`) but NOT Phase 6 data (`k8s-phase6-tcp`).

**Root Cause:** Your EC2 OTEL is still using the old configuration, not the `tcplog` receiver config.

---

## Solution: Update EC2 OTEL Configuration

### Step 1: Check Current OTEL Config Location

```bash
# SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# Find config file location
sudo systemctl cat otel-collector | grep ExecStart
```

**Typical locations:**
- `/etc/otelcol-contrib/config.yaml`
- `/opt/otel/config.yaml`
- `/home/ec2-user/otel-config.yaml`

### Step 2: Backup Current Config

```bash
# Backup existing config
sudo cp /etc/otelcol-contrib/config.yaml /etc/otelcol-contrib/config.yaml.backup
```

### Step 3: Deploy tcplog Config

**Option A: Copy from local machine**

From your local machine:
```bash
scp Splunk-cx-phase6/ec2-otel-tcplog-config.yaml ec2-user@YOUR_OTEL_IP:/tmp/
```

Then on EC2:
```bash
sudo cp /tmp/ec2-otel-tcplog-config.yaml /etc/otelcol-contrib/config.yaml
```

**Option B: Create directly on EC2**

```bash
sudo nano /etc/otelcol-contrib/config.yaml
```

Paste this config:

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
    sampling_initial: 10
    sampling_thereafter: 100

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

### Step 4: Restart OTEL Collector

```bash
sudo systemctl restart otel-collector
```

### Step 5: Verify tcplog is Running

```bash
# Check service status
sudo systemctl status otel-collector

# Check port 9997 is listening
sudo netstat -tlnp | grep 9997
# Should show: tcp  0  0 0.0.0.0:9997  0.0.0.0:*  LISTEN  <PID>/otel-collector

# Watch logs for connections
sudo journalctl -u otel-collector -f
```

**Look for:**
- ✅ "Starting stanza receiver" or "tcplog"
- ✅ No errors about port binding
- ✅ Connections from `172.31.5.184` (K8s pod IP)

---

## Step 6: Verify Logs Appear

### In Coralogix

Search for:
```
application.name:"k8s-phase6-tcp"
```

Should see logs with:
- Application: `k8s-phase6-tcp`
- Subsystem: `kubernetes-central`
- RequestID fields from your app

### In Splunk

Search for:
```
index=main sourcetype="python:phase6:k8s"
```

or

```
index=main source="k8s-phase6-tcp"
```

Should see logs with sourcetype `python:phase6:k8s`.

---

## If Still Not Working

### Check EC2 Security Group

Port 9997 must be open for TCP from your K8s cluster:

```bash
# Get instance security group
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' \
  --output table
```

Check if port 9997 is open:
```bash
aws ec2 describe-security-groups --group-ids <YOUR_SG_ID> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`9997`]'
```

If not open, add rule:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <YOUR_SG_ID> \
  --protocol tcp \
  --port 9997 \
  --cidr 0.0.0.0/0
```

### Test Connectivity from K8s Pod

```bash
# Get pod name
POD_NAME=$(kubectl get pod -l app=splunk-phase6-official -o jsonpath='{.items[0].metadata.name}')

# Test connection to EC2
kubectl exec $POD_NAME -c app -- sh -c "timeout 5 nc -zv YOUR_OTEL_IP 9997 2>&1 || echo 'Connection failed'"
```

---

## Important: What About Phase 5?

**Don't worry!** You can run both Phase 5 and Phase 6 simultaneously:

- **Phase 5:** File-based, OTEL reads from file → Coralogix
- **Phase 6:** TCP-based, OTEL receives TCP → Splunk + Coralogix

Just make sure your EC2 OTEL config includes **both** receivers:

```yaml
receivers:
  filelog:      # For Phase 5
    include: [/path/to/phase5/logs]
  tcplog:       # For Phase 6
    listen_address: "0.0.0.0:9997"
```

Or run separate OTEL instances for each phase.

---

## Quick Commands Summary

```bash
# 1. SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# 2. Backup current config
sudo cp /etc/otelcol-contrib/config.yaml /etc/otelcol-contrib/config.yaml.backup

# 3. Update config (choose method above)

# 4. Restart OTEL
sudo systemctl restart otel-collector

# 5. Check port
sudo netstat -tlnp | grep 9997

# 6. Watch logs
sudo journalctl -u otel-collector -f

# 7. Look for K8s pod IP
sudo journalctl -u otel-collector --since "5 minutes ago" | grep 172.31.5.184
```

---

## Expected Timeline

After deploying the config:
1. **Immediate:** Port 9997 should be listening
2. **Within 1 minute:** Splunk UF should connect from K8s
3. **Within 2 minutes:** Logs should appear in Coralogix and Splunk

If after 5 minutes you still see nothing → Check OTEL logs for errors!

