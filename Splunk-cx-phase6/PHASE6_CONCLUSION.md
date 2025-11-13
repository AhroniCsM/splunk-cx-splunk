# Phase 6 - TCP to OTEL: Conclusion

## Experiment Result: ❌ NOT VIABLE

### What We Tested
- Splunk Universal Forwarder sending via TCP (Splunk proprietary protocol)
- EC2 OTEL Collector with `tcplog` receiver on port 9997
- OTEL forwarding to both Splunk Cloud and Coralogix

### What Happened
✅ **Connectivity worked**: K8s pod → EC2:9997 connection established  
✅ **Data received**: OTEL tcplog receiver received TCP data  
✅ **Forwarding worked**: Data appeared in both Splunk and Coralogix  

❌ **Protocol parsing FAILED**: Logs appeared as raw protocol headers instead of actual log content

### Example of Corrupted Logs
```
--splunk-cooked-mode-v3--splunk-phase6-official-7dc4845cf-7d5zk8089@__s2s_capabilitiesack=0;compression=0_raw
host = unknown
source = k8s-phase6-tcp
sourcetype = python:phase6:k8s
```

**Missing**: The actual log messages (RequestID, Method, Endpoint, Status, etc.)

### Root Cause
The OTEL `tcplog` receiver is a **generic TCP receiver** that treats incoming data as plain text or simple formats. It **cannot parse Splunk's proprietary "cooked mode" TCP protocol**, which includes:
- Binary protocol headers
- Metadata encoding
- Message framing
- Compression flags

The receiver just dumps the raw protocol bytes as text, resulting in corrupted logs.

### Why This Matters
For customers, this means:
- ❌ Phase 6 (TCP → OTEL) does not provide usable logs
- ❌ The `tcplog` receiver is not a replacement for Splunk indexers
- ❌ OTEL cannot natively receive Splunk UF TCP forwarding

---

## ✅ RECOMMENDED SOLUTION: Phase 4 (HEC)

### Architecture
```
Splunk UF → HEC (HTTP) → EC2 OTEL → Splunk Cloud + Coralogix
            Port 8088      splunk_hec receiver
```

### Why Phase 4 Works
✅ **HEC is an open HTTP protocol**: Well-documented JSON format  
✅ **OTEL has native support**: `splunk_hec` receiver properly parses HEC  
✅ **Clean logs**: Full log content preserved  
✅ **Tested successfully**: We validated this in Phase 4  

### Customer Change Required
**Single line** in `outputs.conf`:

**Before (TCP):**
```ini
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = splunk-indexer:9997
```

**After (HEC):**
```ini
[splunk_hec://hec_output]
uri = http://otel-collector:8088/services/collector
token = <any-token>
index = main
sourcetype = <your-sourcetype>
source = <your-source>
```

### Benefits
1. **Minimal customer change**: One configuration block
2. **Fully supported**: Both by Splunk and OTEL
3. **Clean logs**: Proper parsing and formatting
4. **Dual destination**: Forwards to Splunk Cloud AND Coralogix

---

## Alternative: Phase 5 (Dual Path)

If customer **must** use TCP to Splunk Cloud:

```
Splunk UF → TCP:9997 → Splunk Cloud ✅
            
App writes → File → OTEL filelog → Coralogix ✅
```

**Trade-off**: Requires OTEL to read from the same file (file-based integration)

---

## Summary

| Phase | Protocol | OTEL Receiver | Result | Recommendation |
|-------|----------|---------------|---------|----------------|
| Phase 4 | HEC | `splunk_hec` | ✅ Clean logs | **USE THIS** |
| Phase 5 | TCP + File | N/A + `filelog` | ✅ Works | Alternative |
| Phase 6 | TCP | `tcplog` | ❌ Corrupted | **DO NOT USE** |

---

## Next Steps

**For Production**: Deploy Phase 4
1. Customer updates `outputs.conf` to use HEC
2. Points to EC2 OTEL collector (port 8088)
3. OTEL forwards to both destinations
4. **Result**: Clean, identical logs in Splunk Cloud and Coralogix

**Documentation**: Provide customer with:
- Simple `outputs.conf` example
- EC2 OTEL endpoint (IP:8088)
- HEC token (can be any value for OTEL)
- One-page "How to Change Endpoint" guide

---

## Lessons Learned

1. **Splunk's TCP protocol is proprietary**: Not compatible with generic TCP receivers
2. **HEC is the standard**: Open, documented, widely supported
3. **OTEL has excellent Splunk support**: Via `splunk_hec` receiver
4. **Customer impact is minimal**: One config change, same functionality
5. **Testing was valuable**: Confirmed Phase 6 doesn't work before production

**Conclusion**: Phase 4 (HEC) is the correct, production-ready solution for dual-destination forwarding from Splunk Universal Forwarder through OTEL.

