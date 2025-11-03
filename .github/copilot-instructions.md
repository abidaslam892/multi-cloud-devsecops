# Multi-Cloud DevSecOps Project - AI Agent Guide

## Project Architecture

This is a multi-cloud DevSecOps platform deploying a **Python-based microservice (FastAPI/Flask)** across AWS EKS and Azure AKS with security-first principles.

### Component Structure

```
app/                      - Python microservice (FastAPI)
  ├── src/                - Application source code
  │   └── main.py         - FastAPI application entry point
  ├── tests/              - pytest unit and integration tests
  ├── Dockerfile          - Multi-stage container build
  └── requirements.txt    - Python dependencies
terraform/                - Infrastructure as Code
  ├── aws/                - AWS resources (VPC, EKS, ECR, IAM, S3 state backend)
  ├── azure/              - Azure resources (VNet, AKS, ACR, Blob state backend)
  ├── modules/            - Reusable Terraform modules
  └── backends/           - Backend configuration files per environment
helm/                     - Kubernetes deployment
  ├── chart/              - Helm chart (Chart.yaml, templates/, values.yaml)
  ├── values-dev.yaml     - Dev environment overrides
  ├── values-stage.yaml   - Staging environment overrides
  └── values-prod.yaml    - Production environment overrides
monitoring/               - Observability stack
  ├── grafana/            - Grafana Helm values & dashboards (JSON)
  ├── prometheus/         - Prometheus Helm values, rules, alerts
  └── loki/               - Loki Helm values for log aggregation
scripts/                  - Automation and utility scripts
  ├── login-ecr.sh        - Authenticate to AWS ECR
  ├── login-acr.sh        - Authenticate to Azure ACR
  └── fetch-kubeconfig.sh - Retrieve EKS/AKS kubeconfig
docs/                     - Documentation
  ├── architecture/       - Architecture diagrams and design decisions
  └── runbooks/           - Operational runbooks and troubleshooting guides
.github/workflows/        - CI/CD pipelines (GitHub Actions)
  ├── ci.yaml             - Build, test, lint, scan (Trivy, SonarQube)
  ├── cd-aws.yaml         - Deploy to AWS EKS via kubeconfig secrets
  └── cd-azure.yaml       - Deploy to Azure AKS via kubeconfig secrets
```

## Key Conventions

### Infrastructure as Code (Terraform)
- **Multi-cloud strategy**: Separate state management for AWS (`terraform/aws/`) and Azure (`terraform/azure/`)
- **Remote state backends**:
  - AWS: S3 bucket + DynamoDB lock table (`backend "s3"` in `terraform/backends/`)
  - Azure: Blob Storage (`backend "azurerm"` in `terraform/backends/`)
- **Reusable modules**: Common infrastructure patterns in `terraform/modules/`
- **State files excluded**: `*.tfstate` files are gitignored and hidden from VS Code (see workspace settings)
- When working with Terraform:
  - Use `terraform fmt` before committing
  - Keep provider versions pinned in `versions.tf`
  - Tag all resources: `Environment`, `ManagedBy=Terraform`, `Project=multi-cloud-devsecops`
  - Naming convention: `{project}-{environment}-{resource}-{region}`

### Kubernetes & Helm
- Helm charts in `helm/chart/` follow standard Helm 3 conventions
- **Environment-specific values**: Use `helm/values-{dev,stage,prod}.yaml` for overrides
- Deploy with: `helm install <release> ./helm/chart -f helm/values-<env>.yaml`
- Templates should support multi-environment deployments (dev/staging/prod)

### Python Application (FastAPI/Flask)
- **Entry point**: `app/src/main.py`
- **Dependencies**: Managed in `app/requirements.txt`
- **Testing**: pytest for unit tests (`app/tests/`)
- **Containerization**: Multi-stage Dockerfile at `app/Dockerfile` for minimal image size
- **API endpoints**: Should expose `/health` and `/metrics` for K8s liveness/readiness probes

### Security Tooling
- **Trivy** integration for container and IaC scanning
- **SonarLint** for code quality in VS Code
- Security scanning should be integrated in CI/CD workflows (see `.github/workflows/ci.yaml`)
- Follow least-privilege principle in IAM/RBAC configurations

