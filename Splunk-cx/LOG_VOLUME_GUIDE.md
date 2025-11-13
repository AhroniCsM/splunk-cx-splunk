# Managing Splunk Log Volume (5 GB/day limit)

## Overview

Your Splunk instance has a **5 GB/day** limit. The Python app has been modified to generate logs at a **configurable rate** to help you stay within this limit.

## Default Configuration

**Default Setting**: 1 log every **30 seconds**

This generates approximately:
- **2,880 logs per day**
- **~0.5 MB per day** per app instance
- Uses **0.01%** of your 5 GB daily limit

## Configuring Log Rate

### Option 1: Set Environment Variable at Runtime

```bash
# 30 seconds between logs (default)
LOG_INTERVAL_SECONDS=30 ./run-splunkcloud.sh

# 60 seconds between logs (very conservative)
LOG_INTERVAL_SECONDS=60 ./run-splunkcloud.sh

# 10 seconds between logs (for testing)
LOG_INTERVAL_SECONDS=10 ./run-splunkcloud.sh
```

### Option 2: Direct Docker Command

```bash
docker run -d \
  --name splunk-forwarder \
  -e LOG_INTERVAL_SECONDS=30 \
  splunk-forwarder-app:splunkcloud
```

### Option 3: Modify Default in app.py

Edit line 15 in `app.py`:
```python
LOG_INTERVAL_SECONDS = int(os.getenv('LOG_INTERVAL_SECONDS', '30'))
#                                                              ^^^ Change this
```

## Log Volume Calculator

| Interval (sec) | Logs/Day | Est. Volume/Day | % of 5GB Limit |
|----------------|----------|-----------------|----------------|
| 10             | 8,640    | 1.5 MB          | 0.03%          |
| 30             | 2,880    | 0.5 MB          | 0.01%          |
| 60             | 1,440    | 0.25 MB         | 0.005%         |
| 120            | 720      | 0.12 MB         | 0.002%         |
| 300 (5 min)    | 288      | 0.05 MB         | 0.001%         |

**Note**: Estimates assume ~150 bytes per log line.

## Multiple Application Support

With the default 30-second interval, you can run:
- **10,000 instances** before reaching 5 GB/day
- **100 instances** = 50 MB/day (1% of limit)
- **1,000 instances** = 500 MB/day (10% of limit)

This leaves plenty of room for other applications and real production logs.

## Monitoring Splunk Usage

### Check Daily Volume in Splunk

```spl
index=_internal source=*license_usage.log type="Usage"
| eval GB=b/1024/1024/1024
| timechart span=1d sum(GB) as "Daily GB"
```

### Check Volume by Sourcetype

```spl
index=_internal source=*license_usage.log type="Usage"
| eval GB=b/1024/1024/1024
| stats sum(GB) as "Total GB" by st
| sort -"Total GB"
```

### Check This App's Volume

```spl
index=main sourcetype="python:app"
| eval size=len(_raw)
| stats sum(size) as total_bytes count as log_count
| eval MB=round(total_bytes/1024/1024,2)
| eval daily_MB=MB * (86400 / (now() - _index_earliest))
| table log_count MB daily_MB
```

## Recommendations for 5 GB/day Limit

### For Testing/Development
```bash
# More frequent logs for testing
LOG_INTERVAL_SECONDS=10 ./run-splunkcloud.sh
```

### For Production with Single App
```bash
# Conservative - 30 second interval
LOG_INTERVAL_SECONDS=30 ./run-splunkcloud.sh
```

### For Production with Multiple Apps
```bash
# Very conservative - 2 minute interval
LOG_INTERVAL_SECONDS=120 ./run-splunkcloud.sh
```

### For Quiet Production (minimal logging)
```bash
# 5 minute interval - very quiet
LOG_INTERVAL_SECONDS=300 ./run-splunkcloud.sh
```

## Real-time Volume Reporting

When the app starts, it reports estimated volume:

```
2025-11-12 14:51:17 - MyApp - INFO - Log generation interval: 30 seconds
2025-11-12 14:51:17 - MyApp - INFO - Estimated daily logs: ~2,880
2025-11-12 14:51:17 - MyApp - INFO - Estimated daily volume: ~0.50 MB
```

## Adjusting Based on Actual Usage

### Step 1: Deploy with Default (30 sec)
```bash
./build-splunkcloud.sh
./run-splunkcloud.sh
```

### Step 2: Monitor for 24 Hours

Check Splunk UI for actual volume.

### Step 3: Adjust if Needed

If approaching 5 GB limit, increase the interval:
```bash
docker stop splunk-forwarder
docker rm splunk-forwarder

# Double the interval (slower logs)
LOG_INTERVAL_SECONDS=60 ./run-splunkcloud.sh
```

## Setting Splunk Alerts for Volume

Create an alert in Splunk to warn when approaching limit:

```spl
index=_internal source=*license_usage.log type="Usage"
| eval GB=b/1024/1024/1024
| stats sum(GB) as daily_GB
| where daily_GB > 4
| eval message="Warning: Daily volume at ".round(daily_GB,2)." GB (80% of 5 GB limit)"
```

Alert conditions:
- **Warning at 4 GB** (80% of limit)
- **Critical at 4.5 GB** (90% of limit)

## Cost-Saving Tips

1. **Use Sampling**: Only forward a percentage of logs
2. **Filter Noisy Logs**: Exclude DEBUG/TRACE in production
3. **Compress Before Send**: Splunk UF compression is enabled
4. **Index Wisely**: Use summary indexes for aggregations
5. **Set Retention**: Archive old data to cold storage

## Example: Production Setup

```bash
# Build once
./build-splunkcloud.sh

# Run with 2-minute interval (conservative for production)
LOG_INTERVAL_SECONDS=120 ./run-splunkcloud.sh
```

This gives you:
- 720 logs/day per app
- ~0.12 MB/day per app
- Capacity for 41,000+ similar apps within 5 GB limit

## Need More Logs?

If you need more frequent logs but are hitting the limit:

1. **Filter in inputs.conf**: Only send ERROR/WARNING logs
2. **Sampling**: Send every Nth log
3. **Upgrade Splunk**: Increase daily limit
4. **Alternative**: Use OTEL to split to multiple destinations

## Questions?

- Check current container setting:
  ```bash
  docker logs splunk-forwarder 2>&1 | grep "Log generation interval"
  ```

- See actual log rate:
  ```bash
  docker exec splunk-forwarder tail -f /var/log/myapp/application.log
  ```

