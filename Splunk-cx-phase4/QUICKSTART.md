# Phase 4: Quick Start - Splunk UF via HEC

## What This Does
Uses Splunk Universal Forwarder to read logs from file and send via HEC to OTEL Collector, which forwards to both Splunk and Coralogix.

## Prerequisites
- Docker and Docker Compose installed
- Splunk Cloud HEC token
- Coralogix private key
- **x86_64 architecture** (Splunk UF doesn't run on ARM)

## Files in This Phase
- `app_phase4.py` - App writes logs to file only
- `Dockerfile.app` - App container
- `Dockerfile.splunk` - Splunk Universal Forwarder container
- `docker-compose.yaml` - Orchestrates all 3 containers
- `inputs.conf` - Splunk UF monitors the log file
- `outputs-hec.conf` - Splunk UF sends HEC to OTEL
- `otel-collector-config.yaml` - OTEL forwards to both destinations

## Quick Start (2 Steps)

### Step 1: Edit `docker-compose.yaml`
Replace these placeholders:

```yaml
SPLUNK_HEC_TOKEN: YOUR_SPLUNK_HEC_TOKEN          # Replace
SPLUNK_HEC_URL: YOUR_SPLUNK_HEC_URL              # Replace
CORALOGIX_PRIVATE_KEY: YOUR_CORALOGIX_PRIVATE_KEY # Replace
CORALOGIX_DOMAIN: eu2.coralogix.com               # Your region
```

### Step 2: Run Everything
```bash
docker-compose up -d
```

## How It Works
```
Python App → File → Splunk UF → HEC → OTEL → Splunk Cloud
                                             └→ Coralogix
```

## Verify It's Working

### Check Containers
```bash
docker-compose ps
```
You should see 3 containers:
- `python-app-phase4` - Writes logs
- `splunk-uf-phase4` - Reads and forwards logs
- `otel-collector-phase4` - Routes to both destinations

### View Logs
```bash
# Application logs
docker-compose logs -f python-app

# Splunk UF logs
docker-compose logs -f splunk-forwarder

# OTEL Collector logs
docker-compose logs -f otel-collector
```

### Check Splunk
```
index=main sourcetype="python:phase4"
```

### Check Coralogix
- Application: `MyApp-Phase4`
- Subsystem: `Docker`

## Customer Migration

### For customers using Splunk Universal Forwarder:

**Change only `outputs.conf`:**

**OLD (direct to Splunk):**
```ini
[tcpout]
server = inputs.example.splunkcloud.com:9997
```

**NEW (to OTEL):**
```ini
[splunk_hec://hec_output]
uri = http://YOUR_OTEL_IP:8088/services/collector
token = your-token
index = main
sourcetype = your-sourcetype
```

That's it! Everything else stays the same.

## Important Notes

### Architecture Requirement
Splunk Universal Forwarder requires **x86_64** (Intel/AMD) architecture:
- ✅ Works on: x86_64 Linux, Windows, most cloud VMs
- ❌ Won't work on: ARM Macs (M1/M2/M3), ARM servers

For local testing on ARM Mac:
- Build images with `--platform linux/amd64`
- Images will build but UF won't execute
- Deploy to x86_64 for actual testing

### Splunk HEC Token
Same as Phase 3: **Disable "Indexer Acknowledgment"** in Splunk HEC token settings.

## Stop and Clean Up
```bash
docker-compose down
```

## Troubleshooting

**Splunk UF not starting?**
- Check architecture: `docker-compose logs splunk-forwarder`
- If on ARM Mac, deploy to x86_64 machine instead

**Logs not flowing?**
- Check if UF is reading file: `docker-compose exec splunk-forwarder ls -la /var/log/myapp/`
- Check UF internal logs: `docker-compose exec splunk-forwarder tail -f /opt/splunkforwarder/var/log/splunk/splunkd.log`

**Want to send TCP instead of HEC?**
- See Phase 5 (independent paths) or Phase 6 (RAW TCP to OTEL)

