# Phase 6 - RAW TCP Solution

## 🎯 The Problem We Solved

Splunk Universal Forwarder was sending logs to OTEL's `tcplog` receiver using Splunk's proprietary **"cooked mode"** binary protocol, which OTEL could not parse. The logs appeared corrupted, showing protocol headers like `--splunk-cooked-mode-v3--` instead of actual log content.

## 💡 The Solution

Configure Splunk Universal Forwarder to send **plain text (raw mode)** instead of binary cooked mode by setting:

```ini
sendCookedData = false
```

## 📝 Configuration Changes

### outputs.conf (BEFORE - Cooked Mode ❌)
```ini
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = YOUR_OTEL_IP:9997
# No sendCookedData setting = defaults to true (cooked mode)
```

### outputs.conf (AFTER - Raw Mode ✅)
```ini
[tcpout]
defaultGroup = otel_raw_tcp

[tcpout:otel_raw_tcp]
server = YOUR_OTEL_IP:9997
sendCookedData = false  # Send plain text, not binary!
```

## 🔄 Complete Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Kubernetes Pod (Phase 6 RAW TCP)                        │
│                                                            │
│  ┌─────────────────┐                                      │
│  │  Python App     │                                      │
│  │  (app_phase6.py)│                                      │
│  └────────┬────────┘                                      │
│           │                                                │
│           │ Write logs to file                            │
│           │                                                │
│           ▼                                                │
│  ┌─────────────────────────────┐                          │
│  │  /var/log/myapp/           │                          │
│  │  application.log            │                          │
│  └──────────┬──────────────────┘                          │
│             │                                              │
│             │ Read file                                    │
│             │                                              │
│             ▼                                              │
│  ┌─────────────────────────────────┐                      │
│  │  Splunk Universal Forwarder    │                      │
│  │  (RAW TCP Mode)                │                      │
│  │  sendCookedData=false          │                      │
│  └──────────┬──────────────────────┘                      │
└─────────────┼──────────────────────────────────────────────┘
              │
              │ TCP:9997
              │ PLAIN TEXT! 📄
              │
              ▼
     ┌──────────────────────┐
     │  EC2 Instance        │
     │  YOUR_OTEL_IP:9997   │
     │                      │
     │  ┌────────────────┐  │
     │  │ OTEL Collector │  │
     │  │ tcplog receiver│  │
     │  └────┬───────┬───┘  │
     └───────┼───────┼───────┘
             │       │
             │       │
    ┌────────┘       └──────────┐
    │                           │
    │ HEC                       │ Native
    ▼                           ▼
┌──────────────┐        ┌──────────────┐
│ Splunk Cloud │        │  Coralogix   │
│ index=main   │        │ k8s-phase6   │
└──────────────┘        └──────────────┘
```

## 🔍 What Changed in the TCP Stream

### Before (Cooked Mode)
```
--splunk-cooked-mode-v3--splunk-phase6-official-7dc4845cf-7d5zk8089@__s2s_capabilitiesack=0;compression=0_raw host = unknownsource = k8s-phase6-tcpsourcetype = python:phase6:k8s
```

### After (Raw Mode)
```
2025-11-13 21:45:32 - INFO - Application started - RequestID: 8472
2025-11-13 21:46:02 - INFO - Processing request - RequestID: 8473
```

## 📦 Files Created

1. **outputs-raw-tcp.conf** - Splunk UF config with `sendCookedData=false`
2. **Dockerfile.splunk-raw** - Docker image for Splunk UF in RAW mode
3. **k8s/deployment-raw-tcp.yaml** - Kubernetes deployment
4. **push-raw-tcp-to-ecr.sh** - Script to build and push to ECR

## 🚀 Deployment

```bash
# 1. Build and push image
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase6
./push-raw-tcp-to-ecr.sh

# 2. Deploy to Kubernetes
kubectl apply -f k8s/deployment-raw-tcp.yaml

# 3. Check pod status
kubectl get pods -n default -l app=splunk-phase6-raw

# 4. Check logs
kubectl logs -n default -l app=splunk-phase6-raw -c splunk-forwarder --tail=50
```

## ✅ Verification

### 1. Check Coralogix
```
application.name:"k8s-phase6-tcp"
```
You should see clean logs with actual RequestIDs and timestamps.

### 2. Check Splunk
```
index=main sourcetype="python:phase6:k8s"
```
You should see the same clean logs, not corrupted protocol headers.

### 3. Check OTEL Debug Logs (on EC2)
```bash
ssh -i "aharon-key.pem" ec2-user@YOUR_OTEL_IP
sudo journalctl -u otelcol-contrib.service -f
```
You should see logs being received and processed cleanly.

## 🎓 Key Learnings

### Splunk's TCP Protocols

Splunk Universal Forwarder supports two TCP modes:

1. **Cooked Mode** (default, `sendCookedData=true`)
   - Binary protocol with metadata
   - Only Splunk indexers can understand it
   - Includes: host, source, sourcetype, timestamps, etc.
   - **Not compatible with generic TCP receivers**

2. **Raw Mode** (`sendCookedData=false`)
   - Plain text
   - Compatible with any TCP log receiver
   - **Works with OTEL tcplog receiver!**
   - Loses some metadata (but we add it back in OTEL)

### Why This Matters

Your requirement was:
> "Send from Splunk Universal Forwarder TCP to OTEL collector"

This is **only possible** with `sendCookedData=false` because:
- OTEL is NOT a Splunk indexer
- OTEL's `tcplog` receiver expects plain text
- Splunk's cooked mode is a proprietary binary protocol

## 📚 Reference

From your original Akeyless example:
```ini
[tcpout:akeyless_splunk]
server=$SPLUNK_HOST
# This was sending TO Splunk indexer
# Splunk indexer understands cooked mode
# So sendCookedData was fine (and default)
```

For OTEL:
```ini
[tcpout:otel_raw_tcp]
server=YOUR_OTEL_IP:9997
sendCookedData=false  # ← Required for OTEL!
# OTEL is NOT a Splunk indexer
# Must use raw mode for compatibility
```

## 🎉 Success Criteria

Phase 6 is successful when you see:
- ✅ Logs in Coralogix with application.name:"k8s-phase6-tcp"
- ✅ Logs in Splunk with index=main sourcetype="python:phase6:k8s"
- ✅ Clean log content (not corrupted protocol headers)
- ✅ Actual RequestIDs, timestamps, and application logs visible
- ✅ No `--splunk-cooked-mode-v3--` garbage

---

**Status**: Deployed to Kubernetes
**Deployment**: `splunk-phase6-raw-tcp`
**Pod**: Running (2/2 containers)
**Image**: `104013952213.dkr.ecr.us-east-1.amazonaws.com/splunk-phase6-forwarder-raw:latest`
**OTEL Target**: `YOUR_OTEL_IP:9997`

**Wait 2-3 minutes, then verify logs in Coralogix and Splunk! 🚀**

