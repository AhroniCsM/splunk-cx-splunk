# Phase 5: Quick Start - Independent Dual Paths

## What This Does
Sends logs via TWO independent paths:
- **Splunk Universal Forwarder** → Native TCP (port 9997) → Splunk Cloud
- **OTEL Collector** → Reads same file → Coralogix

## Prerequisites
- Docker and Docker Compose installed
- Splunk Cloud with TCP input enabled (port 9997)
- Coralogix private key
- **x86_64 architecture** (for Splunk UF)

## Files in This Phase
- `app_phase5.py` - App writes logs to file
- `Dockerfile.app` - App container
- `Dockerfile.splunk` - Splunk UF container (sends TCP)
- `docker-compose.yaml` - Orchestrates all 3 containers
- `inputs.conf` - Splunk UF monitors the file
- `outputs.conf` - Splunk UF sends TCP to Splunk Cloud
- `otel-collector-config.yaml` - OTEL reads file and sends to Coralogix

## Quick Start (2 Steps)

### Step 1: Edit Configuration Files

**Edit `outputs.conf`** - Set your Splunk Cloud TCP endpoint:
```ini
[tcpout:default-autolb-group]
server = your-instance.splunkcloud.com:9997  # Replace this
```

**Edit `docker-compose.yaml`** - Set Coralogix credentials:
```yaml
CORALOGIX_PRIVATE_KEY: YOUR_CORALOGIX_PRIVATE_KEY  # Replace
CORALOGIX_DOMAIN: eu2.coralogix.com                 # Your region
```

### Step 2: Run Everything
```bash
docker-compose up -d
```

## How It Works
```
                    ┌→ Splunk UF → TCP (9997) → Splunk Cloud
Python App → File ──┤
                    └→ OTEL Collector → Coralogix

Independent paths (if one fails, the other continues)
```

## Verify It's Working

### Check Containers
```bash
docker-compose ps
```
Should show 3 containers:
- `python-app-phase5`
- `splunk-uf-phase5-tcp`
- `otel-collector-phase5`

### View Logs
```bash
# Application
docker-compose logs -f python-app

# Splunk UF
docker-compose logs -f splunk-forwarder

# OTEL
docker-compose logs -f otel-collector
```

### Check Splunk
```
index=main sourcetype="python:phase5"
```

### Check Coralogix
- Application: `MyApp-Phase5`
- Subsystem: `Docker`

## Important Notes

### Splunk Cloud TCP Input
You need TCP input enabled in Splunk Cloud:
1. Go to Settings → Data Inputs → TCP
2. Enable port 9997
3. Note: Some Splunk Cloud plans may not allow TCP inputs

**Can't enable TCP?** Use Phase 4 (HEC to OTEL) instead.

### Architecture
Splunk UF requires x86_64:
- ✅ Works: x86_64 Linux, Windows, cloud VMs
- ❌ Won't work: ARM Macs, ARM servers

## Advantages of This Phase

✅ **Independent Paths** - If one destination is down, the other continues
✅ **Native Protocol** - Uses Splunk's native TCP (not HEC)
✅ **No Single Point of Failure** - No central routing

## Stop and Clean Up
```bash
docker-compose down
```

## Troubleshooting

**Splunk UF not connecting?**
- Verify TCP input is enabled in Splunk Cloud (port 9997)
- Check if port 9997 is accessible
- Review UF logs: `docker-compose logs splunk-forwarder`

**Logs only in Splunk, not Coralogix?**
- Check OTEL logs: `docker-compose logs otel-collector`
- Verify Coralogix key and domain

**Need central routing instead?**
- Use Phase 6 (Splunk UF RAW TCP to OTEL) for central routing with TCP

