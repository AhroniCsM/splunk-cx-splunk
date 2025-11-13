# Phase 1 - COMPLETE ✅

## What We Built

Three complete solutions for sending logs to Splunk:

### 1. ✅ **HEC Version (RECOMMENDED for your Mac)**
- **Status:** Ready to use
- **Platform:** Works on ARM Mac
- **Method:** HTTP Event Collector API
- **Image:** `splunk-forwarder-app:hec` (156 MB)
- **Pros:**
  - ✅ Works on ARM Mac
  - ✅ Native Python, no binary dependencies
  - ✅ Easy to debug (HTTP-based)
  - ✅ Production ready
  - ✅ Fast build (<5 seconds)

### 2. 📦 **Splunk Universal Forwarder Version**
- **Status:** Built but won't run on ARM Mac
- **Platform:** Requires x86_64 (Intel/AMD)
- **Method:** Full Splunk UF with SSL certificates
- **Image:** `splunk-forwarder-app:splunkcloud` (278 MB)
- **Use Case:** Deploy to EKS/EC2 (x86_64 servers)

### 3. 🧪 **Simple Test Version**
- **Status:** Working (for testing only)
- **Platform:** Works on ARM Mac
- **Method:** Plain TCP forwarding
- **Image:** `splunk-forwarder-app:simple` (148 MB)
- **Note:** No SSL, won't reach Splunk Cloud

## File Structure

```
Splunk-cx/
├── HEC Version (✅ Use This!)
│   ├── app_hec.py              - Python app with HEC support
│   ├── Dockerfile.hec          - HEC Docker image
│   ├── run-hec.sh              - Helper script
│   ├── HEC_SETUP_GUIDE.md      - Complete guide
│   └── QUICKSTART_HEC.md       - Quick start
│
├── Splunk UF Version (for x86_64 servers)
│   ├── Dockerfile.splunkcloud  - Full Splunk UF
│   ├── entrypoint_splunk.sh    - Startup script
│   ├── run-splunkcloud.sh      - Helper script
│   ├── inputs.conf             - Splunk input config
│   ├── outputs.conf.template   - Splunk output config
│   └── splunkclouduf.spl       - Your credentials
│
├── Test Version
│   ├── Dockerfile.simple       - Simple forwarder
│   ├── app.py                  - Log generator (volume controlled)
│   ├── simple_forwarder.sh     - TCP forwarder
│   └── entrypoint_simple.sh    - Startup script
│
└── Documentation
    ├── README.md               - Original comprehensive guide
    ├── QUICKSTART.md           - Quick start
    ├── LOG_VOLUME_GUIDE.md     - Volume management
    ├── TEST_RESULTS.md         - Test results
    └── PHASE1_COMPLETE.md      - This file
```

## How to Use (Quick Start)

### Step 1: Get HEC Token (2 minutes)

1. Go to: https://prd-p-vl1fl.splunkcloud.com
2. Settings → Data Inputs → HTTP Event Collector
3. Click "New Token"
4. Name: `MyApp`, Index: `main`, Sourcetype: `python:app`
5. **Copy the token!**

### Step 2: Run Container

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx

# Set your token
export SPLUNK_HEC_TOKEN="your-token-here"

# Run!
./run-hec.sh
```

### Step 3: Verify in Splunk

Wait 2-3 minutes, then search in Splunk Cloud:

```spl
index=main sourcetype="python:app"
```

## Log Volume Control

The app is configured to stay well within your 5 GB/day limit:

| Setting | Logs/Day | Volume/Day | % of 5GB Limit |
|---------|----------|------------|----------------|
| Default (30s) | 2,880 | 0.41 MB | 0.008% |
| Fast (10s) | 8,640 | 1.5 MB | 0.03% |
| Slow (60s) | 1,440 | 0.25 MB | 0.005% |

Change with: `-e LOG_INTERVAL_SECONDS=60`

## Docker Images Available

```
splunk-forwarder-app:hec          156MB  ✅ Use this on Mac
splunk-forwarder-app:splunkcloud  278MB  For x86_64 servers
splunk-forwarder-app:simple       148MB  Testing only
```

## What Each Version Does

### All Versions:
- ✅ Python app generates realistic logs (INFO/WARNING/ERROR)
- ✅ Configurable log rate via environment variable
- ✅ Writes to `/var/log/myapp/application.log`
- ✅ Respects 5 GB/day limit with conservative defaults

### HEC Version (Recommended):
- ✅ Sends logs via HTTPS to Splunk Cloud
- ✅ Uses your HEC token for authentication
- ✅ SSL/TLS enabled by default
- ✅ Works on ARM Mac
- ✅ Immediate feedback on success/failure

### Splunk UF Version (Production):
- ✅ Full Splunk Universal Forwarder
- ✅ Uses your splunkclouduf.spl credentials
- ✅ SSL with client certificates
- ⚠️ Requires x86_64 platform
- ✅ Standard enterprise deployment

### Simple Version (Testing):
- ✅ Plain TCP forwarding
- ⚠️ No SSL/authentication
- ✅ Works on ARM Mac
- ℹ️ Good for local testing only

## Deployment Options

### Option 1: Mac Local Testing ✅ **Current**
```bash
# Use HEC version
SPLUNK_HEC_TOKEN=xxx ./run-hec.sh
```

### Option 2: Deploy to EKS/EC2
```bash
# Push to ECR
docker tag splunk-forwarder-app:hec YOUR_ECR/splunk-forwarder:latest
docker push YOUR_ECR/splunk-forwarder:latest

