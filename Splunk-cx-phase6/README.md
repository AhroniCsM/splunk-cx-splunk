# Phase 6 - Splunk Universal Forwarder with RAW TCP to OTEL

## Goal
Use Splunk Universal Forwarder to send logs via **RAW TCP** (plain text) to a central OTEL Collector, which forwards to **both** Splunk Cloud and Coralogix.

## Architecture
```
Python App → File → Splunk UF → OTEL Collector → ├─→ Splunk Cloud (HEC)
                     (RAW TCP)   (tcplog:9997)    └─→ Coralogix (native)
```

## Use Case
- **Customer wants to use TCP protocol** (industry standard)
- Need central OTEL routing to multiple destinations
- **Customer only changes Splunk UF endpoint** (one line!)
- Perfect for customers familiar with Splunk architecture

## The Key Discovery: sendCookedData=false

By default, Splunk UF sends data in "cooked mode" (binary protocol) which only Splunk indexers understand. Setting `sendCookedData=false` makes Splunk UF send **plain text** that OTEL can parse!

## Prerequisites
- Kubernetes cluster OR x86_64 Linux server
- OTEL Collector running with `tcplog` receiver on port 9997
- Splunk Cloud HEC token and endpoint
- Coralogix domain and private key

## Important Architecture Note

⚠️ **Critical Configuration**: `sendCookedData=false`

```ini
# outputs.conf
[tcpout]
defaultGroup = otel_raw_tcp

[tcpout:otel_raw_tcp]
server = YOUR_OTEL_IP:9997
sendCookedData = false  ← This is ESSENTIAL!
```

**Why?**
- Default (cooked mode): Binary protocol only Splunk indexers understand
- RAW mode: Plain text that OTEL `tcplog` receiver can parse
- Without this setting, logs will be corrupted in OTEL!

## Deploying to Kubernetes

### Step 1: Configure OTEL Collector on EC2

Install and configure OTEL Collector with `tcplog` receiver:

```yaml
receivers:
  tcplog:
    listen_address: "0.0.0.0:9997"

exporters:
  splunk_hec/logs:
    token: "YOUR_SPLUNK_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_KEY"
    application_name: "k8s-phase6-tcp"

service:
  pipelines:
    logs:
      receivers: [tcplog]
      exporters: [splunk_hec/logs, coralogix]
```

### Step 2: Open firewall port on EC2
```bash
# AWS Security Group: Allow TCP 9997 from your K8s cluster
# Or with UFW:
sudo ufw allow 9997/tcp
```

### Step 3: Deploy to Kubernetes
```bash
cd Splunk-cx-phase6

# Apply the final configuration
kubectl apply -f k8s/deployment-official-raw-final.yaml

# Check pods
kubectl get pods -n default -l app=splunk-phase6-final

# View logs
kubectl logs -f deployment/splunk-phase6-official-raw-final -c splunk-forwarder
```

### Step 4: Verify logs in both destinations
```bash
# In Splunk Cloud:
index=main sourcetype=python:phase6:k8s

# In Coralogix:
application.name:"k8s-phase6-tcp"

# You should see your application logs like:
# "2025-11-13 22:10:24 - MyApp-Phase6-TCP - ERROR - RequestID: 15 | Method: GET..."
```

## Configuration Details

### Kubernetes Deployment (k8s/deployment-official-raw-final.yaml)

The configuration uses `default.yml` format for Splunk's official Docker image:

```yaml
splunk:
  conf:
    - key: outputs
      value:
        directory: /opt/splunkforwarder/etc/system/local
        content:
          tcpout:
            defaultGroup: ec2_otel_tcp_raw
            forwardedindex.filter.disable: true
            indexAndForward: false
          tcpout:ec2_otel_tcp_raw:
            server: YOUR_OTEL_IP:9997
            sendCookedData: false  # ← THE KEY SETTING!
            forwardedindex.0.whitelist: main
            forwardedindex.1.blacklist: _.*  # Block Splunk internals
    
    - key: inputs
      value:
        directory: /opt/splunkforwarder/etc/system/local
        content:
          monitor:///var/log/myapp/*.log:
            disabled: false
            sourcetype: python:phase6:k8s
            index: main
          monitor://$SPLUNK_HOME/var/log/splunk:
            disabled: true  # Block Splunk's own logs
          monitor://$SPLUNK_HOME/var/spool/splunk:
            disabled: true  # Block Splunk internal files
```

