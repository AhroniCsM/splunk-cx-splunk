# Phase 6 Success: Using Official Splunk Universal Forwarder Image

## ✅ BREAKTHROUGH ACHIEVED!

**Pod Status:** `2/2 Running` - NO MORE EXECVE ERRORS!  
**Pod IP:** `172.31.5.184`  
**K8s Node:** `ip-172-31-11-138.eu-north-1.compute.internal` (x86_64)

---

## The Problem We Solved

### What DIDN'T Work
Building our own Splunk UF image by downloading and extracting the Linux tar.gz:

```dockerfile
FROM debian:bullseye
RUN wget splunkforwarder.tgz
RUN tar -xzf splunkforwarder.tgz
# → FAILED with "Error calling execve()"
```

**Tried:**
- ❌ Python slim base
- ❌ Debian bullseye-slim
- ❌ Debian bullseye (full) with all dependencies
- ❌ All failed with the same execve error!

### What WORKED
Using **Splunk's official Docker image**:

```yaml
containers:
  - name: splunk-forwarder
    image: splunk/universalforwarder:latest  # ✅ Works!
    env:
      - name: SPLUNK_START_ARGS
        value: "--accept-license"
      - name: SPLUNK_PASSWORD
        value: "changeme123"
      - name: SPLUNK_GENERAL_TERMS
        value: "--accept-sgt-current-at-splunk-com"
```

---

## Configuration That Works

### Deployment
File: `k8s/deployment-official-splunk.yaml`

**Key Points:**
1. Uses `splunk/universalforwarder:latest` official image
2. ConfigMap for inputs.conf and outputs.conf
3. Shared volume between app and Splunk UF
4. Proper license acceptance env vars

### Splunk UF Configuration
```ini
# inputs.conf
[monitor:///var/log/myapp/application.log]
disabled = false
sourcetype = python:phase6:k8s
index = main

# outputs.conf
[tcpout]
defaultGroup = ec2_otel_tcp

[tcpout:ec2_otel_tcp]
server = YOUR_OTEL_IP:9997
```

---

## Current Architecture

```
┌───────────────────────────────────────────────────────────┐
│  Kubernetes Pod (172.31.5.184)                           │
│  ┌──────────────┐  ┌────────────────────────────────┐   │
│  │ Python App   │  │ Splunk UF (OFFICIAL IMAGE!)   │   │
│  │ (writes logs)│  │ ✅ RUNNING without errors      │   │
│  │              │  │ ✅ Reads logs from file        │   │
│  └──────────────┘  │ ✅ Configured to send TCP      │   │
│         │          │    to EC2:9997                 │   │
│         ▼          └────────┬───────────────────────┘   │
│   /var/log/myapp/           │                            │
│   application.log            │ Splunk TCP Protocol       │
└──────────────────────────────┼────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────┐
│  EC2: YOUR_OTEL_IP                                        │
│  OTEL Collector (as service)                              │
│  ┌────────────────────────────────────────────────┐      │
│  │  tcplog receiver on 0.0.0.0:9997               │      │
│  │  (Waiting for connections from 172.31.5.184)   │      │
│  └────────────────────────────────────────────────┘      │
│              │                                             │
│              ├──────────────┬──────────────┐             │
│              ▼              ▼              ▼             │
│      ┌────────────┐  ┌──────────┐  ┌──────────┐        │
│      │   Splunk   │  │Coralogix │  │  Debug   │        │
│      │   Cloud    │  │          │  │          │        │
│      └────────────┘  └──────────┘  └──────────┘        │
└───────────────────────────────────────────────────────────┘
```

---

## Next Steps: Verify on EC2

### 1. Check OTEL is Listening on Port 9997

```bash
sudo netstat -tlnp | grep 9997
```

**Expected output:**
```
tcp  0  0 0.0.0.0:9997  0.0.0.0:*  LISTEN  <PID>/otel-collector
```

### 2. Check OTEL Logs for Connections

```bash
# Watch live
sudo journalctl -u otel-collector -f

# Check recent logs
sudo journalctl -u otel-collector --since "5 minutes ago"

# Look for TCP connections from K8s pod IP
sudo journalctl -u otel-collector --since "5 minutes ago" | grep 172.31.5.184
```

