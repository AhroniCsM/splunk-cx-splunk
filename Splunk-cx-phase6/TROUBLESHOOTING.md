# Phase 6 Troubleshooting - No Logs in Destinations

## Problem: No logs appearing in Splunk or Coralogix

This means the logs are not reaching EC2 OTEL or OTEL is not forwarding them.

---

## Quick Diagnosis

### 1. Most Likely Issue: Splunk UF Not Running (ARM Architecture)

**Check:**
```bash
kubectl logs -l app=splunk-phase6 -c splunk-forwarder --tail=50
```

**If you see:**
```
Error calling execve(): No such file or directory
```

**Problem**: Your K8s nodes are ARM64, but Splunk UF image is x86_64 only.

**Solution Option A - Deploy to x86_64 nodes:**
```bash
# Check node architecture
kubectl get nodes -o wide

# If you have x86_64 nodes, add nodeSelector
kubectl patch deployment splunk-phase6-app -p '{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "kubernetes.io/arch": "amd64"
        }
      }
    }
  }
}'

# Or add toleration for x86 nodes
kubectl patch deployment splunk-phase6-app -p '{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
              "nodeSelectorTerms": [{
                "matchExpressions": [{
                  "key": "kubernetes.io/arch",
                  "operator": "In",
                  "values": ["amd64"]
                }]
              }]
            }
          }
        }
      }
    }
  }
}'

# Delete pod to reschedule on x86_64 node
kubectl delete pod -l app=splunk-phase6
```

**Solution Option B - Use HEC instead of TCP (RECOMMENDED):**

Since TCP with tcplog is experimental and Splunk UF won't run on ARM, use **Phase 4 with HEC** instead!

Phase 4 is proven to work and doesn't require x86_64 for the app.

---

### 2. EC2 OTEL Not Running

**Check on EC2:**
```bash
ssh ec2-user@YOUR_OTEL_IP

# Check if OTEL is running
docker ps | grep otel
# or
sudo systemctl status otel-collector
```

**If not running:**

**Start OTEL with tcplog config:**
```bash
# Copy the config
cat > otel-config.yaml << 'YAML'
receivers:
  tcplog:
    listen_address: "0.0.0.0:9997"

processors:
  batch:
    timeout: 10s
    send_batch_size: 100

exporters:
  splunk_hec/logs:
    token: "YOUR_SPLUNK_HEC_TOKEN"
    endpoint: "https://your-instance.splunkcloud.com:8088"
    source: "k8s-phase6"
    sourcetype: "python:phase6:k8s"
    index: "main"
    tls:
      insecure_skip_verify: true

  coralogix:
    domain: "eu2.coralogix.com"
    private_key: "YOUR_CORALOGIX_PRIVATE_KEY"
    application_name: "k8s-phase6-tcp"
    subsystem_name: "kubernetes"

  debug:
    verbosity: detailed

service:
  pipelines:
    logs:
      receivers: [tcplog]
      processors: [batch]
      exporters: [splunk_hec/logs, coralogix, debug]
YAML

# Run OTEL
docker run -d \
  --name otel-collector \
  -p 9997:9997 \
  -v $(pwd)/otel-config.yaml:/etc/otelcol-contrib/config.yaml \
  otel/opentelemetry-collector-contrib:latest \
  --config=/etc/otelcol-contrib/config.yaml

# Check logs
docker logs -f otel-collector
```

---

### 3. Port 9997 Not Open on EC2

**Check Security Group:**
```bash
# From local machine
aws ec2 describe-security-groups \
  --query 'SecurityGroups[*].IpPermissions[?FromPort==`9997`]' \
  --output table
```

**If port not open, add rule:**
```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=YOUR_OTEL_IP" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get security group ID
SG_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

# Add rule
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 9997 \
  --cidr 0.0.0.0/0
```

---

### 4. Network Connectivity Issue

**Test from K8s pod:**
```bash
# Get pod name
POD_NAME=$(kubectl get pod -l app=splunk-phase6 -o jsonpath='{.items[0].metadata.name}')

# Test connection
kubectl exec -it $POD_NAME -c app -- sh -c "
  apk add --no-cache netcat-openbsd 2>/dev/null || apt-get update && apt-get install -y netcat
  nc -zv YOUR_OTEL_IP 9997
"
```

**If connection fails:**
- Check EC2 security group
- Check K8s network policies
- Verify EC2 IP is correct
- Check if EC2 is in VPC accessible from K8s

---

### 5. tcplog Can't Parse Splunk TCP Protocol

**Check EC2 OTEL logs:**
```bash
docker logs otel-collector 2>&1 | grep -i "error\|parse\|failed"
```

**If you see parsing errors:**

This is expected! `tcplog` is for generic TCP, not Splunk's proprietary TCP protocol.

**Solution: Switch to Phase 4 with HEC**

HEC is proven to work and doesn't have this issue.

---

## RECOMMENDED FIX: Use Phase 4 with HEC

Instead of TCP (which is experimental), use **Phase 4 with HEC**:

### On EC2, change OTEL config to use splunk_hec receiver:

```yaml
receivers:
  splunk_hec:  # Changed from tcplog!
    endpoint: 0.0.0.0:8088  # Changed from 9997!
```

### In K8s, change Splunk UF outputs.conf:

Create new ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: splunk-uf-config
  namespace: default
data:
  outputs.conf: |
    [splunk_hec://ec2_otel]
    uri = http://YOUR_OTEL_IP:8088/services/collector
    token = YOUR_SPLUNK_HEC_TOKEN
    index = main
    sourcetype = python:phase4:k8s
```

Update deployment to use HEC instead of TCP.

**This is Phase 4 - already tested and working!** ✅

---

## Quick Fix Commands

```bash
# 1. Check if running on x86_64 nodes
kubectl get nodes -l kubernetes.io/arch=amd64

# 2. If no x86_64 nodes, switch to HEC (Phase 4)
# See Phase 4 documentation

# 3. Force reschedule on amd64 node (if available)
kubectl patch deployment splunk-phase6-app -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/arch":"amd64"}}}}}'
kubectl delete pod -l app=splunk-phase6

# 4. Check EC2 OTEL (SSH required)
ssh ec2-user@YOUR_OTEL_IP "docker logs otel-collector 2>&1 | tail -30"

# 5. Test connectivity
nc -zv YOUR_OTEL_IP 9997
```

---

## Summary

**Most likely issue**: K8s nodes are ARM64, Splunk UF won't run.

**Best solution**: Use **Phase 4 with HEC** instead of TCP.
- Already tested ✅
- Works on any architecture ✅
- No tcplog parsing issues ✅
- Production-ready ✅

**Alternative**: Deploy to x86_64 K8s nodes (if available).

