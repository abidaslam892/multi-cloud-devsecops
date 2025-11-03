# Multi-Cloud DevSecOps - Access Guide

## 🎯 Application Access

### Azure AKS Deployment
**Application URL:** `http://52.186.101.70`

**Test Endpoints:**
```bash
# Health check
curl http://52.186.101.70/health

# Root endpoint
curl http://52.186.101.70/

# Get item
curl http://52.186.101.70/items/5

# Create item
curl -X POST http://52.186.101.70/items \
  -H "Content-Type: application/json" \
  -d '{"id": 10, "name": "my-item"}'
```

**Cluster:** `multi-cloud-devsecops-dev-aks`  
**Region:** East US  
**Nodes:** 1 (aks-default-23068998-vmss000000)  
**Status:** ✅ Running

---

### AWS EKS Deployment
**Application URL:** `http://a2f5a6578b9a34e5dac5bac56dd065f8-1159945048.us-east-1.elb.amazonaws.com`

**Test Endpoints:**
```bash
# Health check
curl http://a2f5a6578b9a34e5dac5bac56dd065f8-1159945048.us-east-1.elb.amazonaws.com/health

# Root endpoint
curl http://a2f5a6578b9a34e5dac5bac56dd065f8-1159945048.us-east-1.elb.amazonaws.com/

# Get item
curl http://a2f5a6578b9a34e5dac5bac56dd065f8-1159945048.us-east-1.elb.amazonaws.com/items/5

# Create item
curl -X POST http://a2f5a6578b9a34e5dac5bac56dd065f8-1159945048.us-east-1.elb.amazonaws.com/items \
  -H "Content-Type: application/json" \
  -d '{"id": 10, "name": "my-item"}'
```

**Cluster:** `mc-devsecops-dev`  
**Region:** us-east-1  
**Nodes:** 2 (ip-10-0-2-26, ip-10-0-3-254)  
**Status:** ✅ Running

---

## 📊 Monitoring Access

### Grafana (Azure AKS)
**Grafana URL:** `http://48.194.125.118`

**Credentials:**
- **Username:** `admin`
- **Password:** `admin`

**Access via Browser:**
```
http://48.194.125.118
```

**Pre-configured Dashboards:**
- Kubernetes cluster monitoring
- Node exporter metrics
- Application metrics (Prometheus)

---

## 🔧 Kubernetes Access

### Azure AKS
```bash
# Get kubeconfig
az aks get-credentials \
  --resource-group multi-cloud-devsecops-dev-rg \
  --name multi-cloud-devsecops-dev-aks

# Switch context
kubectl config use-context multi-cloud-devsecops-dev-aks

# View pods
kubectl get pods -n dev
kubectl get pods -n monitoring

# View services
kubectl get svc -n dev
kubectl get svc -n monitoring
```

### AWS EKS
```bash
# Get kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name mc-devsecops-dev

# Switch context
kubectl config use-context arn:aws:eks:us-east-1:912606813826:cluster/mc-devsecops-dev

# View pods
kubectl get pods -n dev

# View services
kubectl get svc -n dev
```

---

## 🐳 Container Registry Access

### Azure Container Registry (ACR)
**Registry:** `multiclouddevsecopsdevacr.azurecr.io`

```bash
# Login
az acr login --name multiclouddevsecopsdevacr

# View images
az acr repository list --name multiclouddevsecopsdevacr

# Pull image
docker pull multiclouddevsecopsdevacr.azurecr.io/multi-cloud-devsecops:v1.0.1
```

### AWS Elastic Container Registry (ECR)
**Registry:** `912606813826.dkr.ecr.us-east-1.amazonaws.com`

```bash
# Login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  912606813826.dkr.ecr.us-east-1.amazonaws.com

# View images
aws ecr list-images --repository-name mc-devsecops-dev --region us-east-1

# Pull image
docker pull 912606813826.dkr.ecr.us-east-1.amazonaws.com/mc-devsecops-dev:v1.0.1
```

---

## 🚀 CI/CD Pipeline

### GitHub Actions
**Repository:** https://github.com/abidaslam892/multi-cloud-devsecops

**Workflows:**
- **CI:** Builds, tests, and scans on every push to main/dev
- **CD-AWS:** Deploys to AWS EKS (triggered by CI success)
- **CD-Azure:** Deploys to Azure AKS (triggered by CI success)

**View Workflow Runs:**
```
https://github.com/abidaslam892/multi-cloud-devsecops/actions
```

**Trigger Manual Deployment:**
```bash
# Push to main branch
git push origin main

# CI will run automatically
# CD pipelines will deploy upon CI success
```

---

## 📝 Application Details

**Technology Stack:**
- **Framework:** FastAPI 0.95.2
- **Runtime:** Python 3.11
- **Server:** Uvicorn
- **Port:** 8080 (internal), 80 (LoadBalancer)

**API Endpoints:**
- `GET /` - Root endpoint with status
- `GET /health` - Health check endpoint
- `GET /metrics` - Prometheus metrics endpoint
- `GET /items/{item_id}` - Get item by ID
- `POST /items` - Create new item

---

## 🔍 Troubleshooting

### View Application Logs
```bash
# Azure AKS
kubectl config use-context multi-cloud-devsecops-dev-aks
kubectl logs -n dev -l app.kubernetes.io/name=multi-cloud-devsecops --tail=50

# AWS EKS
kubectl config use-context arn:aws:eks:us-east-1:912606813826:cluster/mc-devsecops-dev
kubectl logs -n dev -l app.kubernetes.io/name=multi-cloud-devsecops --tail=50
```

### Check Pod Status
```bash
# Get pod details
kubectl describe pod -n dev <pod-name>

# Get events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Restart Deployment
```bash
kubectl rollout restart deployment app-multi-cloud-devsecops -n dev
```

---

## 📈 Metrics and Monitoring

### Prometheus Queries (via Grafana)
```promql
# Request rate
rate(http_requests_total[5m])

# Pod CPU usage
container_cpu_usage_seconds_total{namespace="dev"}

# Pod memory usage
container_memory_usage_bytes{namespace="dev"}
```

### Access Prometheus Directly
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access at: http://localhost:9090
```

---

## 🔒 Security Notes

- All containers run as non-root users (UID: 1000)
- Read-only root filesystem enabled
- Pod Security Standards enforced
- Network policies can be added for additional security
- Secrets stored in GitHub Secrets (encrypted)
- Image scanning enabled with Trivy in CI pipeline

---

## 💰 Cost Optimization

**Azure AKS:**
- Using spot instances where possible
- Auto-scaling enabled (min: 1, max: 4)
- Using Standard_D2s_v3 VMs (cost-effective)

**AWS EKS:**
- Using spot instances for node group
- Auto-scaling enabled (min: 1, max: 4)
- Using t3.medium instances (cost-effective)

**Recommendations:**
- Stop/delete resources when not in use
- Monitor costs via Azure Cost Management and AWS Cost Explorer
- Consider using reserved instances for production

---

## 📞 Support

For issues or questions:
1. Check the logs using commands above
2. Review GitHub Actions workflow runs
3. Check Grafana dashboards for metrics
4. Review Kubernetes events for cluster issues

---

**Last Updated:** November 4, 2025
**Status:** ✅ All Systems Operational
