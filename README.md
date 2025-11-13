# Splunk to OTEL Integration - Complete Guide

This repository contains 6 different integration patterns for sending logs from applications to Splunk Cloud and/or Coralogix using OpenTelemetry.

## Quick Overview

| Phase | Name | Protocol | OTEL Routing | Customer Change |
|-------|------|----------|--------------|-----------------|
| **Phase 1** | Direct HEC to Splunk | HEC | No | - |
| **Phase 2** | Dual Shipper (File-Based) | HEC + File | Partial | Application code - configure otel|
| **Phase 3** | Central HEC Routing | HEC | Yes | **Endpoint only** |
| **Phase 4** | Splunk UF via HEC | HEC | Yes | **Endpoint only** |
| **Phase 5** | Independent Dual Paths | TCP + File | Partial | Endpoint only |
| **Phase 6** | **Splunk UF RAW TCP** ⭐ | **TCP (RAW)** | **Yes** | **Endpoint only** |

---

## Phase Architectures

### Phase 1: Direct HEC to Splunk
```
┌─────────────┐
│   Python    │
│     App     │
└──────┬──────┘
       │ HEC
       │ (HTTP)
       ↓
┌─────────────┐
│   Splunk    │
│    Cloud    │
└─────────────┘
```
**Goal**: Send logs directly from application to Splunk Cloud using HEC.

**Use When:**
- Simple testing or small deployments
- Can modify application code
- No need for additional infrastructure

[📖 Full Documentation](./Splunk-cx-phase1/README.md)

---

### Phase 2: Dual Shipper (File-Based)
```
                        ┌──────────────┐
                   ┌───→│ Python HEC   │──→ Splunk Cloud
                   │    │   Shipper    │
┌─────────────┐    │    └──────────────┘
│   Python    │    │
│     App     │────┤
│ (Logs only) │    │    ┌──────────────┐
└─────────────┘    └───→│     OTEL     │──→ Coralogix
                        │  Collector   │
      Writes to         └──────────────┘
      shared file
    (same RequestID)
```
**Goal**: Send the **same logs** to both Splunk and Coralogix from a single application.

**Use When:**
- Need identical logs in both destinations
- Want independent shippers for reliability
- Okay with file-based approach

[📖 Full Documentation](./Splunk-cx-phase2/README.md)

---

### Phase 3: Central HEC Routing
```
┌─────────────┐      HEC       ┌──────────────┐
│   Python    │   (HTTP)       │     OTEL     │──→ Splunk Cloud
│     App     │───────────────→│  Collector   │
│  (with HEC) │  Port 8088     │  (Central)   │──→ Coralogix
└─────────────┘                └──────────────┘
                                      ↑
                  Customer only changes endpoint here!
```
**Goal**: Application sends HEC to OTEL Collector, which forwards to both Splunk and Coralogix.

**Use When:**
- **Minimal customer changes** (only endpoint!)
- Want central routing and management
- Need to add/remove destinations easily
- Migrating from Splunk-only to multi-destination

**Customer Change Required:**
```python
# Just change the endpoint!
SPLUNK_HEC_URL = "http://YOUR_OTEL_IP:8088"
```

[📖 Full Documentation](./Splunk-cx-phase3/README.md)

---

### Phase 4: Splunk UF via HEC
```
┌─────────────┐                ┌──────────────┐
│   Python    │  Writes to     │   Splunk     │      HEC       ┌──────────────┐
│     App     │──→ log file ──→│  Universal   │───────────────→│     OTEL     │──→ Splunk Cloud
│ (Logs only) │                │  Forwarder   │   Port 8088    │  Collector   │
└─────────────┘                └──────────────┘                └──────────────┘──→ Coralogix
                                      ↑
                          Customer only changes outputs.conf!
```
**Goal**: Use Splunk UF to read logs and send via HEC to OTEL Collector.

**Use When:**
- Customer already uses Splunk Universal Forwarder
- Want to leverage existing Splunk infrastructure
- **Customer only changes UF configuration** (one file!)

**Customer Change Required:**
```ini
# outputs.conf - just change the endpoint!
[splunk_hec://hec_output]
uri = http://YOUR_OTEL_IP:8088/services/collector
```

[📖 Full Documentation](./Splunk-cx-phase4/README.md)

---

### Phase 5: Independent Dual Paths - TCP
```
                                ┌──────────────┐    TCP
                           ┌───→│   Splunk     │──────────→ Splunk Cloud
                           │    │  Universal   │  Port 9997
┌─────────────┐            │    │  Forwarder   │
│   Python    │  Writes to │    └──────────────┘
│     App     │──→ log file┤
│ (Logs only) │            │    ┌──────────────┐
└─────────────┘            └───→│     OTEL     │──────────→ Coralogix
                                │  Collector   │
                                └──────────────┘

                           Independent paths (no central routing)
```
**Goal**: Send logs to Splunk via native TCP AND to Coralogix via OTEL (independent paths).

**Use When:**
- Must use Splunk's native TCP protocol (port 9997)
- Want independent paths (if one fails, other continues)
- Splunk Cloud allows TCP inputs

**Note:** This phase has independent data paths - not centrally routed.

