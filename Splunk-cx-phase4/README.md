# Phase 4 - Splunk Universal Forwarder with HEC to OTEL

## Goal
Use Splunk Universal Forwarder to read logs from a file and send via HEC to a central OTEL Collector, which forwards to both Splunk Cloud and Coralogix.

## Architecture
```
Python App → File → Splunk UF → OTEL Collector → ├─→ Splunk Cloud
                       (HEC)      (receives HEC)   └─→ Coralogix
```

## Use Case
- Customer already uses Splunk Universal Forwarder
- Want to leverage existing Splunk infrastructure
- Need central routing to multiple destinations
- **Customer only changes UF endpoint** (not application code)

## Prerequisites
- Docker and Docker Compose installed (for local testing)
- OR: x86_64 Linux/Windows server for production
- Splunk Universal Forwarder (included in Docker images)
- OTEL Collector (Phase 3) running on EC2/remote server

## Important Note
⚠️ **Splunk Universal Forwarder requires x86_64 architecture**. On ARM Macs, the Docker image will build but won't run. Deploy to:
- x86_64 Linux servers
- Windows servers
- Kubernetes (x86_64 nodes)
- AWS EC2 (x86_64 instances)

## Option 1: Running with Docker Compose (x86_64 Linux)

### Step 1: Navigate to directory
```bash
cd Splunk-cx-phase4
```

### Step 2: Configure the OTEL endpoint
Edit `outputs-hec-ec2.conf` or set via script:
```bash
# Point to your OTEL Collector
./configure-ec2.sh YOUR_OTEL_IP:8088
```

### Step 3: Start all services
```bash
docker compose -f docker-compose.yaml up -d
```

This starts:
- Python app (writing logs to file)
- Splunk Universal Forwarder (reading file, sending HEC to OTEL)
- OTEL Collector (forwarding to Splunk and Coralogix)

### Step 4: Verify logs
```bash
# Check containers
docker compose ps

# View Splunk UF logs
docker compose logs -f splunk-forwarder

# In Splunk Cloud, search for:
index=main sourcetype=python:phase4:production

# In Coralogix, search for:
application.name:"MyApp-Phase4"
```

### Step 5: Stop and clean up
```bash
docker compose down
```

## Option 2: Deploying to Kubernetes

### Step 1: Push images to ECR
```bash
cd Splunk-cx-phase4

# Configure AWS CLI
aws configure

# Run push script
./push-to-ecr.sh
```

### Step 2: Create Kubernetes deployment
```bash
# Apply the deployment
kubectl apply -f k8s/deployment.yaml

# Check pods
kubectl get pods -n default

# View logs
kubectl logs -f deployment/splunk-phase4-app -c splunk-forwarder
```

### Step 3: Verify logs in destinations
```bash
# In Splunk:
index=main sourcetype=python:phase4:production

# In Coralogix:
application.name:"MyApp-Phase4"
```

## Configuration Files

### outputs-hec-ec2.conf
```ini
[splunk_hec://hec_output]
uri = http://YOUR_OTEL_IP:8088/services/collector
token = YOUR_HEC_TOKEN
index = main
sourcetype = python:phase4:production
source = phase4-uf-production
```

### inputs.conf
```ini
[monitor:///var/log/myapp/application.log]
disabled = false
sourcetype = python:phase4:production
index = main
```

## Key Features
✅ Uses industry-standard Splunk Universal Forwarder
✅ File-based log collection (reliable)
✅ **Customer only changes UF outputs.conf** (endpoint)
✅ Central OTEL routing to multiple destinations
✅ Production-ready architecture

## Customer Migration Path

### Current Setup:
```ini
[tcpout]
defaultGroup = splunk_cloud
[tcpout:splunk_cloud]
server = splunk-cloud.com:9997
```

### New Setup (Phase 4):
```ini
[splunk_hec://hec_output]
uri = http://YOUR_OTEL_IP:8088/services/collector
token = YOUR_HEC_TOKEN
```

**That's it!** Logs now go to both Splunk and Coralogix automatically.

## Files
- `app_phase4.py` - Application writing logs
- `Dockerfile.app` - Application container
- `Dockerfile.splunk` - Splunk UF container (x86_64)
- `inputs.conf` - Splunk UF input configuration
- `outputs-hec-ec2.conf` - Splunk UF output configuration
- `docker-compose.yaml` - Local orchestration
- `push-to-ecr.sh` - Script to push images to AWS ECR
- `k8s/deployment.yaml` - Kubernetes deployment

## Troubleshooting

### Splunk UF not starting on Mac?
- Splunk UF requires x86_64 architecture
- Deploy to Linux x86_64 server or Kubernetes instead

### Logs not reaching OTEL?
- Check network connectivity: `telnet YOUR_OTEL_IP 8088`
- Verify OTEL Collector is running and listening on port 8088
- Check Security Group rules (if on AWS)

### Logs not in Splunk/Coralogix?
- Check OTEL Collector logs for errors
- Verify tokens and endpoints in OTEL configuration