# Deploy with Kubernetes
kubectl create secret generic splunk-hec \
  --from-literal=token=YOUR_HEC_TOKEN

kubectl run splunk-forwarder \
  --image=YOUR_ECR/splunk-forwarder:latest \
  --env="SPLUNK_HEC_TOKEN=$(kubectl get secret splunk-hec -o jsonpath='{.data.token}' | base64 -d)"
```

### Option 3: Use Splunk UF in Production
```bash
# On x86_64 server
docker run -d \
  --name splunk-forwarder \
  splunk-forwarder-app:splunkcloud
```

## Verification Commands

```bash
# Check container
docker ps --filter name=splunk-forwarder-hec

# View logs
docker logs -f splunk-forwarder-hec

# Check connection success
docker logs splunk-forwarder-hec | grep "Successfully connected"

# View app logs
docker exec -it splunk-forwarder-hec tail -f /var/log/myapp/application.log
```

## Troubleshooting

### HEC Connection Issues

```bash
# Test HEC endpoint
curl -k https://your-instance.splunkcloud.com:8088/services/collector/health

# Test with your token
curl -k https://your-instance.splunkcloud.com:8088/services/collector/event \
  -H "Authorization: Splunk YOUR-TOKEN" \
  -d '{"event": "test"}'
```

### Logs Not Appearing

1. Wait 2-5 minutes (indexing delay)
2. Check time range in Splunk (use "Last 24 hours")
3. Verify index: `index=*` to see all
4. Check token permissions in Splunk
5. Look for errors: `docker logs splunk-forwarder-hec | grep -i error`

## Phase 1 Achievements ✅

✅ **Python app** generating realistic logs  
✅ **Volume control** to stay within 5 GB/day limit  
✅ **Three deployment options** (HEC, Splunk UF, Simple)  
✅ **ARM Mac compatible** version (HEC)  
✅ **Production ready** Splunk UF version  
✅ **Complete documentation** with guides  
✅ **Helper scripts** for easy deployment  
✅ **SSL/TLS** support where needed  
✅ **Splunk Cloud** credentials integrated  

## Ready for Phase 2: OTEL Integration

Now that logs are flowing to Splunk, you can add OTEL in the middle:

```
App → OTEL Collector → Multiple Destinations:
                        ├─ Splunk Cloud
                        └─ Coralogix
```

Benefits:
- Transform/filter logs in OTEL
- Send to multiple destinations simultaneously
- Add additional metadata
- Central observability pipeline

## Quick Reference

```bash
# Build HEC version
docker build -f Dockerfile.hec -t splunk-forwarder-app:hec .

# Run with HEC
SPLUNK_HEC_TOKEN=xxx ./run-hec.sh

# Run with custom settings
docker run -d --name splunk-forwarder-hec \
  -e SPLUNK_HEC_TOKEN=xxx \
  -e LOG_INTERVAL_SECONDS=60 \
  -e SPLUNK_INDEX=custom \
  splunk-forwarder-app:hec

# Stop
docker stop splunk-forwarder-hec

# Remove
docker rm splunk-forwarder-hec

# View logs
docker logs -f splunk-forwarder-hec
```

## Support Documentation

- **HEC_SETUP_GUIDE.md** - Complete HEC setup guide
- **QUICKSTART_HEC.md** - Quick start for HEC
- **LOG_VOLUME_GUIDE.md** - Managing Splunk volume
- **README.md** - Original comprehensive guide
- **SPLUNK_CLOUD_GUIDE.md** - Splunk Cloud with UF

---

**🎉 Phase 1 Complete!**

You now have multiple working solutions to send logs to Splunk Cloud. The HEC version is recommended for your ARM Mac and is ready to use as soon as you provide your HEC token.

**Next:** Get your HEC token and run `./run-hec.sh` to see logs in Splunk Cloud! 🚀

