# Complete Deployment Guide

This guide walks you through deploying the entire multi-cloud DevSecOps platform from scratch.

## Prerequisites Checklist

- [x] GitHub repository created
- [x] GitHub Secrets configured (AWS + Azure)
- [x] AWS CLI installed and configured
- [x] Azure CLI installed and authenticated
- [x] Terraform installed (>= 1.5.0)
- [x] kubectl installed
- [x] Helm installed (>= 3.0)
- [ ] AWS EKS cluster deployed
- [ ] Azure AKS cluster deployed

## Phase 1: Deploy AWS Infrastructure (~15-20 minutes)

### Step 1.1: Review Terraform Configuration

```bash
cd terraform/aws
cat variables.tf  # Review default values
```

### Step 1.2: Deploy AWS Infrastructure

```bash
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-aws-infrastructure.sh
```

This will:
- Create S3 bucket for Terraform state
- Create DynamoDB table for state locking
- Deploy VPC with public/private subnets across 3 AZs
- Deploy EKS cluster (version 1.28)
- Create ECR repository
- Set up IAM roles and security groups

**Expected time**: 15-20 minutes (EKS cluster creation is slow)

### Step 1.3: Verify AWS Deployment

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev

# Verify nodes
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

### Step 1.4: Update GitHub Secrets (if needed)

If you created a new ECR repository:

```bash
cd terraform/aws
ECR_URL=$(terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo $ECR_URL | cut -d'/' -f1)
ECR_REPO=$(echo $ECR_URL | cut -d'/' -f2)

gh secret set ECR_REGISTRY --body "$ECR_REGISTRY"
gh secret set ECR_REPO --body "$ECR_REPO"
```

## Phase 2: Deploy Azure Infrastructure (~15-20 minutes)

### Step 2.1: Review Terraform Configuration

```bash
cd terraform/azure
cat variables.tf  # Review default values
```

### Step 2.2: Deploy Azure Infrastructure

```bash
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-azure-infrastructure.sh
```

This will:
- Create Azure Storage for Terraform state
- Deploy Resource Group
- Deploy Virtual Network with subnets
- Deploy AKS cluster (version 1.28.3)
- Integrate with existing ACR
- Set up NSG and RBAC

**Expected time**: 15-20 minutes (AKS cluster creation is slow)

### Step 2.3: Verify Azure Deployment

```bash
# Configure kubectl for AKS
az aks get-credentials \
  --resource-group multi-cloud-devsecops-dev-rg \
  --name multi-cloud-devsecops-dev-aks

# Verify nodes
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-default-xxxxxxxx-vmss000000     Ready    agent   5m    v1.28.3
# aks-default-xxxxxxxx-vmss000001     Ready    agent   5m    v1.28.3
```

### Step 2.4: Update GitHub Secret

```bash
cd terraform/azure
AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)

gh secret set AKS_CLUSTER_NAME --body "$AKS_CLUSTER_NAME"
```

## Phase 3: Test CI/CD Pipeline

### Step 3.1: Trigger CI Pipeline

```bash
cd /home/abid/multi-cloud-devsecops

# Make a small change to trigger CI
echo "" >> README.md

git add .
git commit -m "Trigger CI/CD pipeline after infrastructure deployment"
git push origin main
```

### Step 3.2: Monitor CI Pipeline

Go to: https://github.com/abidaslam892/multi-cloud-devsecops/actions

**Expected workflow**:
1. **CI Workflow** (ci.yaml) - Runs on every push
   - ✅ Build and test Python app
   - ✅ Run pytest
   - ✅ Build Docker image
   - ✅ Scan with Trivy
   - ✅ Scan with Checkov
   - ✅ Push to ECR and ACR

2. **CD-AWS Workflow** (cd-aws.yaml) - Deploys to EKS
   - ✅ Login to AWS
   - ✅ Update kubeconfig
   - ✅ Deploy with Helm

3. **CD-Azure Workflow** (cd-azure.yaml) - Deploys to AKS
   - ✅ Login to Azure
   - ✅ Get AKS credentials
   - ✅ Deploy with Helm

## Phase 4: Verify Deployments

### Step 4.1: Verify AWS Deployment

```bash
# Switch to EKS context
kubectl config use-context arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/multi-cloud-devsecops-dev

# Check pods
kubectl get pods -n dev

# Check service
kubectl get svc -n dev

# Get application URL (if LoadBalancer)
kubectl get svc -n dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### Step 4.2: Verify Azure Deployment

```bash
# Switch to AKS context
kubectl config use-context multi-cloud-devsecops-dev-aks

# Check pods
kubectl get pods -n dev

# Check service
kubectl get svc -n dev

# Get application URL (if LoadBalancer)
kubectl get svc -n dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

### Step 4.3: Test Application Endpoints