### Monitoring & Observability
- Grafana dashboards in `monitoring/grafana/` use JSON format
- Prometheus metrics should follow standard naming: `<namespace>_<subsystem>_<metric>_<unit>`
- Loki for centralized logging (`monitoring/loki/`)
- Include SLO/SLI dashboards for production services

### Scripts & Automation
- **Container registry authentication**: `scripts/login-ecr.sh` (AWS), `scripts/login-acr.sh` (Azure)
- **Kubeconfig retrieval**: `scripts/fetch-kubeconfig.sh` for EKS/AKS access
- Scripts should be idempotent and include error handling

## Development Workflows

### Application Development
```bash
cd app
# Install dependencies
pip install -r requirements.txt

# Run locally
python src/main.py

# Run tests
pytest tests/ -v

# Build container
docker build -t app:local .
trivy image app:local  # Security scan before push
```

### Working with Terraform
```bash
cd terraform/aws  # or terraform/azure
terraform init
terraform plan
terraform apply

# Environment-specific deployment
cd terraform/aws
terraform init -backend-config=backends/backend-dev.tfvars
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### Working with Helm
```bash
cd helm/chart
helm lint .
helm template . --values values.yaml

# Deploy to specific environment
helm install app-dev ./helm/chart -f helm/values-dev.yaml -n dev
helm upgrade app-stage ./helm/chart -f helm/values-stage.yaml -n stage
```

### Using Helper Scripts
```bash
# Authenticate to container registries
./scripts/login-ecr.sh
./scripts/login-acr.sh

# Fetch kubeconfig for clusters
./scripts/fetch-kubeconfig.sh --cluster eks-dev --region us-east-1
./scripts/fetch-kubeconfig.sh --cluster aks-dev --region eastus
```

## Tool Integration

### Required VS Code Extensions
Per workspace settings, install:
- HashiCorp Terraform
- Docker (Azure Tools)
- YAML (Red Hat)
- Azure Pipelines
- GitLens
- Trivy (Aqua Security)
- SonarLint

### Hidden from View
- `.terraform/` directories
- `node_modules/`
- `*.tfstate` files

## Best Practices

### When Creating IaC
- Tag all resources with: `Environment`, `ManagedBy=Terraform`, `Project=multi-cloud-devsecops`
- Use consistent naming: `{project}-{environment}-{resource}-{region}`
- Document module inputs/outputs in README files

### When Writing CI/CD Pipelines
- **Primary platform**: GitHub Actions (`.github/workflows/`)
- **CI pipeline** (`ci.yaml`):
  - Build and test Python app with pytest
  - Run SonarQube static code analysis
  - Build Docker image with multi-stage build
  - Scan with Trivy (container + IaC)
  - Push to container registry on success
- **CD pipelines** (`cd-aws.yaml`, `cd-azure.yaml`):
  - Separate workflows for AWS EKS and Azure AKS
  - Use GitHub Secrets for cloud credentials and kubeconfig
  - Deploy via `helm upgrade --install`
  - Implement approval gates for staging→prod promotions
- **Testing layers**:
  - Unit tests: `pytest app/tests/`
  - Integration tests: `pytest` with `requests` post-deployment
  - Infrastructure validation: `pytest-terraform` or Terratest

Example workflow structure:
```yaml
# .github/workflows/ci.yaml
jobs:
  test:
    - pytest tests/ --cov
  scan:
    - trivy fs . --scanners vuln,secret,config
    - sonar-scanner
  build:
    - docker build -t app:${{ github.sha }}
    - trivy image app:${{ github.sha }}
```

### When Adding Monitoring
- Every service should expose `/metrics` endpoint
- Add corresponding Grafana dashboard to `monitoring/grafana/dashboards/`
- Define alerts in Prometheus rules with runbook links

### When Writing Documentation
- Architecture diagrams go in `docs/architecture/`
- Operational runbooks in `docs/runbooks/`
- Include design decisions and ADRs (Architecture Decision Records)

## Multi-Cloud Considerations
- Abstract cloud-specific resources behind consistent interfaces
- Keep AWS and Azure configurations parallel where possible
- Document cloud-specific limitations or workarounds
- Use cloud-agnostic tools (Kubernetes, Terraform) as abstraction layer
