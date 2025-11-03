# AWS GitHub Secrets Configuration Guide

This guide walks you through setting up AWS credentials and configuration for GitHub Actions CI/CD.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- GitHub repository admin access

## Step 1: Create AWS IAM User for GitHub Actions

### 1.1 Create IAM User

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-user

# Create access key for the user
aws iam create-access-key --user-name github-actions-user
```

**Save the output!** You'll need:
- `AccessKeyId` → This is your `AWS_ACCESS_KEY_ID`
- `SecretAccessKey` → This is your `AWS_SECRET_ACCESS_KEY`

### 1.2 Attach Required Policies

```bash
# Attach ECR permissions
aws iam attach-user-policy \
  --user-name github-actions-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# Attach EKS permissions
aws iam attach-user-policy \
  --user-name github-actions-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

### 1.3 Create Custom Policy for EKS Access

Create file `eks-github-actions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups"
      ],
      "Resource": "*"
    }
  ]
}
```

Apply the policy:

```bash
aws iam put-user-policy \
  --user-name github-actions-user \
  --policy-name EKSAccess \
  --policy-document file://eks-github-actions-policy.json
```

## Step 2: Get AWS Configuration Values

### 2.1 Get AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

Example output: `123456789012`

### 2.2 Get AWS Region

```bash
# Use your preferred region
echo "us-east-1"
```

Common regions:
- `us-east-1` (N. Virginia)
- `us-west-2` (Oregon)
- `eu-west-1` (Ireland)
- `ap-southeast-1` (Singapore)

### 2.3 Create ECR Repository

```bash
# Set your repository name
ECR_REPO="multi-cloud-devsecops"
AWS_REGION="us-east-1"

# Create ECR repository
aws ecr create-repository \
  --repository-name $ECR_REPO \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true

# Get the repository URI
aws ecr describe-repositories \
  --repository-names $ECR_REPO \
  --region $AWS_REGION \
  --query 'repositories[0].repositoryUri' \
  --output text
```

Example output: `123456789012.dkr.ecr.us-east-1.amazonaws.com/multi-cloud-devsecops`

This gives you:
- **ECR_REGISTRY**: `123456789012.dkr.ecr.us-east-1.amazonaws.com`
- **ECR_REPO**: `multi-cloud-devsecops`

### 2.4 Get EKS Cluster Name

```bash
# List your EKS clusters
aws eks list-clusters --region us-east-1

# Or if you're creating a new cluster, note the name you'll use
# Example: multi-cloud-eks-dev
```

If you don't have an EKS cluster yet, you'll create one with Terraform later. For now, plan your cluster name:
- **EKS_CLUSTER_NAME**: `multi-cloud-eks-dev` (or your preferred name)

## Step 3: Configure GitHub Secrets

### Option A: Via GitHub Web UI

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ACCESS_KEY_ID` | From Step 1.1 | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | From Step 1.1 | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | Your chosen region | `us-east-1` |
| `ECR_REGISTRY` | Registry URL without repo name | `123456789012.dkr.ecr.us-east-1.amazonaws.com` |
| `ECR_REPO` | Repository name only | `multi-cloud-devsecops` |
| `EKS_CLUSTER_NAME` | Your EKS cluster name | `multi-cloud-eks-dev` |

### Option B: Via GitHub CLI

```bash
# Install GitHub CLI if needed: https://cli.github.com/

# Login to GitHub
gh auth login

# Set secrets (replace values with your actual values)
gh secret set AWS_ACCESS_KEY_ID --body "AKIAIOSFODNN7EXAMPLE"
gh secret set AWS_SECRET_ACCESS_KEY --body "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
gh secret set AWS_REGION --body "us-east-1"
gh secret set ECR_REGISTRY --body "123456789012.dkr.ecr.us-east-1.amazonaws.com"
gh secret set ECR_REPO --body "multi-cloud-devsecops"
gh secret set EKS_CLUSTER_NAME --body "multi-cloud-eks-dev"
```

### Option C: Automated Script

Create file `scripts/setup-aws-secrets.sh`:

```bash
#!/bin/bash
set -e

