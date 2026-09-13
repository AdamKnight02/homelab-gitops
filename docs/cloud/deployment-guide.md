# Deployment Guide — Multi-Cloud PKI Lab

> **WARNING**: This guide is for reference only. Do NOT deploy Azure resources. AWS deployment requires explicit approval after free-tier verification.

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI (for Azure)
- AWS CLI (for AWS)
- SSH key pair
- Git repository access

## Azure Deployment (PLAN-ONLY)

### 1. Authenticate

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Initialize Terraform

```bash
cd infra/terraform/azure
terraform init
```

### 3. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 4. Plan (ALLOWED)

```bash
terraform plan -out=azure.tfplan
```

### 5. Apply (NOT ALLOWED)

```bash
# terraform apply azure.tfplan  # DO NOT RUN
```

## AWS Deployment (REQUIRES APPROVAL)

### 1. Authenticate

```bash
aws configure
# Or use environment variables
```

### 2. Verify Free Tier Eligibility

```bash
aws billing get-cost-forecast
# Or check AWS Console > Billing & Cost Management
```

### 3. Initialize Terraform

```bash
cd infra/terraform/aws
terraform init
```

### 4. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 5. Plan (ALLOWED)

```bash
terraform plan -out=aws.tfplan
```

### 6. Apply (REQUIRES EXPLICIT APPROVAL)

```bash
# ONLY after confirming:
# - Free tier eligibility
# - Cost review
# - Resource tagging
# terraform apply aws.tfplan
```

## Post-Deployment

### Access K3s Cluster

```bash
# Azure
scp -i ~/.ssh/pki-cloudlab-lab azureuser@<VM_IP>:/etc/rancher/k3s/k3s.yaml ./k3s-azure.yaml
export KUBECONFIG=./k3s-azure.yaml

# AWS
scp -i ~/.ssh/pki-cloudlab-lab ubuntu@<EC2_IP>:/etc/rancher/k3s/k3s.yaml ./k3s-aws.yaml
export KUBECONFIG=./k3s-aws.yaml
```

### Verify Argo CD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Open http://localhost:8080
```

### Verify PKI Workloads

```bash
kubectl get applications -n argocd
kubectl get pods -A
```

## Teardown

### Azure

```bash
# terraform destroy  # NOT ALLOWED for this project
```

### AWS

```bash
# terraform destroy  # ONLY if explicitly deployed
```

### Independent Verification

```bash
# Azure
az resource list --tag "project=pki-cloudlab"

# AWS
aws ec2 describe-instances --filters "Name=tag:Project,Values=pki-cloudlab"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=pki-cloudlab"
```
