# Phase 6 - Verification Guide

## Architecture

```
Kubernetes Pod → Splunk UF → TCP:9997 → EC2 OTEL → [Splunk, Coralogix]
```

---

## Step-by-Step Verification

### 1. Check Kubernetes Pod

```bash
# Check pod status
kubectl get pods -l app=splunk-phase6

# Expected: 2/2 Running
# NAME                                 READY   STATUS    RESTARTS   AGE
# splunk-phase6-app-597bf56596-xxxxx   2/2     Running   0          Xm
```

**If not Running:**
```bash
kubectl describe pod -l app=splunk-phase6
kubectl logs -l app=splunk-phase6 -c app
kubectl logs -l app=splunk-phase6 -c splunk-forwarder
```

### 2. Check App Logs

```bash
kubectl logs -l app=splunk-phase6 -c app --tail=20
```

**Expected output:**
```
PHASE 6 APPLICATION STARTED - EXPERIMENTAL TCP
Writing logs to: /var/log/myapp/application.log
RequestID: 1 | Method: POST | Endpoint: /api/products | Status: 201
RequestID: 2 | ...
```

### 3. Check Splunk UF Logs

```bash
kubectl logs -l app=splunk-phase6 -c splunk-forwarder --tail=50
```

**Expected output:**
```
Splunk Universal Forwarder - Phase 6 Kubernetes
Configuration:
  Input: /var/log/myapp/application.log
  Output: TCP to EC2 YOUR_OTEL_IP:9997
Splunk Universal Forwarder started successfully
```

**Note**: On ARM nodes, you may see:
```
Error calling execve(): No such file or directory
```
This is expected - Splunk UF needs x86_64. Check if your K8s nodes are amd64.

---

## 4. Check EC2 OTEL Collector

**SSH to EC2:**
```bash
ssh ec2-user@YOUR_OTEL_IP
```

### A. Check OTEL is Running

```bash
# If using Docker:
docker ps | grep otel

# Expected output:
# CONTAINER ID   IMAGE                                        STATUS
# xxxxx          otel/opentelemetry-collector-contrib:latest  Up X minutes

# If using systemd:
sudo systemctl status otel-collector
```

### B. Check OTEL Configuration

```bash
# View current config
docker exec otel-collector cat /etc/otelcol-contrib/config.yaml | grep -A 5 "receivers:"

# Expected:
# receivers:
#   tcplog:
#     listen_address: "0.0.0.0:9997"
```

### C. Check Port 9997 is Listening

```bash
sudo netstat -tlnp | grep 9997
# or
sudo ss -tlnp | grep 9997
# or
sudo lsof -i :9997

# Expected output:
# tcp  0  0  0.0.0.0:9997  0.0.0.0:*  LISTEN  <pid>/otelcol-contrib
```

### D. Check OTEL Logs (MOST IMPORTANT!)

```bash
# If Docker:
docker logs -f otel-collector-ec2

# If systemd:
journalctl -u otel-collector -f
```

**What to look for:**

✅ **Success Indicators:**
```
Starting stanza receiver                               → tcplog started
Everything is ready. Begin running and processing data → OTEL ready
Logs   {"#logs": X}                                    → Receiving logs
```

✅ **Good signs:**
- TCP connections established
- Log entries being parsed
- Exporting to splunk_hec/logs
- Exporting to coralogix

❌ **Error Indicators:**
```
failed to parse
connection refused
timeout
invalid data
```

---

## 5. Check Security Group

**From your local machine:**

```bash
# Check if port 9997 is open
aws ec2 describe-security-groups \
  --filters "Name=ip-address,Values=YOUR_OTEL_IP" \
  --query 'SecurityGroups[*].IpPermissions[?FromPort==`9997`]' \
  --output table
```

**Expected**: Rule allowing TCP 9997 from 0.0.0.0/0 (or K8s CIDR)

**Or check in AWS Console:**
1. Go to EC2 → Security Groups
2. Find security group for your EC2
3. Check Inbound Rules
4. Should have: Type=Custom TCP, Port=9997, Source=0.0.0.0/0

---

## 6. Test Connectivity from K8s to EC2