```bash
# AWS
AWS_URL=$(kubectl get svc -n dev --context arn:aws:eks:... -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl http://$AWS_URL/health
curl http://$AWS_URL/

# Azure
AZURE_IP=$(kubectl get svc -n dev --context multi-cloud-devsecops-dev-aks -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
curl http://$AZURE_IP/health
curl http://$AZURE_IP/
```

## Phase 5: Deploy Monitoring Stack

### Step 5.1: Deploy Monitoring to AWS EKS

```bash
# Switch to EKS context
kubectl config use-context arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/multi-cloud-devsecops-dev

# Deploy monitoring stack
cd /home/abid/multi-cloud-devsecops/monitoring
./install-monitoring.sh

# Or use minimal version for dev
./install-monitoring.sh --minimal
```

### Step 5.2: Deploy Monitoring to Azure AKS

```bash
# Switch to AKS context
kubectl config use-context multi-cloud-devsecops-dev-aks

# Deploy monitoring stack
cd /home/abid/multi-cloud-devsecops/monitoring
./install-monitoring.sh --minimal
```

### Step 5.3: Access Grafana

```bash
# AWS EKS
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 --context arn:aws:eks:...

# Azure AKS
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80 --context multi-cloud-devsecops-dev-aks
```

Open browser:
- AWS Grafana: http://localhost:3000
- Azure Grafana: http://localhost:3001

**Default credentials**:
- Username: `admin`
- Password: Get with `kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode`

## Phase 6: Production Deployment (Optional)

### Step 6.1: Deploy Production Infrastructure

```bash
# AWS Production
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-aws-infrastructure.sh
# Choose "prod" when prompted

# Azure Production
./scripts/deploy-azure-infrastructure.sh
# Choose "prod" when prompted
```

### Step 6.2: Update Helm Values

Review and customize production values:
```bash
vim helm/values-prod.yaml
```

### Step 6.3: Manual Production Deployment

For production, use manual deployment with approvals:

```bash
# Deploy to AWS EKS Prod
helm upgrade --install app-prod ./helm/chart \
  -f helm/values-prod.yaml \
  -n prod \
  --create-namespace

# Deploy to Azure AKS Prod
kubectl config use-context multi-cloud-devsecops-prod-aks
helm upgrade --install app-prod ./helm/chart \
  -f helm/values-prod.yaml \
  -n prod \
  --create-namespace
```

## Troubleshooting

### Issue: Terraform state lock error

**Solution**:
```bash
# AWS
aws dynamodb delete-item \
  --table-name multi-cloud-devsecops-terraform-lock \
  --key '{"LockID":{"S":"LOCK_ID"}}'

# Azure
# Manually delete lease in Azure Portal
```

### Issue: kubectl context not found

**Solution**:
```bash
# AWS
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev

# Azure
az aks get-credentials --resource-group multi-cloud-devsecops-dev-rg --name multi-cloud-devsecops-dev-aks
```

### Issue: Helm deployment fails

**Solution**:
```bash
# Check current context
kubectl config current-context

# Check namespace exists
kubectl get namespaces

# Create namespace if missing
kubectl create namespace dev

# Check Helm releases
helm list -n dev
```

### Issue: CI/CD workflow fails

**Solution**:
1. Check GitHub Secrets are set correctly: https://github.com/abidaslam892/multi-cloud-devsecops/settings/secrets/actions
2. Check workflow logs in Actions tab
3. Verify AWS/Azure credentials are valid

## Cost Management

### Development Environment (Monthly Estimates)

**AWS**:
- EKS Cluster: $73/month (control plane)
- EC2 Instances (2x t3.medium): ~$60/month
- NAT Gateway: ~$32/month
- **Total**: ~$165/month

**Azure**:
- AKS Cluster: Free (control plane)
- VMs (2x Standard_D2s_v3): ~$140/month
- Load Balancer: ~$20/month
- **Total**: ~$160/month

**Combined**: ~$325/month

### Cost Optimization

```bash
# Stop dev environment when not in use
# AWS
terraform destroy -var="environment=dev" -auto-approve

# Azure
terraform destroy -var="environment=dev" -auto-approve
```

## Next Steps

1. ✅ Infrastructure deployed on both clouds
2. ✅ CI/CD pipeline running
3. ✅ Applications deployed to EKS and AKS
4. ✅ Monitoring stack installed
5. ⏭️ Set up custom alerts in Prometheus
6. ⏭️ Configure SSL/TLS certificates
7. ⏭️ Implement GitOps with ArgoCD (optional)
8. ⏭️ Set up disaster recovery procedures

## Summary

You now have:
- ✅ Multi-cloud infrastructure (AWS + Azure)
- ✅ Automated CI/CD pipelines
- ✅ Container orchestration with Kubernetes
- ✅ Monitoring and observability
- ✅ Security scanning (Trivy, Checkov)
- ✅ Infrastructure as Code (Terraform)
- ✅ Declarative deployments (Helm)

**Congratulations! Your multi-cloud DevSecOps platform is live! 🎉**
