# Quick Start Guide - Phase 1

## Overview
This Phase 1 setup includes a Python application with Splunk Universal Forwarder that can send logs to any endpoint (OTEL collector in Phase 2).

## Files Created

```
Splunk-cx/
├── app.py                    # Python app that generates logs
├── Dockerfile               # Container with Splunk UF + Python app
├── entrypoint.sh           # Startup script
├── inputs.conf             # Splunk input config (what to monitor)
├── outputs.conf.template   # Splunk output config (where to send)
├── build.sh                # Helper script to build image
├── run.sh                  # Helper script to run container
├── README.md               # Full documentation
└── QUICKSTART.md           # This file
```

## Step 1: Build the Docker Image

```bash
cd Splunk-cx
./build.sh
```

Or manually:
```bash
docker build -t splunk-forwarder-app:latest .
```

**Note:** First build takes ~5 minutes (downloads Splunk UF)

## Step 2: Run the Container

### Option A: Using the helper script

Edit `run.sh` to set your endpoint:
```bash
export OTEL_HOST="your-otel-endpoint.com"
export OTEL_PORT="9997"
./run.sh
```

### Option B: Direct Docker command

```bash
docker run -d \
  --name splunk-forwarder \
  -e SPLUNK_FORWARDER_HOST=<your-endpoint> \
  -e SPLUNK_FORWARDER_PORT=9997 \
  splunk-forwarder-app:latest
```

### For EKS OTEL Collector (Example)

```bash
docker run -d \
  --name splunk-forwarder \
  -e SPLUNK_FORWARDER_HOST=otel-collector.default.svc.cluster.local \
  -e SPLUNK_FORWARDER_PORT=9997 \
  splunk-forwarder-app:latest
```

## Step 3: Verify It's Working

```bash
# Check container is running
docker ps | grep splunk-forwarder

# View logs
docker logs -f splunk-forwarder

# View application logs
docker exec -it splunk-forwarder tail -f /var/log/myapp/application.log

# Check Splunk forwarder status
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

## What's Happening?

1. **Python App** generates random logs (INFO, WARNING, ERROR)
2. Logs are written to `/var/log/myapp/application.log`
3. **Splunk Universal Forwarder** monitors this file
4. Logs are forwarded via TCP to your configured endpoint
5. In Phase 2, OTEL will receive these logs

## Stopping and Cleaning Up

```bash
docker stop splunk-forwarder
docker rm splunk-forwarder
```

## Troubleshooting

### Container exits immediately?
```bash
docker logs splunk-forwarder
```

### Can't connect to endpoint?
```bash
docker exec -it splunk-forwarder ping <your-endpoint>
```

### Splunk not running?
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

## Next: Phase 2

Once this is working:
1. Set up OTEL Collector in your EKS cluster
2. Configure OTEL with Splunk receiver (port 9997)
3. Configure OTEL exporters to send to Splunk AND Coralogix
4. Update this container to point to OTEL endpoint

---

**Phase 1 Complete!** ✅

Ready to proceed to Phase 2 when you provide the OTEL endpoint details.

