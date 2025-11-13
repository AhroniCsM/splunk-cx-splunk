# Phase 1 - Direct HEC Integration

## Goal
Send logs directly from a Python application to Splunk Cloud using HTTP Event Collector (HEC).

## Architecture
```
Python App → Splunk HEC (HTTPS) → Splunk Cloud
```

## Use Case
- Simple integration when you can modify the application
- Direct connection to Splunk without additional infrastructure
- Best for testing and small-scale deployments

## Prerequisites
- Docker installed
- Splunk Cloud HEC token
- Splunk Cloud HEC endpoint

## Configuration

Edit the environment variables in the script or export them:

```bash
export SPLUNK_HEC_TOKEN="your-hec-token-here"
export SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088"
export LOG_INTERVAL_SECONDS="30"  # Generate logs every 30 seconds
```

## Running Locally

### Step 1: Build the Docker image
```bash
cd Splunk-cx
docker build -f Dockerfile.hec -t splunk-phase1-app:latest .
```

### Step 2: Run the container
```bash
docker run -d \
  --name splunk-phase1 \
  -e SPLUNK_HEC_TOKEN="your-hec-token-here" \
  -e SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088" \
  -e LOG_INTERVAL_SECONDS="30" \
  splunk-phase1-app:latest
```

### Step 3: Verify logs are flowing
```bash
# Check container logs
docker logs -f splunk-phase1

# In Splunk, search for:
index=main sourcetype=python:hec
```

### Step 4: Stop and clean up
```bash
docker stop splunk-phase1
docker rm splunk-phase1
```

## Key Features
✅ Direct HEC integration
✅ SSL/TLS encryption
✅ Simple configuration
✅ No additional infrastructure needed
✅ Configurable log generation rate (to manage Splunk volume limits)

## Files
- `app_hec.py` - Python application sending logs via HEC
- `Dockerfile.hec` - Docker configuration
- `requirements.txt` - Python dependencies

## Notes
- Logs are sent every 30 seconds by default (configurable)
- Uses channel-based HEC for Splunk Cloud compatibility
- SSL certificate verification disabled for self-signed certificates
