# Phase 4 - Deploy to x86_64 Environment

## Prerequisites

✅ **ECR Images Ready**:
```
104013952213.dkr.ecr.us-east-1.amazonaws.com/splunk-phase4-app:latest
104013952213.dkr.ecr.us-east-1.amazonaws.com/splunk-phase4-forwarder:latest
```

✅ **Coralogix**: Working (already verified)  
⚠️ **Splunk Cloud**: Requires TCP port 9997 to be enabled

---

## Step 1: Enable TCP Port 9997 in Splunk Cloud

**CRITICAL**: Must be done BEFORE deployment!

### Method A: Via Splunk Cloud UI

1. Log in to Splunk Cloud
2. Go to **Settings → Forwarding and receiving**
3. Click **Configure receiving** (or **Receive data**)
4. Add new receiving port: **9997**
5. Click **Save**

### Method B: Via Splunk Cloud Support

If you don't see TCP input options:
- Contact Splunk Cloud support
- Request: "Enable TCP input on port 9997 for Universal Forwarder"
- Provide your Splunk Cloud URL

### Verify TCP is Enabled

You should see port 9997 listening at:
```
your-instance.splunkcloud.com:9997
```

---

## Step 2: Deploy to x86_64 Host

Choose your deployment method:

### Option A: EC2 (x86_64)

1. Launch EC2 instance (Amazon Linux 2 or Ubuntu, **x86_64**)
2. SSH into instance
3. Install Docker and Docker Compose
4. Copy deployment files
5. Run deployment script

### Option B: ECS/Fargate

1. Create task definition from `docker-compose.ecr.yaml`
2. Ensure **x86_64** architecture selected
3. Deploy task

### Option C: EKS

1. Create Kubernetes manifests from `docker-compose.ecr.yaml`
2. Deploy to **x86_64** node pool
3. Use provided Helm chart (optional)

---

## Step 3: Deploy on EC2 (Detailed Steps)

### 3.1 Launch EC2 Instance

```bash
# Launch x86_64 instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --key-name your-key \
  --security-group-ids sg-xxxxx \
  --subnet-id subnet-xxxxx \
  --iam-instance-profile Name=your-ecr-access-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=phase4-test}]'
```

### 3.2 Connect and Setup

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@<instance-ip>

# Install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for docker group to take effect
exit
```

### 3.3 Transfer Deployment Files

From your local machine:

```bash
# Create deployment package
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase4
tar czf phase4-deploy.tar.gz \
  docker-compose.ecr.yaml \
  otel-collector-config.yaml \
  deploy-on-ec2.sh

# Copy to EC2
scp -i your-key.pem phase4-deploy.tar.gz ec2-user@<instance-ip>:~
```

### 3.4 Deploy on EC2

On EC2 instance:

```bash
# Extract files
tar xzf phase4-deploy.tar.gz

# Run deployment script
./deploy-on-ec2.sh
```

---

## Step 4: Verify Deployment

### Check Containers

```bash
docker compose -f docker-compose.ecr.yaml ps
```

Expected output:
```
NAME                      STATUS
python-app-phase4         Up
splunk-forwarder-phase4   Up
otel-collector-phase4     Up
```

### Check Logs

```bash
# App logs
docker logs python-app-phase4

# Splunk UF logs (should see "Forwarding to..." messages)
docker logs splunk-forwarder-phase4 | grep -i "forward\|connect"

# OTEL logs (should see no errors)
docker logs otel-collector-phase4 | grep -i "error"
```

### Verify in Splunk

Search:
```
index=main sourcetype="python:phase4"
```

You should see logs with:
- RequestID: 1, 2, 3, etc.
- sourcetype="python:phase4"
- source="phase4-app"

### Verify in Coralogix

Filter:
```
applicationName:"MyApp-Phase4"
```

You should see the **SAME logs** (same RequestIDs) as in Splunk!

---

## Troubleshooting

### Splunk UF Not Forwarding

**Check connection to Splunk Cloud:**
```bash
docker exec splunk-forwarder-phase4 /opt/splunkforwarder/bin/splunk list forward-server
```

**Expected output:**
```
Active forwards:
	your-instance.splunkcloud.com:9997
