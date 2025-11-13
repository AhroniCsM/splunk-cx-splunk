# Phase 3 - Central OTEL Collector (HEC to OTEL)

## Goal
Application sends logs to a central OpenTelemetry Collector, which forwards to **both** Splunk Cloud and Coralogix in parallel.

## Architecture
```
Python App → OTEL Collector → ├─→ Splunk Cloud (HEC)
       (HEC)    (receives HEC)  └─→ Coralogix (native)
```

## Use Case
- **Minimal customer application changes** (only endpoint change)
- Central log routing and processing
- Add/remove destinations without touching the application
- Perfect for migrating from Splunk-only to multi-destination

## Prerequisites
- Docker and Docker Compose installed (for local testing)
- OR: Standalone OTEL Collector on EC2/VM
- Splunk Cloud HEC token and endpoint
- Coralogix domain and private key

## Key Benefit
**Customer only needs to change the HEC endpoint** from Splunk Cloud to your OTEL Collector!

## Option 1: Running Locally (Testing)

### Step 1: Start the OTEL Collector
```bash
cd Splunk-cx-phase3
docker compose up -d
```

This starts the OTEL Collector listening on `http://localhost:8088` (HEC endpoint).

### Step 2: Configure your application
Change your application's Splunk HEC endpoint to point to the OTEL Collector:

```python
# Before:
SPLUNK_HEC_URL = "https://your-instance.splunkcloud.com:8088"

# After:
SPLUNK_HEC_URL = "http://localhost:8088"  # Or your OTEL collector IP
```

### Step 3: Verify logs flow to both destinations
```bash
# Check OTEL logs
docker compose logs -f otel-collector

# In Splunk, search for:
index=main sourcetype=python:phase3

# In Coralogix, search for:
application.name:"MyApp-Phase3"
```

### Step 4: Stop when done
```bash
docker compose down
```

## Option 2: Running on EC2/Remote Server

### Step 1: Install OTEL Collector on EC2
```bash
# Download OTEL Contrib Collector
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.91.0/otelcol-contrib_0.91.0_linux_amd64.tar.gz
tar -xzf otelcol-contrib_0.91.0_linux_amd64.tar.gz

# Copy configuration
sudo mkdir -p /etc/otelcol-contrib
sudo cp otel-collector-config.yaml /etc/otelcol-contrib/config.yaml
```

### Step 2: Configure environment variables
```bash
sudo nano /etc/otelcol-contrib/config.yaml

# Update:
# - SPLUNK_HEC_TOKEN
# - SPLUNK_HEC_URL
# - CORALOGIX_PRIVATE_KEY
# - CORALOGIX_DOMAIN
```

### Step 3: Create systemd service
```bash
sudo tee /etc/systemd/system/otelcol-contrib.service > /dev/null <<EOF
[Unit]
Description=OpenTelemetry Collector
After=network.target

[Service]
ExecStart=/usr/local/bin/otelcol-contrib --config=/etc/otelcol-contrib/config.yaml
Restart=always
User=otelcol-contrib

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable otelcol-contrib
sudo systemctl start otelcol-contrib
```

### Step 4: Open firewall port
```bash
# Allow HEC port
sudo ufw allow 8088/tcp

# Or in AWS Security Group: Allow TCP 8088 from your application IPs
```

### Step 5: Update customer application
Customer changes **only one line**:
```python
SPLUNK_HEC_URL = "http://YOUR_EC2_IP:8088"
```

## Key Features
✅ **Minimal customer changes** (only endpoint!)
✅ Central routing - add/remove destinations easily
✅ Logs go to both Splunk and Coralogix automatically
✅ Can run locally or on remote server
✅ No code changes needed

## Important Notes

### Splunk HEC Configuration
⚠️ **Important**: Disable "Indexer Acknowledgment" in your Splunk HEC token settings!

The OTEL `splunk_hec` exporter doesn't support the `X-Splunk-Request-Channel` header required by Splunk Cloud when acknowledgment is enabled.

To disable:
1. Go to Splunk Cloud Settings → Data Inputs → HTTP Event Collector
2. Edit your HEC token
3. Uncheck "Enable indexer acknowledgment"
4. Save

## Files
- `otel-collector-config.yaml` - OTEL configuration
- `docker-compose.yaml` - For local testing

## Troubleshooting

### Logs not appearing in Splunk?
- Check if "Indexer Acknowledgment" is disabled
- Verify HEC token is correct
- Check OTEL logs: `docker compose logs otel-collector`

### Logs not appearing in Coralogix?
- Verify private key and domain are correct
- Check OTEL logs for connection errors