[📖 Full Documentation](./Splunk-cx-phase5/README.md)

---

### Phase 6: Splunk UF RAW TCP 
```
┌─────────────┐                ┌──────────────┐     RAW TCP    ┌──────────────┐
│   Python    │  Writes to     │   Splunk     │  (Plain Text)  │     OTEL     │──→ Splunk Cloud
│     App     │──→ log file ──→│  Universal   │───────────────→│  Collector   │
│ (Logs only) │                │  Forwarder   │   Port 9997    │  (Central)   │──→ Coralogix
└─────────────┘                └──────────────┘                └──────────────┘
                                      ↑
                            sendCookedData=false
                         (Makes TCP work with OTEL!)
```
**Goal**: Use Splunk UF with RAW TCP mode to send to OTEL Collector, which forwards to both destinations.

**Use When:**
- ✅ **Customer prefers TCP protocol** (industry standard)
- ✅ Want **central OTEL routing** to multiple destinations
- ✅ **Customer only changes one line** in Splunk UF config
- ✅ Need logs processed/enriched by OTEL

**The Key:** `sendCookedData=false` makes Splunk UF send plain text instead of binary protocol!

**Customer Change Required:**
```ini
# outputs.conf - add ONE setting!
[tcpout:otel_tcp]
server = YOUR_OTEL_IP:9997
sendCookedData = false  ← This makes it work with OTEL!
```

[📖 Full Documentation](./Splunk-cx-phase6/README.md)

---

## Decision Matrix

### Choose Phase 1 if:
- ❌ No OTEL infrastructure needed
- ❌ Splunk only (no Coralogix)
- ✅ Simple testing
- ✅ Can modify application

### Choose Phase 2 if:
- ✅ Need logs in both Splunk AND Coralogix
- ✅ Want identical logs with same RequestIDs
- ✅ Prefer file-based reliability
- ❌ No central routing

### Choose Phase 3 if:
- ✅ **Minimal customer changes** (endpoint only!)
- ✅ Customer uses HEC currently
- ✅ Want central routing via OTEL
- ✅ Easy to add more destinations
- ⚠️ Requires disabling Splunk Indexer Acknowledgment

### Choose Phase 4 if:
- ✅ Customer uses Splunk Universal Forwarder
- ✅ Customer comfortable with HEC
- ✅ Want central OTEL routing
- ✅ Customer only changes UF outputs.conf
- ⚠️ Requires x86_64 architecture for Splunk UF

### Choose Phase 5 if:
- ✅ Must use Splunk native TCP (port 9997)
- ✅ Want independent paths (no single point of failure)
- ✅ Splunk Cloud allows TCP inputs
- ❌ No central routing (separate paths)

### Choose Phase 6 if: ⭐
- ✅ **Customer prefers TCP protocol**
- ✅ Want **central OTEL routing**
- ✅ **Minimal config change** (one line!)
- ✅ Comfortable with `sendCookedData=false`
- ✅ **Best of both worlds**: Splunk familiarity + OTEL flexibility

## Common Prerequisites

All phases require:
- Docker installed (for local testing)
- Splunk Cloud account with HEC token
- Coralogix account with private key (except Phase 1)

Some phases require:
- Kubernetes cluster (Phases 4, 5, 6 for production)
- x86_64 architecture (Phases 4, 5, 6 - for Splunk UF)
- OTEL Collector on EC2/remote server (Phases 3, 4, 6)

## Architecture Comparison

### Centralized Routing (Phases 3, 4, 6)
```
Application → OTEL Collector → ├─→ Splunk Cloud
                                └─→ Coralogix
```
**Benefits:**
- Add/remove destinations without touching application
- Central processing and enrichment
- Single configuration point

### Independent Paths (Phases 2, 5)
```
              ┌─→ Shipper 1 → Splunk Cloud
Application → File →
              └─→ Shipper 2 → Coralogix
```
**Benefits:**
- If one path fails, other continues
- No single point of failure
- Separate configurations

## Getting Started

1. **Review the Decision Matrix** above
2. **Choose the phase** that fits your requirements
3. **Read the phase-specific README** for detailed instructions
4. **Test locally** with Docker Compose
5. **Deploy to production** (Kubernetes or servers)

## Support and Documentation

- Each phase has its own detailed README
- Architecture diagrams included
- Step-by-step deployment instructions
- Troubleshooting sections
- Configuration examples

## Key Learnings

### Phase 6 Discovery: sendCookedData=false
The breakthrough for Phase 6 was discovering that Splunk UF's default "cooked mode" (binary protocol) doesn't work with OTEL. Setting `sendCookedData=false` makes it send plain text that OTEL can parse!

### Splunk Cloud HEC with OTEL (Phases 3, 4)
OTEL's `splunk_hec` exporter doesn't support the `X-Splunk-Request-Channel` header. Solution: Disable "Indexer Acknowledgment" in Splunk HEC token settings.

### Splunk Universal Forwarder Requirements
Splunk UF requires x86_64 architecture. It will build on ARM Macs but won't execute. Deploy to x86_64 Linux, Windows, or Kubernetes with x86_64 nodes.

## License

This is a reference implementation for customer integrations. Adapt as needed for your environment.
