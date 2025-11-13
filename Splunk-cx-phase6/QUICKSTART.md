# Phase 6: Quick Start - Splunk UF RAW TCP ⭐

## What This Does
Uses Splunk Universal Forwarder with **RAW TCP mode** to send to OTEL Collector, which forwards to BOTH Splunk and Coralogix.

**The Key:** `sendCookedData=false` makes Splunk UF send plain text that OTEL can parse!

## Prerequisites
- Docker and Docker Compose (for local testing)
- OR Kubernetes cluster (for production)
- Splunk Cloud HEC token
- Coralogix private key
- **x86_64 architecture**

## Files in This Phase
- `app_phase6.py` - App writes logs to file
- `Dockerfile.app` - App container
- `Dockerfile.splunk` - Splunk UF with RAW TCP config
- `docker-compose.yaml` - Local testing setup
- `inputs.conf` - Splunk UF monitors the file
- `outputs-raw-tcp.conf` - **sendCookedData=false** (the magic!)
- `otel-collector-config.yaml` - OTEL tcplog receiver
- `k8s/deployment.yaml` - Kubernetes production deployment

---

## Option 1: Local Testing with Docker Compose

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

### How It Works (Local)
```
Python App → File → Splunk UF → RAW TCP (9997) → OTEL → Splunk Cloud
                                                        └→ Coralogix
```

### Verify
```bash
# Check containers
docker-compose ps

# View logs
docker-compose logs -f

# Check Splunk: index=main sourcetype="python:phase6"
# Check Coralogix: Application="MyApp-Phase6-TCP"
```

### Stop
```bash
docker-compose down
```

---

## Option 2: Deploy to Kubernetes (Production) ⭐

### Step 1: Edit `k8s/deployment.yaml`
Update the ConfigMap with your OTEL Collector details:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: splunk-uf-config-raw-final
data:
  default.yml: |
    splunk:
      conf:
        - key: outputs
          value:
            content:
              tcpout:ec2_otel_tcp_raw:
                server: YOUR_OTEL_IP:9997  # ← Replace with your OTEL IP
                sendCookedData: false       # ← This is the magic!
```

Also update the OTEL Collector environment variables (if running OTEL in the same cluster, or use external OTEL).

### Step 2: Create a Namespace (Optional)
```bash
kubectl create namespace splunk-phase6
```

### Step 3: Deploy to Kubernetes
```bash
kubectl apply -f k8s/deployment.yaml
```

Or with custom namespace:
```bash
kubectl apply -f k8s/deployment.yaml -n splunk-phase6
```

### Step 4: Verify Deployment
```bash
# Check pods
kubectl get pods

# Check logs
kubectl logs -f deployment/splunk-phase6-official-raw-final -c app
kubectl logs -f deployment/splunk-phase6-official-raw-final -c splunk-forwarder

# Describe pod (if issues)
kubectl describe pod <pod-name>
```

### Architecture in Kubernetes
```
┌─────────────────────────────────────────┐
│  Kubernetes Pod                          │
│  ┌──────────┐        ┌───────────────┐  │
│  │   App    │─file──→│  Splunk UF    │  │
│  │Container │        │  (Official    │  │
│  └──────────┘        │   Image)      │  │
│                      └───────┬───────┘  │
└──────────────────────────────┼──────────┘
                               │ RAW TCP
                               │ (9997)
                               ↓
                    ┌──────────────────┐
                    │  OTEL Collector  │──→ Splunk Cloud
                    │  (On EC2 or K8s) │──→ Coralogix
                    └──────────────────┘
```

### K8s Configuration Explained

The deployment uses the **official Splunk Universal Forwarder image** (`splunk/universalforwarder:latest`) with configuration via `default.yml` ConfigMap:

**Key Configuration:**
```yaml
sendCookedData: false  # Makes Splunk UF send plain text (not binary)
```

This allows OTEL's `tcplog` receiver to parse the logs!

### Stop and Clean Up
```bash
kubectl delete -f k8s/deployment.yaml
```

---

## Customer Migration

### For customers using Splunk Universal Forwarder:

**Change ONE setting in `outputs.conf`:**

**OLD (binary protocol to Splunk):**
```ini
[tcpout]
server = inputs.example.splunkcloud.com:9997
```

**NEW (plain text to OTEL):**
```ini
[tcpout]
server = YOUR_OTEL_IP:9997
sendCookedData = false  # ← ADD THIS LINE!
```

That's it! OTEL then forwards to both Splunk AND Coralogix.

---

## OTEL Collector Configuration

Your OTEL Collector needs the `tcplog` receiver:

```yaml
receivers:
  tcplog:
    listen_address: "0.0.0.0:9997"
    max_log_size: 1MiB

exporters:
  splunk_hec/logs:
    token: "your-token"
    endpoint: "https://inputs.example.splunkcloud.com:8088"
    # ... rest of config
  
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "your-key"
    # ... rest of config

service:
  pipelines:
    logs:
      receivers: [tcplog]
      exporters: [splunk_hec/logs, coralogix]
```

---

## Troubleshooting

### Docker Compose Issues

**Splunk UF not starting?**
- Check architecture: must be x86_64
- View logs: `docker-compose logs splunk-forwarder`

**Logs not reaching OTEL?**
- Check OTEL logs: `docker-compose logs otel-collector`
- Verify port 9997 is accessible

### Kubernetes Issues

**Pod pending?**
- Check nodes: `kubectl get nodes`
- Ensure you have x86_64 nodes available
- Check node selector in deployment

**Pod CrashLoopBackOff?**
- Check logs: `kubectl logs <pod-name> -c splunk-forwarder`
- Verify ConfigMap is correct: `kubectl get configmap splunk-uf-config-raw-final -o yaml`

**Logs not flowing?**
- Verify OTEL Collector is reachable from K8s cluster
- Check network policies/firewall rules
- Ensure OTEL is listening on port 9997

**Seeing Splunk internal logs instead of app logs?**
- The deployment filters them out with index-based filtering
- Only `main` index logs (your app) should flow

---

## Why This Phase is Recommended ⭐

✅ **Customer Familiar** - Uses Splunk Universal Forwarder (industry standard)
✅ **Minimal Change** - Only add `sendCookedData=false`
✅ **Central Routing** - OTEL forwards to multiple destinations
✅ **TCP Protocol** - Native protocol, not HTTP
✅ **Production Ready** - K8s deployment included

## Comparison with Other Phases

| Feature | Phase 4 (HEC) | Phase 5 (Dual Path) | Phase 6 (RAW TCP) |
|---------|---------------|---------------------|-------------------|
| Protocol | HTTP (HEC) | TCP + File | TCP (RAW) |
| Central Routing | ✅ Yes | ❌ No | ✅ Yes |
| Customer Change | outputs.conf | outputs.conf | outputs.conf + 1 line |
| Splunk Familiar | ⚠️ HEC | ✅ TCP | ✅ TCP |
| K8s Ready | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Additional Resources

- See `README.md` for detailed architecture
- See main repository README for comparison of all phases