```

**If connection fails:**
1. Verify port 9997 is enabled in Splunk Cloud
2. Check security group allows outbound to port 9997
3. Check Splunk UF logs:
```bash
docker exec splunk-forwarder-phase4 tail -f /opt/splunkforwarder/var/log/splunk/splunkd.log
```

### No Logs in Splunk

1. **Check if logs are being generated:**
```bash
docker exec python-app-phase4 cat /var/log/myapp/application.log
```

2. **Check if Splunk UF is reading the file:**
```bash
docker exec splunk-forwarder-phase4 /opt/splunkforwarder/bin/splunk list inputstatus
```

3. **Check Splunk UF internal logs:**
```bash
docker exec splunk-forwarder-phase4 tail -f /opt/splunkforwarder/var/log/splunk/splunkd.log | grep -i "monitor\|input"
```

### OTEL Not Sending to Coralogix

Check OTEL logs for errors:
```bash
docker logs otel-collector-phase4 2>&1 | grep -i "error\|fail"
```

---

## Architecture on x86_64

```
┌──────────────────────────────────────┐
│  EC2 Instance (x86_64)               │
│                                      │
│  ┌────────────────┐                  │
│  │  Python App    │                  │
│  │  (container)   │                  │
│  └───────┬────────┘                  │
│          │                           │
│          │ writes to file            │
│          ▼                           │
│  ┌──────────────────┐                │
│  │  /var/log/myapp/ │                │
│  │  application.log │                │
│  │  (shared volume) │                │
│  └────┬──────────┬───┘                │
│       │          │                   │
│       │          │                   │
│       ▼          ▼                   │
│  ┌────────┐  ┌──────────┐           │
│  │ Splunk │  │   OTEL   │           │
│  │   UF   │  │Collector │           │
│  │(x86_64)│  │          │           │
│  └────┬───┘  └────┬─────┘           │
│       │           │                  │
└───────┼───────────┼──────────────────┘
        │           │
        │           │ HTTPS
        │ TCP       │
        │ 9997      │
        ▼           ▼
   ┌────────┐  ┌──────────┐
   │ Splunk │  │Coralogix │
   │ Cloud  │  │          │
   └────────┘  └──────────┘
```

---

## Next Steps After Deployment

1. ✅ Verify logs in Splunk
2. ✅ Verify logs in Coralogix
3. ✅ Compare RequestIDs (should match!)
4. 📊 Monitor for 24 hours
5. 🚀 Move to production

---

## Production Deployment

For production, consider:

1. **High Availability**:
   - Multiple EC2 instances with load balancer
   - Or use ECS with multiple tasks
   - Or use EKS with multiple replicas

2. **Monitoring**:
   - CloudWatch for EC2/ECS metrics
   - OTEL metrics endpoint: http://localhost:8898/metrics
   - Splunk internal logs for UF status

3. **Security**:
   - Use IAM roles for ECR access (no credentials)
   - Use secrets manager for Coralogix keys
   - Restrict security groups

4. **Scaling**:
   - Scale app containers as needed
   - One Splunk UF + OTEL per app instance
   - Shared volume per app instance

---

## Summary

✅ ECR images ready: `104013952213.dkr.ecr.us-east-1.amazonaws.com`  
✅ Deploy to x86_64 (EC2/ECS/EKS)  
⚠️ **Critical**: Enable TCP port 9997 in Splunk Cloud FIRST  
✅ Use `deploy-on-ec2.sh` for easy deployment  
✅ Verify logs in both Splunk and Coralogix  

The x86_64 deployment will work perfectly! The ARM Mac limitation is only for local testing.