```bash
# Get a shell in the app container
kubectl exec -it <pod-name> -c app -- /bin/bash

# Test connectivity to EC2 port 9997
apt-get update && apt-get install -y netcat
nc -zv YOUR_OTEL_IP 9997

# Expected output:
# Connection to YOUR_OTEL_IP 9997 port [tcp/*] succeeded!
```

---

## 7. Check Splunk

**Search in Splunk:**
```
index=main sourcetype="python:phase4:ec2"
```

**Or more specific:**
```
index=main sourcetype="python:phase4:ec2" "RequestID"
| sort -_time
| head 10
```

**Expected**: Logs with RequestIDs matching your K8s app

---

## 8. Check Coralogix

**Filter by:**
- Application: `ec2-classic-integration`
- Subsystem: `central-collector`

**Search for:**
```
RequestID
```

**Expected**: Same RequestIDs as in Splunk

---

## Common Issues and Solutions

### Issue 1: Splunk UF Not Running in K8s

**Symptom:**
```
Error calling execve(): No such file or directory
```

**Cause**: K8s node is ARM, Splunk UF image is x86_64

**Solution:**
```bash
# Check node architecture
kubectl get nodes -o wide

# If ARM, either:
# - Deploy to x86_64 node pool
# - Add nodeSelector to deployment:
kubectl patch deployment splunk-phase6-app -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/arch":"amd64"}}}}}'
```

### Issue 2: EC2 OTEL Not Receiving Logs

**Symptom**: OTEL logs show no incoming connections

**Possible causes:**

1. **Port 9997 not open**
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id <sg-id> \
     --protocol tcp \
     --port 9997 \
     --cidr 0.0.0.0/0
   ```

2. **OTEL not listening**
   ```bash
   docker restart otel-collector-ec2
   ```

3. **Wrong receiver config**
   - Verify `tcplog` is in receivers (not `splunk_hec`)
   - Verify pipeline uses `[tcplog]`

### Issue 3: Logs Garbled or Not Parsing

**Symptom**: OTEL receives data but can't parse

**Cause**: tcplog receiver can't parse Splunk's proprietary TCP protocol

**Solution**: This is the experimental part! tcplog is for generic TCP, not Splunk TCP.

**Options:**
- Check OTEL debug logs for parsing details
- May need to switch to HEC (Phase 4 with HEC instead)

### Issue 4: Logs Not in Splunk/Coralogix

**Symptom**: OTEL receives logs but they don't appear in destinations

**Check:**

1. **Splunk credentials**
   ```bash
   # Test Splunk HEC manually
   curl -k https://your-instance.splunkcloud.com:8088/services/collector \
     -H "Authorization: Splunk YOUR_SPLUNK_HEC_TOKEN" \
     -d '{"event":"test"}'
   ```

2. **Coralogix credentials**
   - Verify domain: eu2.coralogix.com
   - Verify private key is correct

3. **OTEL exporter errors**
   - Check OTEL logs for "failed to export"
   - Check "retry" messages

---

## Success Criteria

✅ **K8s Pod**: 2/2 Running
✅ **App**: Writing logs with RequestIDs
✅ **Splunk UF**: Running (on x86_64 node)
✅ **EC2 OTEL**: Receiving TCP connections
✅ **EC2 OTEL**: Parsing logs successfully
✅ **Splunk**: Logs appearing with RequestIDs
✅ **Coralogix**: Same RequestIDs as Splunk

---

## Quick Debug Commands

```bash
# K8s side
kubectl get pods -l app=splunk-phase6
kubectl logs -l app=splunk-phase6 -c app --tail=20
kubectl logs -l app=splunk-phase6 -c splunk-forwarder --tail=20

# EC2 side (SSH required)
docker logs -f otel-collector-ec2
sudo netstat -tlnp | grep 9997
docker ps | grep otel

# Test connectivity
kubectl exec -it <pod> -c app -- nc -zv YOUR_OTEL_IP 9997
```

---

## What We're Testing

**Hypothesis**: Can OTEL's `tcplog` receiver handle Splunk's proprietary TCP protocol?

**Expected Results:**
- **Best case**: Logs arrive in both Splunk and Coralogix ✅
- **Likely case**: OTEL receives data but can't parse properly ⚠️
- **Worst case**: Connection rejected or crashes ❌

**If it fails**: Switch to Phase 4 with HEC (proven to work!) ✅

