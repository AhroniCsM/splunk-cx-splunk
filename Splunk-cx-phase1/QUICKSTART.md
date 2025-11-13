# Phase 1: Quick Start - Direct HEC to Splunk

## What This Does
Sends logs directly from your Python application to Splunk Cloud using HEC (HTTP Event Collector).

## Prerequisites
- Docker installed
- Splunk Cloud HEC token
- Splunk Cloud endpoint

## Files in This Phase
- `app_hec.py` - Python application that sends logs via HEC
- `Dockerfile.hec` - Docker image definition
- `run-hec.sh` - Helper script (optional)

## Quick Start (3 Steps)

### Step 1: Set Your Credentials
```bash
export SPLUNK_HEC_TOKEN="your-hec-token-here"
export SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088/services/collector"
```

### Step 2: Build the Docker Image
```bash
docker build -f Dockerfile.hec -t phase1-app .
```

### Step 3: Run the Container
```bash
docker run -d \
  --name phase1-app \
  -e SPLUNK_HEC_TOKEN="${SPLUNK_HEC_TOKEN}" \
  -e SPLUNK_HEC_URL="${SPLUNK_HEC_URL}" \
  -e LOG_INTERVAL_SECONDS=30 \
  phase1-app
```

## View Logs
```bash
# View container logs
docker logs -f phase1-app

# Check if logs are reaching Splunk
# Go to Splunk Cloud and search: index=main sourcetype="python:phase1"
```

## Stop and Clean Up
```bash
docker stop phase1-app
docker rm phase1-app
```

## Configuration

### Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `SPLUNK_HEC_TOKEN` | Your Splunk HEC token | `12345678-1234-1234-1234-123456789012` |
| `SPLUNK_HEC_URL` | Your Splunk HEC endpoint | `https://inputs.example.splunkcloud.com:8088/services/collector` |
| `LOG_INTERVAL_SECONDS` | Seconds between log generation | `30` (default) |

### Splunk Search
Once running, find your logs in Splunk:
```
index=main sourcetype="python:phase1"
```

## Troubleshooting

**Logs not appearing in Splunk?**
1. Verify HEC is enabled in Splunk Cloud
2. Check token is valid
3. Ensure endpoint URL is correct (include `/services/collector`)
4. Check container logs: `docker logs phase1-app`

**SSL Certificate errors?**
- The app uses `verify=False` for SSL. For production, configure proper certificates.

