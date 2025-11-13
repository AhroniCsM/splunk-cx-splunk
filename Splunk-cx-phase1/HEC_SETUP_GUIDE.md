# Splunk HEC (HTTP Event Collector) Setup Guide

## ✅ Works on ARM Mac!

This version uses Splunk's HTTP Event Collector (HEC) API instead of Splunk Universal Forwarder, so it works perfectly on your ARM Mac!

## Step 1: Get Your Splunk HEC Token

### Option A: Create New HEC Token

1. **Log in to Splunk Cloud:**
   ```
   https://prd-p-vl1fl.splunkcloud.com
   ```

2. **Navigate to Settings:**
   - Click **Settings** (top right)
   - Click **Data Inputs**
   - Click **HTTP Event Collector**

3. **Create New Token:**
   - Click **New Token** (green button)
   - Give it a name: `MyApp HEC Token`
   - Click **Next**

4. **Configure Input Settings:**
   - Source name override: `myapp`
   - Source type: Select **Structured** > **json** or create custom `python:app`
   - Index: Select `main` (or your preferred index)
   - Click **Review**

5. **Save and Copy Token:**
   - Click **Submit**
   - **COPY THE TOKEN** - it looks like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - Save it securely!

### Option B: Use Existing HEC Token

If you already have an HEC token:
1. Go to **Settings** > **Data Inputs** > **HTTP Event Collector**
2. Find your token in the list
3. Click the token name to view details
4. Copy the **Token Value**

### Verify HEC is Enabled

1. In HEC settings, check **Global Settings**
2. Ensure **All Tokens** is set to **Enabled**
3. Note the **HTTP Port Number** (usually 8088)

## Step 2: Build the Docker Image

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx
docker build -f Dockerfile.hec -t splunk-forwarder-app:hec .
```

This builds in ~10 seconds (no Splunk UF download needed!)

## Step 3: Run the Container

### Basic Usage:

```bash
SPLUNK_HEC_TOKEN=your-token-here ./run-hec.sh
```

### With Custom Configuration:

```bash
# Set environment variables
export SPLUNK_HEC_TOKEN="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export LOG_INTERVAL_SECONDS=30
export SPLUNK_INDEX="main"
export SPLUNK_SOURCETYPE="python:app"

# Run
./run-hec.sh
```

### Manual Docker Command:

```bash
docker run -d \
  --name splunk-forwarder-hec \
  -e LOG_INTERVAL_SECONDS=30 \
  -e SPLUNK_HEC_TOKEN="your-token-here" \
  -e SPLUNK_HEC_URL="https://your-instance.splunkcloud.com:8088/services/collector/event" \
  -e SPLUNK_INDEX="main" \
  -e SPLUNK_SOURCETYPE="python:app" \
  splunk-forwarder-app:hec
```

## Step 4: Verify Logs in Splunk

### Wait 2-3 Minutes
HEC has a small delay before logs appear.

### Search in Splunk Cloud:

**Basic Search:**
```spl
index=main sourcetype="python:app"
```

**Recent Logs:**
```spl
index=main sourcetype="python:app" earliest=-15m
| table _time event.message event.severity
```

**By Severity:**
```spl
index=main sourcetype="python:app"
| stats count by event.severity
```

**Latest 100 Events:**
```spl
index=main sourcetype="python:app"
| head 100
| table _time event.message event.severity
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPLUNK_HEC_TOKEN` | **Required** - Your HEC token | None |
| `SPLUNK_HEC_URL` | HEC endpoint URL | `https://your-instance.splunkcloud.com:8088/services/collector/event` |
| `SPLUNK_INDEX` | Splunk index name | `main` |
| `SPLUNK_SOURCETYPE` | Sourcetype for events | `python:app` |
| `LOG_INTERVAL_SECONDS` | Seconds between logs | `30` |

## Monitoring

### View Container Logs:
```bash
docker logs -f splunk-forwarder-hec
```

### View Application Logs:
```bash
docker exec -it splunk-forwarder-hec tail -f /var/log/myapp/application.log
```

### Check Container Status:
```bash
docker ps --filter name=splunk-forwarder-hec
```

## Troubleshooting

### Error: "Failed to send to Splunk HEC"

**Check 1: Verify HEC Token**
- Make sure token is correct
- Check it's not expired
- Verify token is enabled in Splunk

**Check 2: Verify HEC is Enabled**
```bash
curl -k https://your-instance.splunkcloud.com:8088/services/collector/health
```
Should return: `{"text":"HEC is healthy","code":17}`

**Check 3: Test HEC Manually**
```bash
curl -k https://your-instance.splunkcloud.com:8088/services/collector/event \
  -H "Authorization: Splunk YOUR-TOKEN-HERE" \
  -d '{"event": "test event", "sourcetype": "manual"}'
```

**Check 4: Check Firewall**
Ensure port 8088 is accessible:
```bash
nc -zv your-instance.splunkcloud.com 8088
```

### Error: "SPLUNK_HEC_TOKEN not set"

Set the environment variable:
```bash
export SPLUNK_HEC_TOKEN="your-token-here"
./run-hec.sh
```

### Logs Not Appearing in Splunk?

1. **Wait 2-5 minutes** - HEC has indexing delay
2. **Check time range** - Try "Last 24 hours" in Splunk
3. **Verify index** - Make sure you're searching the right index
4. **Check container logs** - Look for connection errors
5. **Verify token permissions** - Token must have write access to the index

## Log Volume Management

Same as before - configure `LOG_INTERVAL_SECONDS`:

| Interval | Logs/Day | Volume/Day | % of 5GB |
|----------|----------|------------|----------|
| 10 sec   | 8,640    | 1.5 MB     | 0.03%    |
| 30 sec   | 2,880    | 0.5 MB     | 0.01%    |
| 60 sec   | 1,440    | 0.25 MB    | 0.005%   |
| 120 sec  | 720      | 0.12 MB    | 0.002%   |

## Advantages of HEC

✅ **Works on ARM Mac** - Pure Python, no binary dependencies  
✅ **Easier to debug** - HTTP-based, can test with curl  
✅ **More flexible** - Can add custom metadata easily  
✅ **Better error handling** - Get immediate HTTP response  
✅ **Faster setup** - No Splunk UF installation  
✅ **Production ready** - Used by many large organizations  

## Next Steps

Once logs are flowing to Splunk Cloud via HEC:
1. ✅ **Phase 1 Complete!**
2. Ready for **Phase 2**: Add OTEL in the middle
3. OTEL can receive from HEC and forward to multiple destinations

## Example Log Format in Splunk

You'll see events like this:

```json
{
  "time": 1699804734.123,
  "host": "39da6176c580",
  "source": "myapp",
  "sourcetype": "python:app",
  "index": "main",
  "event": {
    "message": "INFO: User authentication successful - RequestID: 1234",
    "severity": "INFO",
    "application": "MyApp"
  }
}
```

## Security Note

**Never commit your HEC token to git!**

Add to `.gitignore`:
```
*.token
.env
```

Store tokens securely:
- Use environment variables
- Use secrets management (AWS Secrets Manager, etc.)
- Use Kubernetes secrets for production

