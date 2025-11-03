#!/bin/bash
# Quick GitHub Repository Setup Guide

set -e

echo "=========================================="
echo "  GitHub Repository Setup"
echo "=========================================="
echo ""
echo "You have two options:"
echo ""
echo "Option 1: Create repository via GitHub CLI (Recommended)"
echo "Option 2: Create repository manually via GitHub.com"
echo ""

read -p "Choose option [1/2]: " OPTION

if [ "$OPTION" == "1" ]; then
    echo ""
    echo "Creating GitHub repository via CLI..."
    echo ""
    
    # Check if gh is installed
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI not installed"
        echo "Install: https://cli.github.com/"
        exit 1
    fi
    
    # Check authentication
    if ! gh auth status &> /dev/null; then
        echo "🔐 Authenticating with GitHub..."
        gh auth login
    fi
    
    echo ""
    read -p "Enter repository name [multi-cloud-devsecops]: " REPO_NAME
    REPO_NAME=${REPO_NAME:-multi-cloud-devsecops}
    
    read -p "Public or Private? [public/private]: " VISIBILITY
    VISIBILITY=${VISIBILITY:-public}
    
    read -p "Repository description: " DESCRIPTION
    DESCRIPTION=${DESCRIPTION:-"Multi-cloud DevSecOps platform deploying Python apps to AWS EKS and Azure AKS"}
    
    echo ""
    echo "Creating repository '$REPO_NAME' ($VISIBILITY)..."
    
    gh repo create "$REPO_NAME" \
        --$VISIBILITY \
        --description "$DESCRIPTION" \
        --source=. \
        --remote=origin \
        --push
    
    echo ""
    echo "✅ Repository created and code pushed!"
    echo ""
    echo "Next: Configure AWS secrets with:"
    echo "  ./scripts/setup-aws-secrets.sh"
    
elif [ "$OPTION" == "2" ]; then
    echo ""
    echo "Manual Setup Instructions:"
    echo "=========================="
    echo ""
    echo "1. Go to https://github.com/new"
    echo "2. Repository name: multi-cloud-devsecops"
    echo "3. Choose Public or Private"
    echo "4. DO NOT initialize with README (we already have one)"
    echo "5. Click 'Create repository'"
    echo ""
    echo "6. Then run these commands:"
    echo ""
    echo "   git remote add origin https://github.com/YOUR_USERNAME/multi-cloud-devsecops.git"
    echo "   git push -u origin main"
    echo ""
    read -p "Press Enter after creating the repository on GitHub..."
    
    echo ""
    read -p "Enter your GitHub username: " USERNAME
    
    git remote add origin "https://github.com/$USERNAME/multi-cloud-devsecops.git"
    
    echo ""
    echo "Pushing code to GitHub..."
    git push -u origin main
    
    echo ""
    echo "✅ Code pushed to GitHub!"
    echo ""
    echo "Next: Configure AWS secrets with:"
    echo "  ./scripts/setup-aws-secrets.sh"
else
    echo "Invalid option. Exiting."
    exit 1
fi
