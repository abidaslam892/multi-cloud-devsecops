#!/bin/bash
# Setup AWS GitHub Secrets Interactively
# This script helps configure all required AWS secrets for GitHub Actions

set -e

echo "=========================================="
echo "  AWS GitHub Secrets Setup Wizard"
echo "=========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo ""
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install gh"
    echo "  macOS: brew install gh"
    echo "  Or visit: https://cli.github.com/"
    echo ""
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "🔐 GitHub CLI authentication required"
    gh auth login
fi

echo "✓ GitHub CLI is ready"
echo ""

# Prompt for AWS credentials
echo "Step 1: AWS Credentials"
echo "------------------------"
echo "You can get these by creating an IAM user in AWS Console"
echo "or by running: aws iam create-access-key --user-name github-actions-user"
echo ""

read -p "Enter AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -sp "Enter AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
echo ""
echo ""

# Prompt for AWS region
echo "Step 2: AWS Region"
echo "------------------"
echo "Common regions: us-east-1, us-west-2, eu-west-1, ap-southeast-1"
read -p "Enter AWS_REGION [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}
echo ""

# Get AWS Account ID
echo "Step 3: AWS Account ID"
echo "----------------------"
echo "Attempting to get AWS Account ID..."

if command -v aws &> /dev/null; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -n "$AWS_ACCOUNT_ID" ]; then
        echo "✓ Detected AWS Account ID: $AWS_ACCOUNT_ID"
        read -p "Use this Account ID? [Y/n]: " USE_DETECTED
        if [[ ! "$USE_DETECTED" =~ ^[Nn]$ ]]; then
            echo "Using detected Account ID"
        else
            read -p "Enter AWS Account ID manually: " AWS_ACCOUNT_ID
        fi
    else
        read -p "Enter AWS Account ID (12 digits): " AWS_ACCOUNT_ID
    fi
else
    read -p "Enter AWS Account ID (12 digits): " AWS_ACCOUNT_ID
fi
echo ""

# Prompt for ECR repository
echo "Step 4: ECR Repository"
echo "----------------------"
read -p "Enter ECR_REPO name [multi-cloud-devsecops]: " ECR_REPO
ECR_REPO=${ECR_REPO:-multi-cloud-devsecops}

# Construct ECR_REGISTRY
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "✓ ECR Registry: $ECR_REGISTRY"
echo ""

# Prompt for EKS cluster
echo "Step 5: EKS Cluster Name"
echo "------------------------"
echo "If you haven't created an EKS cluster yet, choose a name you'll use"
read -p "Enter EKS_CLUSTER_NAME [multi-cloud-eks-dev]: " EKS_CLUSTER_NAME
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-multi-cloud-eks-dev}
echo ""

# Summary
echo "=========================================="
echo "  Configuration Summary"
echo "=========================================="
echo ""
echo "AWS_ACCESS_KEY_ID:     ${AWS_ACCESS_KEY_ID:0:20}..."
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}... (hidden)"
echo "AWS_REGION:            $AWS_REGION"
echo "ECR_REGISTRY:          $ECR_REGISTRY"
echo "ECR_REPO:              $ECR_REPO"
echo "EKS_CLUSTER_NAME:      $EKS_CLUSTER_NAME"
echo ""

read -p "Proceed to set GitHub Secrets? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Setting GitHub Secrets..."
echo ""

# Set secrets
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
echo "✓ AWS_ACCESS_KEY_ID set"

gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
echo "✓ AWS_SECRET_ACCESS_KEY set"

gh secret set AWS_REGION --body "$AWS_REGION"
echo "✓ AWS_REGION set"

gh secret set ECR_REGISTRY --body "$ECR_REGISTRY"
echo "✓ ECR_REGISTRY set"

gh secret set ECR_REPO --body "$ECR_REPO"
echo "✓ ECR_REPO set"

gh secret set EKS_CLUSTER_NAME --body "$EKS_CLUSTER_NAME"
echo "✓ EKS_CLUSTER_NAME set"

echo ""
echo "=========================================="
echo "  ✅ All AWS Secrets Configured!"
echo "=========================================="
echo ""
echo "You can verify secrets with: gh secret list"
echo ""
echo "Next steps:"
echo "  1. Create ECR repository:"
echo "     aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION"
echo ""
echo "  2. Create EKS cluster with Terraform (or via AWS Console)"
echo ""
echo "  3. Push code to trigger CI/CD pipeline"
echo ""
