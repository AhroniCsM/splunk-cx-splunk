# EC2 OTEL Setup Instructions for Phase 4

## Your EC2 OTEL is Already Configured!

You have OTEL running on your EC2 with the config you showed me. Perfect! ✅

## What I Created for You:

### 1. `ec2-otel-config.yaml` (with env vars)
- Uses environment variables
- Best practice for security
- Recommended for production

### 2. `ec2-otel-config-resolved.yaml` (with actual values)
- All values resolved
- Ready to use directly
- Copy this to your EC2 if you want to update

## Splunk Details (Resolved):

```yaml
token: "YOUR_SPLUNK_HEC_TOKEN"
endpoint: "https://your-instance.splunkcloud.com:8088"
```

## Now: Configure Phase 4 to Point to Your EC2

### Step 1: Get Your EC2 IP

```bash
# On your EC2
curl http://169.254.169.254/latest/meta-data/public-ipv4

# Or from AWS Console
```

### Step 2: Configure Phase 4 Endpoint

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase4
./configure-ec2.sh

# Enter your EC2 IP when prompted
# Example: 54.123.45.67
```

This will update `outputs-hec-ec2.conf` to:
```ini
uri = http://YOUR_EC2_IP:8088/services/collector
```

### Step 3: Verify EC2 Security Group

Make sure your EC2 security group allows:
- **Inbound TCP 8088** from Phase 4 location

### Step 4: Deploy Phase 4

```bash
./deploy-phase4-to-ec2-otel.sh
```

## Architecture:

```
┌─────────────────────────────┐
│  Your EC2                   │
│  ┌───────────────────┐      │
│  │ OTEL Collector    │      │
│  │ (your config)     │      │
│  │ Port 8088         │      │
│  └─────┬─────────────┘      │
│        │                    │
│        ▼                    │
│  Splunk + Coralogix        │
└─────────────────────────────┘
         ▲
         │ HEC
         │
┌────────┼─────────────────────┐
│ Phase 4                      │
│ ┌─────────────┐              │
│ │ Python App  │              │
│ └──────┬──────┘              │
│        │ writes file         │
│        ▼                     │
│ ┌──────────────┐             │
│ │ Splunk UF    │             │
│ │ (reads file) │             │
│ └──────┬───────┘             │
│        │                     │
│        └─ HEC → http://YOUR_EC2_IP:8088/services/collector
└──────────────────────────────┘
```

## Verification:

### On EC2 (Monitor OTEL):
```bash
# If using Docker
docker logs -f otel-collector

# If using systemd
journalctl -u otel-collector -f
```

### Check Logs Arrive:

**Splunk:**
```
index=main sourcetype="python:phase4:ec2"
```

**Coralogix:**
```
applicationName:"ec2-classic-integration"
subsystemName:"central-collector"
```

## Notes:

✅ Your EC2 OTEL config is perfect!  
✅ Only Phase 4 needs configuration (the endpoint)  
✅ No code changes to Splunk UF or app  
✅ Works on x86_64 (EC2, not ARM Mac)  

## Important: Splunk Cloud Settings

⚠️ **Disable "Indexer Acknowledgment"** in your Splunk HEC token:
- Go to Splunk Cloud
- Settings → Data inputs → HTTP Event Collector
- Edit your token
- Uncheck "Enable indexer acknowledgment"
- Save

This is required for OTEL splunk_hec exporter to work properly!

