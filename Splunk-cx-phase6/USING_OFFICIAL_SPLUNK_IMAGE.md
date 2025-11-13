# Phase 6 - Using Official Splunk Universal Forwarder Image

## The Problem with Our Previous Approach

We were **building our own** Splunk UF image by:
1. Downloading the Linux tar.gz from Splunk
2. Extracting it in a minimal container (Debian slim/Python slim)
3. Trying to run the binary → **FAILED with execve errors**

**Why it failed:**
- Missing system libraries
- Incompatible base OS
- Not how Splunk intends UF to be containerized

---

## The Correct Approach: Use Splunk's Official Image

Splunk provides **pre-built, tested Docker images** for Universal Forwarder!

### Official Splunk Images

```bash
# Latest version
docker pull splunk/universalforwarder:latest

# Red Hat based (more robust)
docker pull splunk/universalforwarder:redhat

# Specific version
docker pull splunk/universalforwarder:9.3.1
```

**Benefits:**
- ✅ All dependencies included
- ✅ Tested by Splunk
- ✅ Officially supported
- ✅ Works in containers reliably
- ✅ Regular security updates

---

## How to Make Phase 6 Work

### What Changes Needed:

**BEFORE (Our Custom Build):**
```dockerfile
FROM debian:bullseye
RUN wget splunkforwarder.tgz
RUN tar -xzf splunkforwarder.tgz
# Install dependencies...
# → FAILS with execve error!
```

**AFTER (Official Image):**
```yaml
containers:
  - name: splunk-forwarder
    image: splunk/universalforwarder:latest  # ✅ Just use it!
    env:
      - name: SPLUNK_START_ARGS
        value: "--accept-license --answer-yes"
```