## Key Features
✅ **Splunk Universal Forwarder** (industry standard)
✅ **TCP protocol** (familiar to ops teams)
✅ **Central OTEL routing** (add destinations easily)
✅ **RAW mode** (plain text compatible with OTEL)
✅ **Customer only changes one line** (outputs.conf)
✅ **Filters out Splunk internal logs** (only app logs forwarded)

## What Makes Phase 6 Special

### Before Discovery (Didn't Work):
```ini
[tcpout:otel]
server = otel-collector:9997
# Default: sendCookedData=true (binary protocol)
# Result: Corrupted logs in OTEL ❌
```

### After Discovery (Works!):
```ini
[tcpout:otel]
server = otel-collector:9997
sendCookedData = false  # ← Plain text protocol
# Result: Clean logs in OTEL ✅
```

## Customer Migration Path

### Current Setup (Splunk-only):
```ini
[tcpout]
defaultGroup = splunk_cloud
[tcpout:splunk_cloud]
server = splunk-cloud.com:9997
```

### Phase 6 Setup (Splunk + Coralogix):
```ini
[tcpout]
defaultGroup = otel_tcp
[tcpout:otel_tcp]
server = YOUR_OTEL_IP:9997
sendCookedData = false
```

**That's it!** Logs now automatically go to both destinations!

## Comparison with Other Phases

| Feature | Phase 4 (HEC→OTEL) | Phase 5 (TCP+File) | Phase 6 (RAW TCP→OTEL) |
|---------|-------------------|-------------------|----------------------|
| Protocol to OTEL | HEC | - | TCP (RAW) |
| Customer Change | Endpoint (HEC) | Endpoint (TCP) | Endpoint (TCP) + sendCookedData |
| Splunk Familiarity | Medium | High | **Highest** |
| Central Routing | ✅ Yes | ❌ No | ✅ Yes |
| OTEL Compatibility | Native | N/A | **With RAW mode** |

## Use This Phase When:
- ✅ Customer is familiar with Splunk TCP architecture
- ✅ Want central OTEL routing to multiple destinations
- ✅ Comfortable with `sendCookedData=false` configuration
- ✅ Need logs going through OTEL for processing/enrichment

## Files
- `k8s/deployment-official-raw-final.yaml` - **Production-ready Kubernetes deployment**
- `app_phase6.py` - Application writing logs
- `inputs.conf` - Splunk UF input configuration (reference)
- `outputs-raw-tcp.conf` - Splunk UF output configuration (reference)
- `RAW_TCP_SOLUTION.md` - Detailed technical explanation

## Troubleshooting

### Logs still corrupted?
- Verify `sendCookedData=false` is in outputs.conf
- Check OTEL Collector has `tcplog` receiver on port 9997
- Restart Splunk UF after config changes

### Only seeing Splunk internal logs?
- Check that Splunk log directories are disabled in inputs.conf
- Verify index filtering with `forwardedindex.1.blacklist: _.*`
- Review the deployed ConfigMap

### No logs at all?
- Check network connectivity: `telnet YOUR_OTEL_IP 9997`
- Verify EC2 Security Group allows port 9997
- Check OTEL Collector logs: `journalctl -u otelcol-contrib -f`
- Verify pod is running: `kubectl get pods -l app=splunk-phase6-final`

## Technical Deep Dive

See `RAW_TCP_SOLUTION.md` for detailed explanation of:
- Why `sendCookedData=false` is needed
- Splunk "cooked mode" vs "raw mode"
- How OTEL `tcplog` receiver works
- Complete architecture diagrams

## Success Criteria

✅ Logs appear in **both** Splunk Cloud and Coralogix
✅ Logs are **clean** (not corrupted protocol headers)
✅ Same RequestIDs in both destinations
✅ **Only application logs** (no Splunk internals)

Example of successful log:
```
"2025-11-13 22:10:24 - MyApp-Phase6-TCP - ERROR - RequestID: 15 | Method: GET | Endpoint: /api/users | Status: 404 | ResponseTime: 180ms"
```
