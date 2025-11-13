# Quick Start: Seeing Your Logs in Splunk Cloud

## 🚀 Step 1: Build the Splunk Cloud Image (Running Now)

The build is currently running in the background. This takes **5-10 minutes** as it downloads Splunk Universal Forwarder (~200MB).

### Check Build Progress:
```bash
docker images | grep splunk-forwarder-app
```

When you see `splunkcloud` tag, the build is complete!

## 🏃 Step 2: Run the Container

Once the build completes:

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx

# Option A: Use the helper script (recommended)
./run-splunkcloud.sh

# Option B: Manual command
docker run -d \
  --name splunk-forwarder \
  -e LOG_INTERVAL_SECONDS=30 \
  splunk-forwarder-app:splunkcloud
```

The script will:
- Start Splunk Universal Forwarder
- Load your Splunk Cloud credentials (from splunkclouduf.spl)
- Start the Python app generating logs
- Begin forwarding logs to Splunk Cloud

## 📊 Step 3: View Logs in Splunk Cloud

### Login to Splunk Cloud:
Go to: **https://prd-p-vl1fl.splunkcloud.com**

### Search for Your Logs:

**Basic Search:**
```spl
index=main sourcetype="python:app"
```

**Recent Logs (last 15 minutes):**
```spl
index=main sourcetype="python:app" earliest=-15m
| table _time message
```

**By Log Level:**
```spl
index=main sourcetype="python:app"
| rex field=_raw "(?<level>INFO|WARNING|ERROR)"
| stats count by level
```

**Latest 100 Logs:**
```spl
index=main sourcetype="python:app"
| head 100
| table _time _raw
```

## ⏱️ Timeline

| Time | What to Expect |
|------|----------------|
| 0 min | Build starting |
| 5-10 min | Build completes |
| 11 min | Run container |
| 12 min | First log sent to Splunk Cloud |
| 15 min | Logs should be visible in Splunk |

**Note:** It may take 2-5 minutes for logs to appear in Splunk Cloud after the container starts.

## ✅ Verification Steps

### 1. Check Container is Running:
```bash
docker ps --filter name=splunk-forwarder
```

Should show:
```
CONTAINER ID   IMAGE                              STATUS
xxxxx          splunk-forwarder-app:splunkcloud   Up X minutes
```

### 2. Check Container Logs:
```bash
docker logs splunk-forwarder
```

Should show:
```
Starting Splunk Universal Forwarder...
Splunk status: Running
Starting Python Application...
Log generation interval: 30 seconds
Estimated daily logs: ~2,880
Estimated daily volume: ~0.41 MB
```

### 3. Check Splunk Forwarder Status:
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

Should show:
```
splunkd is running (PID: xxx)
```

### 4. Check Forward Server Connection:
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk list forward-server
```

Should show:
```
Active forwards:
    your-instance.splunkcloud.com:9997
```

### 5. View Application Logs Locally:
```bash
docker exec -it splunk-forwarder tail -f /var/log/myapp/application.log
```

## 🔍 Troubleshooting

### Can't See Logs in Splunk?

**Check 1: Verify container is running**
```bash
docker ps --filter name=splunk-forwarder
```

**Check 2: Look for connection errors**
```bash
docker exec -it splunk-forwarder tail -50 /opt/splunkforwarder/var/log/splunk/splunkd.log | grep -i error
```

**Check 3: Verify data is being read**
```bash
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk list inputstatus
```

**Check 4: Check Splunk internal logs**
```bash
docker exec -it splunk-forwarder tail -100 /opt/splunkforwarder/var/log/splunk/splunkd.log
```

### Common Issues:

#### Issue: "No results found" in Splunk
**Solution:**
1. Wait 2-5 minutes (initial delay is normal)
2. Check time range in Splunk (try "Last 24 hours")
3. Verify container is running: `docker ps`
4. Check logs are being generated: `docker logs splunk-forwarder`

#### Issue: Container exits immediately
**Solution:**
```bash
docker logs splunk-forwarder
# Look for errors, then restart:
docker stop splunk-forwarder
docker rm splunk-forwarder
./run-splunkcloud.sh
```

#### Issue: SSL certificate errors
**Solution:**
The splunkclouduf.spl file contains the correct certificates. If you see SSL errors, verify the file is present:
```bash
docker exec -it splunk-forwarder ls -l /opt/splunkforwarder/etc/apps/100_prd-p-vl1fl_splunkcloud/
```

## 📈 What Logs Look Like in Splunk

You should see entries like:
```
2025-11-12 20:49:14 - MyApp - INFO - INFO: Configuration reloaded - RequestID: 6738
2025-11-12 20:49:44 - MyApp - INFO - INFO: Database query executed - RequestID: 6077  
2025-11-12 20:50:14 - MyApp - WARNING - WARNING: High memory usage detected - 85%
2025-11-12 20:50:44 - MyApp - ERROR - ERROR: Connection timeout - User: user42
```

## 🎛️ Adjusting Log Volume

If you need to change how many logs are generated:

```bash
# Stop current container
docker stop splunk-forwarder
docker rm splunk-forwarder

# Restart with different interval (e.g., 60 seconds)
LOG_INTERVAL_SECONDS=60 ./run-splunkcloud.sh
```

See `LOG_VOLUME_GUIDE.md` for detailed volume management.

## 📞 Need Help?

**Check current status:**
```bash
# Overall container health
docker ps --filter name=splunk-forwarder

# Recent logs
docker logs --tail 50 splunk-forwarder

# Splunk forwarder status
docker exec -it splunk-forwarder /opt/splunkforwarder/bin/splunk status
```

**Common Commands:**
```bash
# Stop container
docker stop splunk-forwarder

# Start container
docker start splunk-forwarder

# View live logs
docker logs -f splunk-forwarder

# Restart container
docker restart splunk-forwarder

# Remove and recreate
docker stop splunk-forwarder && docker rm splunk-forwarder
./run-splunkcloud.sh
```

## ✨ Success Checklist

- [ ] Build completed successfully
- [ ] Container is running (`docker ps`)
- [ ] Splunk forwarder status shows "running"
- [ ] Forward server shows Splunk Cloud endpoint
- [ ] Logs visible in container (`docker logs`)
- [ ] **Logs visible in Splunk Cloud UI** ✅

Once you see your logs in Splunk Cloud, you're ready for Phase 2 (OTEL integration)!