### Configuration via ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: splunk-uf-config
data:
  inputs.conf: |
    [monitor:///var/log/myapp/application.log]
    disabled = false
    sourcetype = python:phase6:k8s
    
  outputs.conf: |
    [tcpout]
    defaultGroup = ec2_otel
    
    [tcpout:ec2_otel]
    server = YOUR_OTEL_IP:9997
```

---

## Deployment Steps

### 1. Delete Old Phase 6 Deployment

```bash
kubectl delete deployment splunk-phase6-app
kubectl delete configmap splunk-uf-config 2>/dev/null || true
```

### 2. Deploy with Official Splunk Image

```bash
kubectl apply -f k8s/deployment-official-splunk.yaml
```

### 3. Verify Splunk UF is Running

```bash
# Check pod status
kubectl get pod -l app=splunk-phase6-official

# Check Splunk UF container logs
kubectl logs -l app=splunk-phase6-official -c splunk-forwarder --tail=50
```

**What you should see:**
```
Splunk Universal Forwarder starting...
Checking prerequisites...
All preliminary checks passed.
Starting splunk server daemon (splunkd)...
Done
```

**NOT this:**
```
Error calling execve()  ← This should be GONE!
```

### 4. Verify on EC2 OTEL

On your EC2 machine:

```bash
# Check OTEL is listening on port 9997
sudo netstat -tlnp | grep 9997

# Check OTEL logs for incoming TCP connections
sudo journalctl -u otel-collector -f | grep -i "tcp\|connection"
```

---

## Important Notes

### Splunk Official Image Requirements

1. **SPLUNK_PASSWORD env var is required** (even for UF)
   - Set to any secure password
   - Required by the image entrypoint

2. **Configuration can be mounted at:**
   - `/tmp/defaults/` - for default configs
   - `/opt/splunkforwarder/etc/system/local/` - for persistent configs

3. **The image handles:**
   - License acceptance (via SPLUNK_START_ARGS)
   - User creation
   - Permissions
   - Splunk initialization

### Will This Work with OTEL tcplog?

**Important:** Even with the official Splunk image working correctly, the **OTEL `tcplog` receiver still might not fully parse Splunk's proprietary TCP protocol**.

The `tcplog` receiver is designed for generic TCP syslog, not Splunk's specific protocol.

**You may see:**
- ✅ Splunk UF successfully starting
- ✅ Splunk UF connecting to EC2:9997
- ⚠️ OTEL receiving raw TCP data
- ❌ OTEL unable to properly parse/structure the logs

**This is why HEC (Phase 4) is still recommended** - it's a standard HTTP protocol that OTEL fully supports.

---

## Architecture: Phase 6 with Official Splunk Image

```
┌─────────────────────────────────────────────────────┐
│  Kubernetes Pod                                     │
│  ┌──────────────┐  ┌──────────────────────────────┐│
│  │ Python App   │  │ Splunk UF (OFFICIAL IMAGE)   ││
│  │ (writes logs)│  │ ✅ Pre-built by Splunk       ││
│  │              │  │ ✅ All dependencies included ││
│  └──────────────┘  │ ✅ Reads logs from file      ││
│         │          │ ✅ Sends via TCP             ││
│         ▼          └─────────────┬────────────────┘│
│   /var/log/myapp/               │                  │
│   application.log                │ TCP (port 9997)  │
└──────────────────────────────────┼──────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────┐
│  EC2: OTEL Collector                                │
│  ┌────────────────────────────────────────────────┐ │
│  │  tcplog receiver on 0.0.0.0:9997               │ │
│  │  (May not fully parse Splunk's TCP protocol)  │ │
│  └────────────────────────────────────────────────┘ │
│              │                                       │
│              ├─────────────┬──────────────┐         │
│              ▼             ▼              ▼         │
│      ┌────────────┐ ┌───────────┐ ┌──────────┐    │
│      │   Splunk   │ │ Coralogix │ │  Debug   │    │
│      │   (HEC)    │ │           │ │          │    │
│      └────────────┘ └───────────┘ └──────────┘    │
└─────────────────────────────────────────────────────┘
```

---

## Comparison: Custom vs Official Splunk Image

| Aspect | Our Custom Build | Official Splunk Image |
|--------|------------------|----------------------|
| **Binary execution** | ❌ execve errors | ✅ Works reliably |
| **Dependencies** | ❌ Missing/incomplete | ✅ All included |
| **Splunk support** | ❌ Not supported | ✅ Officially supported |
| **Security updates** | ❌ Manual | ✅ Automatic via image updates |
| **Image size** | ~100-200 MB | ~400-500 MB (but works!) |
| **Complexity** | ❌ High (build process) | ✅ Low (just use it) |

---

## Commands Summary

```bash
# 1. Deploy with official Splunk image
kubectl apply -f k8s/deployment-official-splunk.yaml

# 2. Watch pod startup
kubectl get pod -l app=splunk-phase6-official -w

# 3. Check Splunk UF logs (should show success!)
kubectl logs -l app=splunk-phase6-official -c splunk-forwarder -f

# 4. Check if Splunk process is running inside container
kubectl exec -it $(kubectl get pod -l app=splunk-phase6-official -o name) \
  -c splunk-forwarder -- /opt/splunkforwarder/bin/splunk status

# 5. On EC2: Check for incoming TCP connections
sudo journalctl -u otel-collector -f
```

---

## Expected Outcome

With the official Splunk image:
1. ✅ Splunk UF container will **START successfully** (no more execve errors!)
2. ✅ Splunk UF will **READ the log file**
3. ✅ Splunk UF will **CONNECT to EC2:9997**
4. ⚠️ OTEL `tcplog` receiver will **receive TCP data** (but may not parse it properly)
5. ❓ Logs may or may not appear correctly in Splunk/Coralogix

**If step 4/5 fails** → This confirms `tcplog` can't handle Splunk's TCP protocol → Use Phase 4 HEC instead!

---

## Next Step

**Try deploying with the official Splunk image and let's see if:**
1. The container starts successfully ✅
2. OTEL can process the TCP data ❓

If OTEL still can't process it correctly, then **Phase 4 HEC is the definitive solution**.

