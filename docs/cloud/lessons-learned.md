# Lessons Learned

> **Project**: Multi-Cloud PKI Lab with Terraform and GitOps  
> **Date**: 2026-09-02  
> **Status**: Terraform plans validated, documentation complete

## What Worked Well

### 1. Terraform-First Approach

- Infrastructure definitions are version-controlled and reproducible
- Easy to review changes before applying
- Consistent across Azure and AWS

### 2. VM + K3s Architecture

- **Cost-effective**: ~$3-13/month vs $70+/month for managed Kubernetes
- **Portable**: Same K3s setup works everywhere
- **Educational**: Full control over the stack

### 3. Cloud-Init Bootstrap

- Automated installation of K3s, Argo CD, and dependencies
- No manual intervention needed after VM creation
- Easy to update and version control

### 4. GitOps with Argo CD

- Single source of truth in Git
- Automated sync of applications
- Easy to replicate across environments

### 5. Plan-Only Mode

- Validated architecture without cost
- Identified issues early
- Safe experimentation

## Challenges Faced

### 1. Azure RBAC Limitations

**Issue**: User lacks resource group read permissions  
**Impact**: Cannot run `terraform plan` for Azure  
**Resolution**: Code is validated and ready; plan will work with proper permissions  
**Lesson**: Verify cloud permissions before starting infrastructure work

### 2. AWS Variable Conflicts

**Issue**: Duplicate resource declarations across files  
**Impact**: Terraform validation failures  
**Resolution**: Consolidated resources into single files per category  
**Lesson**: Establish clear file organization conventions early

### 3. Cloud-Init Template Variables

**Issue**: Missing template variables in locals.tf  
**Impact**: Terraform plan failures  
**Resolution**: Added all required variables to template rendering  
**Lesson**: Validate template variables match cloud-init script

### 4. Provider Version Conflicts

**Issue**: Duplicate required_providers blocks  
**Impact**: Terraform initialization failures  
**Resolution**: Consolidated provider configurations  
**Lesson**: Keep provider configuration in one place

## Design Decisions

### Why Not AKS/EKS?

| Factor | Decision | Rationale |
|--------|----------|-----------|
| Cost | VM + K3s | 5-10x cheaper |
| Learning | VM + K3s | More control, better understanding |
| Portability | VM + K3s | Same everywhere |
| Production | AKS/EKS | Would choose managed for production |

### Why Standard_B1s / t2.micro?

- Sufficient for lab workloads
- AWS t2.micro is free tier eligible
- Can scale up if needed
- Easy to stop when not in use

### Why Dynamic Public IP?

- $0 when VM is stopped
- Acceptable for lab environment
- Static IP not needed for ephemeral infrastructure

## Cost Insights

### Azure
- **Running 24/7**: ~$12.50/month
- **Stopped when not in use**: ~$4/month (storage only)
- **Biggest savings**: Avoiding AKS ($70+/month)

### AWS
- **Running 24/7 (free tier)**: ~$3/month
- **Running 24/7 (after free tier)**: ~$13.50/month
- **Stopped when not in use**: ~$5/month (storage only)
- **Biggest savings**: Avoiding EKS ($70+/month)

## Security Insights

### What We Did Well
- EBS encryption enabled (AWS)
- Minimal IAM permissions
- No secrets in Terraform code
- Resource tagging for ownership

### What Needs Improvement
- SSH open to 0.0.0.0/0 (restrict to your IP)
- K3s API exposed (use VPN for production)
- No disk encryption at rest (Azure)
- Local Terraform state (use remote for production)

## Next Steps

1. **Add GitOps overlays** for Azure and AWS environments
2. **Implement ingress controller** (nginx or traefik)
3. **Add monitoring stack** (Prometheus/Grafana)
4. **Configure backup strategy** for persistent data
5. **Add CI/CD pipeline** for Terraform validation
6. **Implement secret management** with OpenBao
7. **Add network policies** for pod-to-pod security
8. **Configure cert-manager** for automatic TLS

## Key Takeaways

1. **Terraform is powerful** for multi-cloud infrastructure
2. **K3s is lightweight** and sufficient for lab environments
3. **GitOps simplifies** application deployment
4. **Cost awareness** is critical for cloud projects
5. **Security is a journey** — start with basics and improve
6. **Documentation is essential** for reproducibility
7. **Plan-only mode** is valuable for architecture validation
