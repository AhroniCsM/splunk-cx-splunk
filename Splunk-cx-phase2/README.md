# Phase 2 - Dual Destination (File-Based)

## Goal
Send the **same logs** to both Splunk Cloud (via HEC) and Coralogix (via OpenTelemetry) from a single application.

## Architecture
```
Python App → File → ├─→ Python HEC Script → Splunk Cloud
                    └─→ OTEL Collector → Coralogix
```

## Use Case
- Need logs in both Splunk and Coralogix
- Want identical logs in both destinations (same RequestIDs)
- File-based approach for reliable log shipping

## Prerequisites
- Docker and Docker Compose installed
- Splunk Cloud HEC token and endpoint
- Coralogix domain and private key

## Configuration

Create a `.env` file or export environment variables:

```bash
# Splunk Configuration
export SPLUNK_HEC_TOKEN="your-hec-token"
export SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088"

# Coralogix Configuration
export CORALOGIX_DOMAIN="eu2.coralogix.com"  # or your region
export CORALOGIX_PRIVATE_KEY="your-coralogix-key"

# Application Configuration
export LOG_INTERVAL_SECONDS="30"
```

## Running with Docker Compose

### Step 1: Navigate to the directory
```bash
cd Splunk-cx-phase2
```

### Step 2: Start all services
```bash
docker compose up -d
```

This starts:
- Python app (writing logs to file)
- Python HEC shipper (reading file, sending to Splunk)
- OTEL Collector (reading file, sending to Coralogix)

### Step 3: Verify logs
```bash
# Check all containers
docker compose ps

# View logs from each service
docker compose logs -f python-app
docker compose logs -f splunk-shipper
docker compose logs -f otel-collector

# In Splunk, search for:
index=main sourcetype=python:phase2

# In Coralogix, search for:
application.name:"MyApp-Phase2"
```

### Step 4: Verify logs match
Pick a RequestID from Coralogix and search for it in Splunk - they should match exactly!

### Step 5: Stop and clean up
```bash
docker compose down
docker compose down -v  # Remove volumes as well
```

## Key Features
✅ Same logs to both destinations
✅ Independent shippers (if one fails, other continues)
✅ File-based reliability
✅ OTEL for modern observability stack
✅ Easy to add more destinations

## Files
- `docker-compose.yaml` - Orchestration configuration
- `app_hec.py` - Application writing logs
- `otel-collector-config.yaml` - OTEL configuration for Coralogix
- `Dockerfile.hec` - Application container

## Architecture Details
1. Python app writes logs to `/var/log/myapp/application.log`
2. Python HEC script reads the file and sends to Splunk
3. OTEL Collector reads the same file and sends to Coralogix
4. All services share a Docker volume for the log file

## Notes
- Both shippers read from the same file
- Logs are guaranteed to be identical in both destinations
- If one shipper fails, the other continues working
