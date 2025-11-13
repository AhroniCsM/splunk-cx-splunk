# Quick Start - Splunk HEC Version ✅

## What's Different?

✅ **Works on ARM Mac!**  
✅ **No Splunk Universal Forwarder needed**  
✅ **Pure Python - sends logs via HTTP**  
✅ **Faster build (<5 seconds)**  
✅ **Easier to debug**  

## Prerequisites

You need a **Splunk HEC Token**. Follow these steps:

### Get Your HEC Token (2 minutes):

1. **Log in to Splunk Cloud:**
   ```
   https://prd-p-vl1fl.splunkcloud.com
   ```

2. **Go to Settings:**
   - Click **Settings** (top menu)
   - Click **Data Inputs**
   - Click **HTTP Event Collector**

3. **Create New Token:**
   - Click **New Token** (green button)
   - Name: `MyApp HEC`
   - Click **Next**
   - Source type: `json` or create `python:app`
   - Index: `main`
   - Click **Review** → **Submit**
   - **COPY THE TOKEN!** (looks like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

4. **Enable HEC (if needed):**
   - Click **Global Settings**
   - Set **All Tokens** to **Enabled**
   - Click **Save**

## Quick Start

### Option 1: Using the Helper Script

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx

# Set your token
export SPLUNK_HEC_TOKEN="paste-your-token-here"

# Run!
./run-hec.sh
```

### Option 2: Direct Docker Command

```bash
docker run -d \
  --name splunk-forwarder-hec \
  -e SPLUNK_HEC_TOKEN="your-token-here" \
  -e LOG_INTERVAL_SECONDS=30 \
  splunk-forwarder-app:hec

# View logs
docker logs -f splunk-forwarder-hec
```

## Verify It's Working

### Check Container Logs:
```bash
docker logs splunk-forwarder-hec
```

You should see:
```
✅ Successfully connected to Splunk HEC!
```

### Search in Splunk Cloud:

Wait 2-3 minutes, then search:

```spl
index=main sourcetype="python:app"
```

Or:

```spl
index=main earliest=-15m
| search "*MyApp*"
```

## What You'll See in Splunk

Events will look like:

```json
{
  "time": "2025-11-12T20:57:13",
  "event": {
    "message": "INFO: User authentication successful - RequestID: 1234",
    "severity": "INFO",
    "application": "MyApp"
  }
}
```

## Configuration Options

```bash
# Custom log interval (seconds between logs)
-e LOG_INTERVAL_SECONDS=60

# Custom index
-e SPLUNK_INDEX="custom_index"

# Custom sourcetype
-e SPLUNK_SOURCETYPE="myapp:logs"
```

## Troubleshooting

### "Failed to connect to Splunk HEC"

**Check 1: Verify Token**
```bash
curl -k https://your-instance.splunkcloud.com:8088/services/collector/event \
  -H "Authorization: Splunk YOUR-TOKEN-HERE" \
  -d '{"event": "test"}'
```

Should return: `{"text":"Success","code":0}`

**Check 2: HEC is Enabled**
```bash
curl -k https://your-instance.splunkcloud.com:8088/services/collector/health
```

Should return: `{"text":"HEC is healthy","code":17}`

### Logs Not in Splunk

1. **Wait 2-5 minutes** - indexing delay is normal
2. **Check time range** - use "Last 24 hours"
3. **Verify index** - search `index=*` to see all indexes
4. **Check token permissions** - token needs write access to index

## Commands Reference

```bash
# Build (already done)
docker build -f Dockerfile.hec -t splunk-forwarder-app:hec .

# Run with token
SPLUNK_HEC_TOKEN=<token> ./run-hec.sh

# View logs
docker logs -f splunk-forwarder-hec

# Stop
docker stop splunk-forwarder-hec

# Remove
docker rm splunk-forwarder-hec

# Restart with new config
docker stop splunk-forwarder-hec && docker rm splunk-forwarder-hec
SPLUNK_HEC_TOKEN=<token> LOG_INTERVAL_SECONDS=60 ./run-hec.sh
```

## Success Checklist

- [ ] HEC token obtained from Splunk Cloud
- [ ] HEC enabled in Splunk Cloud global settings
- [ ] Docker image built (`splunk-forwarder-app:hec`)
- [ ] Container running (`docker ps`)
- [ ] Container logs show "Successfully connected to Splunk HEC"
- [ ] Logs visible in Splunk Cloud (wait 2-5 min)

## Next: Phase 2

Once logs are flowing to Splunk:
- Ready for OTEL integration!
- OTEL can receive logs and forward to multiple destinations
- Split logs to Splunk + Coralogix simultaneously

---

**Full documentation:** See `HEC_SETUP_GUIDE.md`

