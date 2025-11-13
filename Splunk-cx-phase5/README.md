# Phase 5 - Dual Path (Splunk TCP + OTEL File)

## Goal
Send logs to Splunk Cloud via native TCP (Splunk Universal Forwarder) AND to Coralogix via OTEL Collector reading the same file.

## Architecture
```
              ┌─→ Splunk UF (TCP:9997) → Splunk Cloud
Python App → File →
              └─→ OTEL Collector (filelog) → Coralogix
```

## Use Case
- Customer must use Splunk's native TCP protocol (port 9997)
- Also need logs in Coralogix
- Independent paths: if one fails, the other continues
- Splunk connection uses their standard, tested protocol

## Prerequisites
- Docker and Docker Compose installed (for local dev)
- OR: x86_64 Linux server for production
- Splunk Cloud TCP input configured (port 9997)
- Coralogix domain and private key

## Important Notes
⚠️ **Splunk Universal Forwarder**:
- Requires x86_64 architecture
- Won't run on ARM Macs (build works, execution fails)
- Deploy to x86_64 Linux, Windows, or Kubernetes

⚠️ **Splunk Cloud TCP**:
- Some Splunk Cloud instances may not allow TCP inputs
- Verify with your Splunk administrator
- Alternative: Use Phase 4 (HEC) or Phase 6 (TCP to OTEL)

## Running with Docker Compose (x86_64 Linux)

### Step 1: Configure Splunk Cloud TCP
Edit `outputs.conf`:
```ini
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = YOUR_INSTANCE.splunkcloud.com:9997
```

### Step 2: Configure Coralogix
Edit `otel-collector-config.yaml` or set environment variables:
```yaml
coralogix:
  domain: "eu2.coralogix.com"  # Your region
  private_key: "your-coralogix-key"
```

### Step 3: Start all services
```bash
cd Splunk-cx-phase5
docker compose up -d
```

This starts:
- Python app (writing to file)
- Splunk UF (reading file, sending TCP to Splunk Cloud)
- OTEL Collector (reading same file, sending to Coralogix)

### Step 4: Verify logs
```bash
# Check services
docker compose ps

# View logs
docker compose logs -f python-app
docker compose logs -f splunk-forwarder
docker compose logs -f otel-collector

# In Splunk Cloud:
index=main sourcetype=python:phase5

# In Coralogix:
application.name:"MyApp-Phase5-TCP"
```

### Step 5: Stop and clean up
```bash
docker compose down
docker compose down -v  # Remove volumes
```

## Deploying to Production (Kubernetes)

### Step 1: Push images to ECR
```bash
cd Splunk-cx-phase5
./push-to-ecr.sh
```

### Step 2: Deploy to Kubernetes
```bash
kubectl apply -f k8s/deployment.yaml

# Check status
kubectl get pods -n default -l app=splunk-phase5

# View logs
kubectl logs -f deployment/splunk-phase5-app -c splunk-forwarder
kubectl logs -f deployment/splunk-phase5-app -c otel-collector
```

## Configuration Files

### outputs.conf (Splunk UF → Splunk Cloud)
```ini
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = inputs.splunkcloud.com:9997
```

### otel-collector-config.yaml (OTEL → Coralogix)
```yaml
receivers:
  filelog:
    include: [/var/log/myapp/application.log]

exporters:
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "your-key"
    application_name: "MyApp-Phase5-TCP"
    subsystem_name: "Docker"
```

## Key Features
✅ **Dual independent paths** (if one fails, other continues)
✅ Splunk native TCP protocol (standard, tested)
✅ OTEL for modern observability (Coralogix)
✅ File-based reliability
✅ No cross-dependencies

## Comparison with Other Phases

| Feature | Phase 4 | Phase 5 | Phase 6 |
|---------|---------|---------|---------|
| Splunk Protocol | HEC | TCP | TCP (RAW) |
| OTEL Receives | HEC | - | TCP (RAW) |
| OTEL Reads | - | File | - |
| Customer Change | Endpoint | Endpoint | Endpoint |
| Independent Paths | No | **Yes** | No |

## Use This Phase When:
- ✅ Splunk Cloud allows TCP (port 9997)
- ✅ You want independent paths to each destination
- ✅ One path failing shouldn't affect the other
- ✅ You're using Splunk's standard TCP protocol

## Don't Use This Phase When:
- ❌ Splunk Cloud blocks TCP port 9997
- ❌ You want centralized routing (use Phase 3 or 6)
- ❌ You need all logs going through OTEL (use Phase 6)

## Files
- `app_phase5.py` - Application
- `Dockerfile.app` - Application container
- `Dockerfile.splunk` - Splunk UF container (x86_64)
- `inputs.conf` - Splunk UF input configuration
- `outputs.conf` - Splunk UF output (TCP to Splunk Cloud)
- `otel-collector-config.yaml` - OTEL reading file to Coralogix
- `docker-compose.yaml` - Local orchestration
- `push-to-ecr.sh` - Push to AWS ECR
- `k8s/deployment.yaml` - Kubernetes deployment

## Troubleshooting

### Splunk UF not running?
- Check if on x86_64 architecture (not ARM)
- Verify Splunk Cloud accepts TCP on port 9997
- Check outputs.conf server address

### Logs not in Coralogix?
- Check OTEL Collector logs
- Verify Coralogix key and domain
- Ensure file exists and has read permissions
