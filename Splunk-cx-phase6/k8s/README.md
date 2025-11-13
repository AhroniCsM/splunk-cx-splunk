# Phase 6 - Kubernetes Deployment

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                         │
│                  (default namespace)                        │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Pod: splunk-phase6-app                            │    │
│  │                                                     │    │
│  │  Container 1: Python App                           │    │
│  │  • Writes to /var/log/myapp/application.log        │    │
│  │  • Shared volume                                   │    │
│  │                                                     │    │
│  │  Container 2: Splunk Universal Forwarder           │    │
│  │  • Reads from /var/log/myapp/application.log       │    │
│  │  • Sends TCP to EC2 (YOUR_OTEL_IP:9997)            │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ TCP (Splunk protocol)
                           │ Port 9997
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              EC2 (YOUR_OTEL_IP)                             │
│                                                             │
│  OTEL Collector                                             │
│  • tcplog receiver (port 9997)                              │
│  • Forwards to Splunk Cloud (HEC)                           │
│  • Forwards to Coralogix (OTLP)                             │
└─────────────────────────────────────────────────────────────┘
                   │                    │
                   │ HEC                │ OTLP
                   ▼                    ▼
        ┌─────────────────┐   ┌──────────────────┐
        │  Splunk Cloud   │   │   Coralogix      │
        └─────────────────┘   └──────────────────┘
```

---

## Prerequisites

1. **AWS CLI** configured
2. **kubectl** configured for your cluster
3. **Docker buildx** for multi-arch builds
4. **EC2 OTEL** running with tcplog receiver
5. **ECR repositories** (will be created automatically)

---

## Step 1: Update EC2 OTEL Configuration

Your EC2 OTEL needs to use `tcplog` receiver instead of `splunk_hec`:

```yaml
receivers:
  tcplog:
    listen_address: "0.0.0.0:9997"  # Changed from splunk_hec!
    attributes: {}
    add_attributes: true
    encoding: utf-8

exporters:
  splunk_hec/logs:
    token: "YOUR_SPLUNK_HEC_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
    # ... rest of config
  
  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_PRIVATE_KEY"
    # ... rest of config

service:
  pipelines:
    logs:
      receivers: [tcplog]  # Changed from splunk_hec!
      exporters: [splunk_hec/logs, coralogix]
```

**Important**: 
- Restart OTEL on EC2 with new config
- Open port 9997 in EC2 Security Group

---

## Step 2: Push Images to ECR

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase6

# Build and push to ECR
./push-to-ecr.sh
```

This will:
- Login to ECR
- Create repositories if needed
- Build multi-arch app image (amd64 + arm64)
- Build x86_64 Splunk UF image
- Push both to ECR

---

## Step 3: Deploy to Kubernetes

```bash
# Deploy to default namespace
kubectl apply -f k8s/deployment.yaml

# Check deployment
kubectl get pods -l app=splunk-phase6

# Check logs
kubectl logs -l app=splunk-phase6 -c app
kubectl logs -l app=splunk-phase6 -c splunk-forwarder
```

---

## Step 4: Verify Logs

### Check EC2 OTEL Logs
```bash
# SSH to EC2
ssh ec2-user@YOUR_OTEL_IP

# Check OTEL logs
docker logs -f otel-collector-ec2
# or
journalctl -u otel-collector -f
```

Look for:
- ✅ TCP connections from K8s
- ✅ Log parsing
- ✅ Forwarding to Splunk and Coralogix

### Check Splunk
```
index=main sourcetype="python:phase6:k8s"
```

### Check Coralogix
Filter: `applicationName:"MyApp-Phase6-TCP-Experimental"`

---

## EC2 Security Group Requirements

**Inbound Rules:**
- Port 9997 (TCP) - Allow from anywhere (or K8s CIDR)
- Description: OTEL tcplog receiver

```bash
# Using AWS CLI
aws ec2 authorize-security-group-ingress \
  --group-id <your-security-group-id> \
  --protocol tcp \
  --port 9997 \
  --cidr 0.0.0.0/0
```

---

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -l app=splunk-phase6
kubectl logs -l app=splunk-phase6 -c splunk-forwarder --previous
```

### Can't pull images
```bash
# Check ECR permissions
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 104013952213.dkr.ecr.us-east-1.amazonaws.com
```

### EC2 not receiving logs
- Check Security Group (port 9997)
- Check OTEL is running
- Check tcplog receiver config
- Check connectivity from K8s to EC2

### Logs not in Splunk/Coralogix
- Check EC2 OTEL logs for errors
- Verify Splunk/Coralogix credentials
- Check if tcplog can parse Splunk TCP protocol

---

## Clean Up

```bash
# Delete K8s resources
kubectl delete -f k8s/deployment.yaml

# Delete ECR images (optional)
aws ecr batch-delete-image \
  --repository-name splunk-phase6-app \
  --image-ids imageTag=latest

aws ecr batch-delete-image \
  --repository-name splunk-phase6-forwarder-tcp \
  --image-ids imageTag=latest
```

---

## Expected Behavior

### Success Indicators:
- ✅ Pod running (both containers)
- ✅ App writing logs
- ✅ Splunk UF forwarding via TCP
- ✅ EC2 OTEL receiving logs
- ✅ Logs in Splunk
- ✅ Logs in Coralogix
- ✅ Same RequestID in both

### If tcplog can't parse Splunk TCP:
- ⚠️ Garbled logs
- ⚠️ Parsing errors in OTEL
- ⚠️ Missing metadata
- **Solution**: Switch to Phase 4 (HEC) instead

---

## Images

- **App**: `104013952213.dkr.ecr.us-east-1.amazonaws.com/splunk-phase6-app:latest`
- **Splunk UF**: `104013952213.dkr.ecr.us-east-1.amazonaws.com/splunk-phase6-forwarder-tcp:latest`

---

## Notes

- **Experimental**: tcplog with Splunk TCP is untested
- **Production**: Use Phase 4 (HEC) for reliability
- **Learning**: Great for understanding TCP forwarding
- **Architecture**: Sidecar pattern (app + forwarder in same pod)

