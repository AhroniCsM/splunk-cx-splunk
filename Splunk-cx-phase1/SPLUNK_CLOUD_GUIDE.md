# Sending Logs to Splunk Cloud

## Overview

Your `splunkclouduf.spl` file contains the credentials to connect to **Splunk Cloud**:
- **Endpoint**: `your-instance.splunkcloud.com:9997`
- **SSL Certificates**: Included for secure connection
- **Authentication**: SSL password encrypted

## Quick Start

### Option 1: Using Helper Scripts (Recommended)

```bash
# Step 1: Build the image (takes 5-10 minutes)
./build-splunkcloud.sh

# Step 2: Run the container
./run-splunkcloud.sh
```

### Option 2: Manual Commands

```bash
# Build
docker build --platform=linux/amd64 \
  -f Dockerfile.splunkcloud \
  -t splunk-forwarder-app:splunkcloud .

# Run
docker run -d \
  --name splunk-forwarder \
  splunk-forwarder-app:splunkcloud
```

## What Happens

```
┌─────────────────────────────────────┐
│     Docker Container                │
│                                     │
│  ┌──────────────────┐              │
│  │  Python App      │              │
│  │  (generates logs)│              │
│  └────────┬─────────┘              │
│           │                         │
│           ▼                         │
│  /var/log/myapp/application.log    │
│           │                         │
│           ▼                         │
│  ┌────────────────────────────────┐│
│  │ Splunk Universal Forwarder     ││
│  │ + Your Splunk Cloud Creds      ││
│  └──────────────┬─────────────────┘│
└─────────────────┼───────────────────┘
                  │ SSL/TLS
                  │ (Port 9997)
                  ▼
    ┌──────────────────────────────┐
    │  Splunk Cloud                │
    │  inputs.prd-p-vl1fl          │
    │  .splunkcloud.com            │
    └──────────────────────────────┘
```

## Monitoring

### View Container Logs
```bash
docker logs -f splunk-forwarder
```

### View Application Logs
```bash
docker exec -it splunk-forwarder tail -f /var/log/myapp/application.log
```

### Check Splunk Forwarder Status
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

### List Forward Servers
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk list forward-server
```

### Check Connection to Splunk Cloud
```bash
# View internal Splunk logs
docker exec -it splunk-forwarder tail -f /opt/splunkforwarder/var/log/splunk/splunkd.log
```

## Verification in Splunk Cloud

1. Log in to your Splunk Cloud instance
2. Go to **Search & Reporting**
3. Run this search:
   ```spl
   index=main sourcetype="python:app"
   | head 100
   ```

4. You should see logs like:
   ```
   2025-11-12 20:29:36 - MyApp - INFO - INFO: Session created - RequestID: 9817
   2025-11-12 20:29:31 - MyApp - WARNING - WARNING: High memory usage detected - 89%
   2025-11-12 20:29:25 - MyApp - ERROR - ERROR: Connection timeout - User: user51
   ```

## Configuration Files

The container uses:

1. **splunkclouduf.spl** - Your Splunk Cloud credentials package
   - Contains SSL certificates
   - Contains outputs.conf with endpoint configuration
   - Contains SSL password

2. **inputs.conf** - What logs to monitor
   ```ini
   [monitor:///var/log/myapp/application.log]
   disabled = false
   index = main
   sourcetype = python:app
   ```

## Troubleshooting

### Check if Splunk is Running
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

### Check Splunk Logs for Errors
```bash
docker exec -it splunk-forwarder tail -100 /opt/splunkforwarder/var/log/splunk/splunkd.log
```

### Verify SSL Connection
```bash
docker exec -it splunk-forwarder cat /opt/splunkforwarder/etc/apps/100_prd-p-vl1fl_splunkcloud/default/outputs.conf
```

### Restart Splunk Forwarder
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk restart
```

### Container Won't Start
Check Docker logs:
```bash
docker logs splunk-forwarder
```

Common issues:
- Download timeout (retry build)
- Platform mismatch (make sure `--platform=linux/amd64` is used)
- Port conflicts (change port mapping if needed)

## Customization

### Change Index
Edit `inputs.conf`:
```ini
[monitor:///var/log/myapp/application.log]
index = your_custom_index  # Change this
```

### Change Sourcetype
Edit `inputs.conf`:
```ini
[monitor:///var/log/myapp/application.log]
sourcetype = your_custom_sourcetype  # Change this
```

### Monitor Additional Logs
Add to `inputs.conf`:
```ini
[monitor:///var/log/other/*.log]
disabled = false
index = main
sourcetype = other:logs
```

## Stopping and Cleaning Up

```bash
# Stop the container
docker stop splunk-forwarder

# Remove the container
docker rm splunk-forwarder

# Remove the image (if needed)
docker rmi splunk-forwarder-app:splunkcloud

# Remove extracted config (optional)
rm -rf splunk_config_extracted
```

## Next: Phase 2 with OTEL

Once this is working and sending logs to Splunk Cloud, we can add OTEL in the middle:

```
App → OTEL Collector → Both: Splunk Cloud + Coralogix
```

This allows you to:
- Keep sending to Splunk Cloud
- Also send to Coralogix (or other platforms)
- Transform/filter logs in OTEL
- Add additional metadata

