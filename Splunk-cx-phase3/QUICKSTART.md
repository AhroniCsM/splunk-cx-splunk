# Phase 3: Quick Start - Central HEC Routing

## What This Does
Your app sends HEC to OTEL Collector, which forwards to BOTH Splunk and Coralogix.
**Customer only changes endpoint** - app code stays the same!

## Prerequisites
- Docker and Docker Compose installed
- Splunk Cloud HEC token (with Indexer Acknowledgment DISABLED)
- Coralogix private key

## Files in This Phase
- `app_hec.py` - Your application (unchanged from Phase 1)
- `Dockerfile.hec` - Docker image
- `docker-compose.yaml` - Orchestrates app + OTEL
- `otel-collector-config.yaml` - Central routing config

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
Python App → HEC (port 8088) → OTEL Collector → Splunk Cloud
                                               └→ Coralogix
```

The app thinks it's sending to Splunk, but OTEL intercepts and forwards to both!

## Verify It's Working

### Check Containers
```bash
docker-compose ps
```

### View Logs
```bash
# Application logs
docker-compose logs -f python-app

# OTEL Collector logs (see forwarding to both)
docker-compose logs -f otel-collector
```

### Check Splunk
```
index=main sourcetype="python:phase3"
```

### Check Coralogix
- Application: `MyApp-Phase3`
- Subsystem: `Docker`

## Customer Migration

### For customers migrating from Phase 1:
**OLD (Phase 1):**
```bash
SPLUNK_HEC_URL=https://inputs.example.splunkcloud.com:8088/services/collector
```

**NEW (Phase 3):**
```bash
SPLUNK_HEC_URL=http://YOUR_OTEL_IP:8088/services/collector
#                    ^^^^^^^^^ Just change the endpoint!
```

That's it! No code changes needed.

## Important: Splunk Cloud Setup

⚠️ **You MUST disable "Indexer Acknowledgment" in your Splunk HEC token settings:**

1. Go to Splunk Cloud → Settings → Data Inputs → HTTP Event Collector
2. Find your token
3. Click Edit
4. **UNCHECK "Enable indexer acknowledgment"**
5. Save

Why? OTEL's `splunk_hec` exporter doesn't support the `X-Splunk-Request-Channel` header required by Indexer Acknowledgment.

## Stop and Clean Up
```bash
docker-compose down
```

## Troubleshooting

**OTEL returning 400 Bad Request to Splunk?**
- Disable "Indexer Acknowledgment" in Splunk HEC token (see above)

**Logs not appearing in Coralogix?**
- Check OTEL logs: `docker-compose logs otel-collector`
- Verify Coralogix private key and domain

**Want to add more destinations?**
- Just edit `otel-collector-config.yaml` and add more exporters!
- App doesn't need to change

