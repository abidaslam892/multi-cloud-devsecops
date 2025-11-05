# Multi-Cloud DevSecOps Platform

A comprehensive DevSecOps platform deploying FastAPI applications across AWS EKS and Azure AKS with full CI/CD, security scanning, and observability.

## 🚀 Quick Start

### Prerequisites

- Docker
- kubectl
- Helm 3
- Terraform (for infrastructure)
- AWS CLI (for AWS deployment)
- Azure CLI (for Azure deployment)

### Local Development

1. **Install dependencies:**
```bash
cd app
pip install -r requirements.txt
```

2. **Run the application:**
```bash
python src/main.py
```

3. **Run tests:**
```bash
pytest tests/ -v
```

4. **Build Docker image:**
```bash
docker build -t multi-cloud-app:local .
```

5. **Run container:**
```bash
docker run -p 8000:80 multi-cloud-app:local
```

Access the API at: http://localhost:8000

## 🔐 GitHub Secrets Configuration

Before running CI/CD workflows, configure these GitHub Secrets in your repository settings (`Settings > Secrets and variables > Actions > New repository secret`):

### Required for AWS Deployment

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | `xxxxxxxxxxxxx` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `xxxxxxxxxxxxxxxx` |
| `AWS_REGION` | AWS region for deployment | `xxxxxxxxxx` |
| `ECR_REGISTRY` | ECR registry URL | `xxxxxxxxxxxxxxx |
| `ECR_REPO` | ECR repository name | `multi-cloud-devsecops` |
| `EKS_CLUSTER_NAME` | EKS cluster name | `multi-cloud-eks-dev` |

### Required for Azure Deployment

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CREDENTIALS` | Azure service principal JSON | `{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `ACR_NAME` | Azure Container Registry name | `multiclouddevsecopsacr` |
| `ACR_LOGIN_SERVER` | ACR login server | `multiclouddevsecopsacr.azurecr.io` |
| `ACR_REPO` | ACR repository name | `multi-cloud-app` |
| `AKS_RESOURCE_GROUP` | AKS resource group | `multi-cloud-rg` |
| `AKS_CLUSTER_NAME` | AKS cluster name | `multi-cloud-aks-dev` |

### Optional Secrets

| Secret Name | Description | When to Use |
|-------------|-------------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username | If pushing to Docker Hub |
| `DOCKERHUB_TOKEN` | Docker Hub access token | If pushing to Docker Hub |
| `SONAR_TOKEN` | SonarQube token | If using SonarQube analysis |
| `SONAR_HOST_URL` | SonarQube server URL | If using SonarQube analysis |

### How to Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

Copy the JSON output to `AZURE_CREDENTIALS` secret.

### How to Get ECR Registry URL

```bash
aws ecr describe-repositories --repository-names multi-cloud-devsecops --query 'repositories[0].repositoryUri' --output text
```

## 📁 Project Structure

```
.
├── app/                      # FastAPI application
│   ├── src/
│   │   └── main.py          # Application entry point
│   ├── tests/
│   │   └── test_basic.py    # Unit tests
│   ├── Dockerfile           # Multi-stage build
│   └── requirements.txt     # Python dependencies
├── .github/workflows/       # CI/CD pipelines
│   ├── ci.yaml             # Build, test, scan
│   ├── cd-aws.yaml         # Deploy to AWS EKS
│   └── cd-azure.yaml       # Deploy to Azure AKS
├── terraform/              # Infrastructure as Code
│   ├── aws/                # AWS resources
│   ├── azure/              # Azure resources
│   ├── modules/            # Reusable modules
│   └── backends/           # State backends
├── helm/                   # Kubernetes deployment
│   ├── chart/              # Helm chart
│   ├── values-dev.yaml     # Dev environment
│   ├── values-stage.yaml   # Staging environment
│   └── values-prod.yaml    # Production environment
├── monitoring/             # Observability
│   ├── prometheus-values.yaml
│   ├── grafana-values.yaml
│   ├── loki-values.yaml
│   └── grafana/dashboards/
├── scripts/                # Helper scripts
│   ├── login_ecr.sh
│   ├── login_acr.sh
│   ├── get_eks_kubeconfig.sh
│   └── get_aks_kubeconfig.sh
└── docs/                   # Documentation
    ├── roadmap.md
    └── monitoring-setup.md
```

## 🔄 CI/CD Workflows

### CI Pipeline (`.github/workflows/ci.yaml`)

Triggers on: Push and Pull Requests to `main` and `dev` branches

Steps:
1. Run unit tests with pytest
2. Build Docker image
3. Scan container with Trivy
4. Scan Terraform with Checkov
5. (Optional) SonarQube code analysis

### CD Pipeline - AWS (`.github/workflows/cd-aws.yaml`)

Triggers on: Push to `main` branch

Steps:
1. Authenticate to AWS
2. Build and push image to ECR
3. Update kubeconfig for EKS
4. Deploy to EKS using Helm

### CD Pipeline - Azure (`.github/workflows/cd-azure.yaml`)

Triggers on: Push to `main` branch

Steps:
1. Authenticate to Azure
2. Build and push image to ACR
3. Get AKS credentials
4. Deploy to AKS using Helm

## 🛠️ Infrastructure Deployment

### AWS Infrastructure

```bash
cd terraform/aws
terraform init -backend-config=../backends/s3.tf
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### Azure Infrastructure

```bash
cd terraform/azure
terraform init -backend-config=../backends/azurerm.tf
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## 📊 Monitoring

Install the monitoring stack (Prometheus + Grafana + Loki):

```bash
./monitoring/install-monitoring.sh dev --minimal
```

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Default credentials: `admin` / `admin`

## 🔒 Security Features

- **Container Scanning**: Trivy scans all images for vulnerabilities
- **IaC Scanning**: Checkov validates Terraform configurations
- **Code Quality**: SonarQube static analysis (optional)
- **Secrets Management**: GitHub Secrets for sensitive data
- **Network Policies**: Pod-to-pod communication controls
- **RBAC**: Role-based access control on clusters

## 🎯 API Endpoints

- `GET /` - Root endpoint
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `GET /items/{item_id}` - Get item by ID
- `POST /items` - Create new item

## 📚 Documentation

- [Implementation Roadmap](docs/roadmap.md)
- [Monitoring Setup Guide](docs/monitoring-setup.md)
- [Copilot Instructions](.github/copilot-instructions.md)

## 🧪 Testing

Run tests locally:
```bash
cd app
pytest tests/ -v --cov=src
```

## 📦 Deployment

### Deploy to Dev Environment

```bash
# AWS
helm upgrade --install multi-cloud-app helm/chart \
  -f helm/values-dev.yaml \
  --set image.repository=$ECR_REGISTRY/$ECR_REPO \
  --set image.tag=latest \
  --namespace dev --create-namespace

# Azure
helm upgrade --install multi-cloud-app helm/chart \
  -f helm/values-dev.yaml \
  --set image.repository=$ACR_LOGIN_SERVER/$ACR_REPO \
  --set image.tag=latest \
  --namespace dev --create-namespace
```

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Run tests: `pytest tests/`
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues and questions:
- Check the [documentation](docs/)
- Review [monitoring setup](docs/monitoring-setup.md)
- Consult the [roadmap](docs/roadmap.md)