**What to look for:**
- ✅ "Starting stanza receiver" or "tcplog" startup messages
- ✅ TCP connection attempts from `172.31.5.184`
- ⚠️ Any errors parsing the TCP data
- ⚠️ "Unable to parse" or similar protocol errors

### 3. Check if Logs Reach Splunk

In Splunk Cloud:
```
index=main sourcetype="python:phase6:k8s"
| head 20
```

### 4. Check if Logs Reach Coralogix

In Coralogix:
- Application: `k8s-phase6-tcp`
- Subsystem: `kubernetes`

---

## The Big Question: Can tcplog Parse Splunk's TCP?

**Current Status:**
- ✅ Splunk UF is RUNNING and configured to send TCP
- ✅ Splunk UF should be connecting to EC2:9997
- ❓ Can OTEL `tcplog` receiver parse Splunk's proprietary TCP protocol?

**Possible Outcomes:**

### Outcome A: tcplog Works ✅
- Logs appear in both Splunk and Coralogix
- **Phase 6 is complete!**
- Splunk TCP → OTEL tcplog → Splunk + Coralogix

### Outcome B: tcplog Can't Parse ❌
- OTEL receives TCP data but can't structure it
- Logs don't appear correctly in destinations
- **Solution:** Use Phase 4 with HEC instead
- HEC is HTTP-based and fully supported by OTEL

---

## Comparison: All Working Solutions

| Phase | Transport | Splunk UF Needed? | OTEL Location | Works? |
|-------|-----------|-------------------|---------------|--------|
| **Phase 4** | HEC (HTTP) | No - Python sends HEC | EC2 | ✅ Proven |
| **Phase 5** | Dual (TCP + File) | Yes - on EC2/VM | EC2 (reads file) | ✅ Proven |
| **Phase 6** | TCP to OTEL | Yes - in K8s | EC2 (tcplog) | ❓ Testing |

---

## Commands Summary

### K8s Side (Already Done ✅)

```bash
# Deployed
kubectl get pod -l app=splunk-phase6-official
# Should show: 2/2 Running

# Check Splunk UF logs
kubectl logs -l app=splunk-phase6-official -c splunk-forwarder

# Check app logs
kubectl logs -l app=splunk-phase6-official -c app
```

### EC2 Side (Your Turn!)

```bash
# 1. Check OTEL listening
sudo netstat -tlnp | grep 9997

# 2. Watch OTEL logs live
sudo journalctl -u otel-collector -f

# 3. Check for K8s pod connections
sudo journalctl -u otel-collector --since "5 minutes ago" | grep 172.31.5.184

# 4. Check for any TCP errors
sudo journalctl -u otel-collector --since "5 minutes ago" | grep -i "error\|parse\|fail"
```

---

## Key Learnings

1. **Don't build custom Splunk UF images**
   - Use `splunk/universalforwarder:latest` official image
   - It has all dependencies and proper configuration

2. **License acceptance is specific**
   - Need both `SPLUNK_START_ARGS` and `SPLUNK_GENERAL_TERMS`
   - Password is required even for UF

3. **Splunk UF CAN run in K8s containers**
   - When using the official image!
   - On x86_64 nodes
   - With proper configuration

4. **Splunk's TCP protocol is proprietary**
   - OTEL `tcplog` receiver is for generic TCP syslog
   - May not fully support Splunk's specific protocol
   - This is why HEC (Phase 4) is more reliable

---

## If tcplog Doesn't Work...

**Recommended Solution: Phase 4 with HEC**

It's proven to work and achieves the same goal:
- Customer changes one endpoint → EC2 OTEL
- OTEL forwards to both Splunk + Coralogix
- Uses standard HTTP (HEC) protocol
- No compatibility issues!

See: `../Splunk-cx-phase4/` for working HEC implementation.

---

## Files Created

- `k8s/deployment-official-splunk.yaml` - Working K8s deployment
- `USING_OFFICIAL_SPLUNK_IMAGE.md` - Documentation
- `PHASE6_SUCCESS_WITH_OFFICIAL_IMAGE.md` - This file

---

## Status

🎉 **Splunk UF is RUNNING in K8s** (first time!)  
⏳ **Waiting for EC2 verification** (check OTEL logs)  
❓ **Will tcplog work?** (To be determined)

**Run the EC2 commands above and report back!**

