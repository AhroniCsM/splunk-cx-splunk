# Quick Deploy Instructions

## 1. Update EC2 OTEL (First!)

SSH to your EC2 (YOUR_OTEL_IP) and update OTEL config:

```bash
# Replace your current config with ec2-otel-tcplog-config.yaml
# Key changes:
#   - Use tcplog receiver instead of splunk_hec
#   - Listen on port 9997
#   - Forward to Splunk + Coralogix

# Restart OTEL
docker restart otel-collector-ec2
# or
sudo systemctl restart otel-collector
```

## 2. Open Port 9997 on EC2

```bash
# Update Security Group
aws ec2 authorize-security-group-ingress \
  --group-id <your-sg-id> \
  --protocol tcp \
  --port 9997 \
  --cidr 0.0.0.0/0
```

## 3. Push to ECR

```bash
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase6
./push-to-ecr.sh
```

## 4. Deploy to K8s

```bash
kubectl apply -f k8s/deployment.yaml
```

## 5. Verify

```bash
# Check pods
kubectl get pods -l app=splunk-phase6

# Check logs
kubectl logs -l app=splunk-phase6 -c app --tail=20
kubectl logs -l app=splunk-phase6 -c splunk-forwarder --tail=20

# Check EC2 OTEL (SSH to EC2)
docker logs -f otel-collector-ec2
```

## 6. Check Destinations

- **Splunk**: `index=main sourcetype="python:phase6:k8s"`
- **Coralogix**: `applicationName:"k8s-phase6-tcp"`

---

## Full Command Sequence

```bash
# 1. Update EC2 OTEL config (manual step - SSH to EC2)
# 2. Open EC2 port 9997
# 3. Push images
cd /Users/aharon.shahar/Desktop/tasks/Splunk-cx-phase6
./push-to-ecr.sh

# 4. Deploy
kubectl apply -f k8s/deployment.yaml

# 5. Watch deployment
kubectl get pods -l app=splunk-phase6 -w

# 6. Check logs
kubectl logs -l app=splunk-phase6 -c splunk-forwarder -f
```

Done! 🚀

