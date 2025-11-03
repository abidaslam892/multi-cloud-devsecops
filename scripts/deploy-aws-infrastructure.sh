#!/bin/bash
# Deploy AWS Infrastructure with Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/aws"

echo "=========================================="
echo "  AWS Infrastructure Deployment"
echo "=========================================="
echo ""

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

echo "✓ Prerequisites checked"
echo ""

# Select environment
read -p "Select environment (dev/stage/prod) [dev]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

echo ""
echo "Environment: $ENVIRONMENT"
echo "Terraform directory: $TERRAFORM_DIR"
echo ""

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo "✓ AWS Account: $AWS_ACCOUNT_ID"
echo "✓ AWS Region: $AWS_REGION"
echo ""

# Create S3 backend if it doesn't exist
BUCKET_NAME="multi-cloud-devsecops-terraform-state"
TABLE_NAME="multi-cloud-devsecops-terraform-lock"

echo "Setting up Terraform backend..."

# Check if bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        $(if [ "$AWS_REGION" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=$AWS_REGION"; fi)
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    echo "✓ S3 bucket created and configured"
else
    echo "✓ S3 bucket already exists"
fi

# Check if DynamoDB table exists
if ! aws dynamodb describe-table --table-name "$TABLE_NAME" &>/dev/null; then
    echo "Creating DynamoDB table: $TABLE_NAME"
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME"
    echo "✓ DynamoDB table created"
else
    echo "✓ DynamoDB table already exists"
fi

echo ""

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init \
    -backend-config="../backends/backend-${ENVIRONMENT}-aws.tfvars" \
    -upgrade

echo ""

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

echo ""

# Plan deployment
echo "Planning infrastructure changes..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="region=$AWS_REGION" \
    -out=tfplan

echo ""
echo "=========================================="
echo "  Review Plan Above"
echo "=========================================="
echo ""

read -p "Apply this plan? [y/N]: " APPLY
if [[ ! "$APPLY" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Applying infrastructure changes..."
terraform apply tfplan

echo ""
echo "=========================================="
echo "  ✅ AWS Infrastructure Deployed!"
echo "=========================================="
echo ""

# Get outputs
echo "Infrastructure Details:"
echo ""
terraform output

echo ""
echo "Next steps:"
echo "  1. Configure kubectl:"
echo "     $(terraform output -raw configure_kubectl)"
echo ""
echo "  2. Verify cluster:"
echo "     kubectl get nodes"
echo ""
echo "  3. Deploy application:"
echo "     cd ../../helm"
echo "     helm install app ./chart -f values-${ENVIRONMENT}.yaml"
echo ""