echo "AWS GitHub Secrets Setup"
echo "========================"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Prompt for values
read -p "Enter AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -sp "Enter AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
echo ""
read -p "Enter AWS_REGION (e.g., us-east-1): " AWS_REGION
read -p "Enter AWS Account ID: " AWS_ACCOUNT_ID
read -p "Enter ECR_REPO name (e.g., multi-cloud-devsecops): " ECR_REPO
read -p "Enter EKS_CLUSTER_NAME (e.g., multi-cloud-eks-dev): " EKS_CLUSTER_NAME

# Construct ECR_REGISTRY
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Set secrets
echo "Setting GitHub Secrets..."
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set AWS_REGION --body "$AWS_REGION"
gh secret set ECR_REGISTRY --body "$ECR_REGISTRY"
gh secret set ECR_REPO --body "$ECR_REPO"
gh secret set EKS_CLUSTER_NAME --body "$EKS_CLUSTER_NAME"

echo ""
echo "✓ All AWS secrets configured successfully!"
echo ""
echo "Summary:"
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "  AWS_REGION: $AWS_REGION"
echo "  ECR_REGISTRY: $ECR_REGISTRY"
echo "  ECR_REPO: $ECR_REPO"
echo "  EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
```

Make it executable and run:

```bash
chmod +x scripts/setup-aws-secrets.sh
./scripts/setup-aws-secrets.sh
```

## Step 4: Verify Secrets

### Via GitHub Web UI

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see all 6 secrets listed

### Via GitHub CLI

```bash
gh secret list
```

## Step 5: Test AWS Credentials Locally

Before pushing to GitHub, test your credentials locally:

```bash
# Test AWS CLI access
aws sts get-caller-identity

# Test ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Test EKS access (if cluster exists)
aws eks describe-cluster --name multi-cloud-eks-dev --region us-east-1
```

## Step 6: Update Terraform Variables (Optional)

If you're using Terraform to create EKS, update your variable files:

```hcl
# terraform/aws/variables.tf
variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "multi-cloud-eks-dev"
}

variable "ecr_repository_name" {
  default = "multi-cloud-devsecops"
}
```

## Troubleshooting

### Issue: "User is not authorized to perform: ecr:GetAuthorizationToken"

**Solution**: Attach the `AmazonEC2ContainerRegistryPowerUser` policy:

```bash
aws iam attach-user-policy \
  --user-name github-actions-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

### Issue: "Error: cannot get cluster info"

**Solution**: Ensure the IAM user has EKS read permissions and the cluster exists:

```bash
aws eks list-clusters --region us-east-1
```

### Issue: "Repository does not exist"

**Solution**: Create the ECR repository:

```bash
aws ecr create-repository \
  --repository-name multi-cloud-devsecops \
  --region us-east-1
```

## Security Best Practices

1. **Rotate Access Keys Regularly**: Set up a reminder to rotate keys every 90 days
2. **Use Least Privilege**: Only grant necessary permissions
3. **Enable MFA**: Consider requiring MFA for sensitive operations
4. **Monitor Access**: Enable CloudTrail logging for the IAM user
5. **Use Environment Secrets**: For production, use environment-specific secrets

## Quick Reference Card

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get ECR Registry URL
echo "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# List ECR Repositories
aws ecr describe-repositories --region us-east-1

# List EKS Clusters
aws eks list-clusters --region us-east-1

# Test ECR Login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

## Summary

After completing these steps, you should have:

- ✅ IAM user for GitHub Actions with appropriate permissions
- ✅ AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
- ✅ ECR repository created
- ✅ All 6 GitHub Secrets configured:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - AWS_REGION
  - ECR_REGISTRY
  - ECR_REPO
  - EKS_CLUSTER_NAME
- ✅ Credentials tested and verified

**Next Step**: Push code to GitHub to trigger the CI/CD pipeline!
