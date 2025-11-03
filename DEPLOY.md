# Quick Start - Deploy Everything

This is a rapid deployment guide to get your multi-cloud platform running ASAP.

## Prerequisites (5 minutes)

```bash
# Verify all tools are installed
terraform --version  # Should be >= 1.5.0
aws --version        # AWS CLI installed
az --version         # Azure CLI installed
kubectl version --client
helm version

# Verify authentication
aws sts get-caller-identity  # Should show your AWS account
az account show              # Should show your Azure subscription

# Verify GitHub secrets
gh secret list  # Should show 12-13 secrets
```

## Option 1: Full Deployment (Both Clouds) - 45 minutes

### Deploy AWS Infrastructure (20 minutes)

```bash
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-aws-infrastructure.sh
```

When prompted:
- Environment: `dev` (press Enter)
- Review plan: `y`

### Deploy Azure Infrastructure (20 minutes)

```bash
./scripts/deploy-azure-infrastructure.sh
```

When prompted:
- Environment: `dev` (press Enter)
- Review plan: `y`

### Configure kubectl

```bash
# AWS EKS
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev

# Azure AKS  
az aks get-credentials --resource-group multi-cloud-devsecops-dev-rg --name multi-cloud-devsecops-dev-aks

# Verify
kubectl config get-contexts
```

### Trigger CI/CD Pipeline

```bash
# Make a change to trigger the pipeline
echo "# Deployment $(date)" >> README.md
git add README.md
git commit -m "Trigger deployment after infrastructure setup"
git push origin main
```

### Monitor Deployment

Go to: https://github.com/abidaslam892/multi-cloud-devsecops/actions

Wait for all workflows to complete (~10 minutes):
- ✅ CI Workflow (build, test, scan)
- ✅ CD-AWS Workflow (deploy to EKS)
- ✅ CD-Azure Workflow (deploy to AKS)

### Verify Applications

```bash
# AWS
kubectl get all -n dev --context arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/multi-cloud-devsecops-dev

# Azure
kubectl get all -n dev --context multi-cloud-devsecops-dev-aks

# Test endpoints
kubectl port-forward svc/app 8080:80 -n dev
curl http://localhost:8080/health
```

## Option 2: AWS Only - 25 minutes

```bash
# Deploy AWS infrastructure
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-aws-infrastructure.sh

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev

# Trigger deployment
git add .
git commit -m "Deploy to AWS"
git push origin main

# Verify
kubectl get pods -n dev
```

## Option 3: Azure Only - 25 minutes

```bash
# Deploy Azure infrastructure
cd /home/abid/multi-cloud-devsecops
./scripts/deploy-azure-infrastructure.sh

# Update GitHub secret
cd terraform/azure
gh secret set AKS_CLUSTER_NAME --body "$(terraform output -raw aks_cluster_name)"

# Configure kubectl
az aks get-credentials --resource-group multi-cloud-devsecops-dev-rg --name multi-cloud-devsecops-dev-aks

# Trigger deployment
git add .
git commit -m "Deploy to Azure"
git push origin main

# Verify
kubectl get pods -n dev
```

## Option 4: Manual Helm Deployment (Skip CI/CD)

If you want to deploy manually without waiting for GitHub Actions:

```bash
# Configure kubectl (choose one)
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev
# OR
az aks get-credentials --resource-group multi-cloud-devsecops-dev-rg --name multi-cloud-devsecops-dev-aks

# Build and push image manually
cd app
docker build -t myapp:latest .

# Push to ECR (AWS)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ECR_REGISTRY
docker tag myapp:latest ECR_REGISTRY/multi-cloud-devsecops:latest
docker push ECR_REGISTRY/multi-cloud-devsecops:latest

# OR Push to ACR (Azure)
az acr login --name multicloudacr93322
docker tag myapp:latest multicloudacr93322.azurecr.io/multi-cloud-devsecops:latest
docker push multicloudacr93322.azurecr.io/multi-cloud-devsecops:latest

# Deploy with Helm
cd ../helm
helm install app ./chart -f values-dev.yaml -n dev --create-namespace

# Verify
kubectl get all -n dev
```

## Add Monitoring (Optional) - 5 minutes

```bash
cd /home/abid/multi-cloud-devsecops/monitoring

# Minimal stack for dev (recommended)
./install-monitoring.sh --minimal

# Full stack for production
./install-monitoring.sh

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# User: admin
# Pass: $(kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)
```

## Cleanup (When Done Testing)

```bash
# Delete Kubernetes resources
helm uninstall app -n dev
kubectl delete namespace dev monitoring

# Destroy infrastructure
cd terraform/aws
terraform destroy -var="environment=dev" -auto-approve

cd ../azure
terraform destroy -var="environment=dev" -auto-approve
```

## Estimated Costs

**Running full dev environment (both clouds)**:
- AWS: ~$165/month (~$5.50/day)
- Azure: ~$160/month (~$5.30/day)
- **Total**: ~$325/month (~$11/day)

**Cost-saving tips**:
- Use Spot/Low-priority instances (already configured for dev)
- Destroy when not in use (terraform destroy)
- Use smaller instance types (already using smallest viable)

## Common Issues

### Terraform Error: "Error acquiring state lock"

```bash
# AWS
aws dynamodb delete-item --table-name multi-cloud-devsecops-terraform-lock --key '{"LockID":{"S":"multi-cloud-devsecops-terraform-state/aws/dev/terraform.tfstate"}}'

# Azure
# Go to Azure Portal > Storage Account > Containers > tfstate > Break lease
```

### kubectl: "The connection to the server was refused"

```bash
# Re-authenticate
aws eks update-kubeconfig --region us-east-1 --name multi-cloud-devsecops-dev
# OR
az aks get-credentials --resource-group multi-cloud-devsecops-dev-rg --name multi-cloud-devsecops-dev-aks
```

### CI/CD Pipeline Fails

1. Check secrets: `gh secret list`
2. Verify infrastructure is deployed: `kubectl get nodes`
3. Check workflow logs: https://github.com/abidaslam892/multi-cloud-devsecops/actions

## Next Steps After Deployment

1. ✅ Access application via LoadBalancer IP/hostname
2. ✅ View logs: `kubectl logs -f -n dev deployment/app`
3. ✅ Access Grafana dashboards
4. ✅ Test API endpoints
5. ⏭️ Set up custom domain with SSL
6. ⏭️ Configure production environment
7. ⏭️ Implement backup/disaster recovery

## Success Criteria

Your deployment is successful when:

- [ ] `kubectl get nodes` shows 2+ nodes in Ready state
- [ ] `kubectl get pods -n dev` shows app pod Running
- [ ] `curl http://LOADBALANCER_IP/health` returns HTTP 200
- [ ] Grafana shows metrics from your application
- [ ] GitHub Actions workflows show green checkmarks

**Ready to deploy? Start with Option 1 for the full experience!**
