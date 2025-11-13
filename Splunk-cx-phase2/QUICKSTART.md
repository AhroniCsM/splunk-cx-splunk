# Phase 2: Quick Start - Dual Shipper (File-Based)

## What This Does
Sends the **same logs** to both Splunk Cloud AND Coralogix using separate shippers reading from a shared file.

## Prerequisites
- Docker and Docker Compose installed
- Splunk Cloud HEC token
- Coralogix private key

## Files in This Phase
- `app_hec.py` - Python application
- `Dockerfile.hec` - Docker image
- `docker-compose.yaml` - Orchestrates app + 2 shippers
- `otel-collector-config.yaml` - OTEL configuration for Coralogix

## Quick Start (2 Steps)

### Step 1: Edit `docker-compose.yaml`
Replace these placeholders with your credentials:

```yaml
SPLUNK_HEC_TOKEN: YOUR_SPLUNK_HEC_TOKEN          # Replace this
SPLUNK_HEC_URL: YOUR_SPLUNK_HEC_URL              # Replace this
CORALOGIX_PRIVATE_KEY: YOUR_CORALOGIX_PRIVATE_KEY # Replace this
```

### Step 2: Run Everything
```bash
docker-compose up -d
```

That's it! Logs are now flowing to both destinations.

## Verify It's Working

### Check Container Status
```bash
docker-compose ps
```
You should see 3 containers running:
- `python-app-phase2` - Generates logs
- `python-app-phase2-1` - (duplicate, can ignore)
- `otel-collector-phase2` - Sends to Coralogix

### View Logs
```bash
# Application logs
docker-compose logs -f python-app

# OTEL Collector logs (Coralogix shipper)
docker-compose logs -f otel-collector
```

### Check Splunk
Search in Splunk Cloud:
```
index=main sourcetype="python:phase2"
```

### Check Coralogix
In Coralogix, filter by:
- Application: `MyApp-Phase2`
- Subsystem: `Docker`

## Configuration

Edit `docker-compose.yaml`:

```yaml
environment:
  # Splunk Settings (for HEC shipper)
  - SPLUNK_HEC_TOKEN=your-token
  - SPLUNK_HEC_URL=https://your-instance.splunkcloud.com:8088/services/collector
  
  # Coralogix Settings (for OTEL)
  - CORALOGIX_PRIVATE_KEY=your-key
  - CORALOGIX_DOMAIN=eu2.coralogix.com  # or your region
  
  # Log Generation
  - LOG_INTERVAL_SECONDS=30
```

## Stop and Clean Up
```bash
docker-compose down
```

## Troubleshooting

**Logs only in Splunk, not Coralogix?**
- Check OTEL logs: `docker-compose logs otel-collector`
- Verify Coralogix key is correct
- Ensure domain matches your region (eu2, us1, etc.)

**Logs only in Coralogix, not Splunk?**
- Check app logs: `docker-compose logs python-app`
- Verify Splunk HEC token and URL

**Different RequestIDs in each destination?**
- This phase guarantees same logs (same RequestID) because both shippers read from the same file

