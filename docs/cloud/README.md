# Multi-Cloud PKI Lab Documentation

> **Project**: Reproducible Multi-Cloud PKI Architecture  
> **Status**: Terraform plans validated for Azure (PLAN-ONLY) and AWS (PLAN-ONLY)  
> **Local Environment**: Unchanged and healthy  

## Overview

This project extends the existing local PKI homelab into a reproducible multi-cloud architecture using Terraform as the primary Infrastructure-as-Code mechanism.

## Architecture

```
                    EXISTING GIT REPOSITORY
                              |
                   +----------+----------+
                   |                     |
                   v                     v
                AZURE                  AWS
              Terraform              Terraform
                 |                      |
               PLAN             PLAN / TEMP TEST
                 |                      |
                 v                      v
             Linux VM               EC2
                 |                      |
                K3s                    K3s
                 |                      |
              Argo CD                Argo CD
                 |                      |
                 +----------+-----------+
                            |
                            v
                     SAME PKI PLATFORM
```

## Directory Structure

```
infra/
└── terraform/
    ├── modules/
    │   └── (shared modules - future expansion)
    ├── azure/
    │   ├── providers.tf
    │   ├── versions.tf
    │   ├── main.tf
    │   ├── network.tf
    │   ├── compute.tf
    │   ├── variables.tf
    │   ├── locals.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   ├── cloud-init.yaml
    │   └── README.md
    └── aws/
        ├── providers.tf
        ├── versions.tf
        ├── main.tf
        ├── network.tf
        ├── compute.tf
        ├── iam.tf
        ├── data.tf
        ├── variables.tf
        ├── locals.tf
        ├── outputs.tf
        ├── terraform.tfvars.example
        ├── cloud-init.yaml
        └── README.md

docs/cloud/
├── README.md
├── local-architecture-inventory.md
├── azure-architecture.md
├── aws-architecture.md
└── (more docs to be created)
```

## Execution Modes

| Cloud | Mode | Resources Created | Cost |
|-------|------|-------------------|------|
| Azure | **PLAN-ONLY** | 0 | $0 |
| AWS | **PLAN-ONLY** | 0 | $0 |

## Cloud Portability Matrix

| Capability | Homelab | Azure | AWS |
|------------|---------|-------|-----|
| Infrastructure | libvirt/local | Azure VM | EC2 |
| Network | LAN/libvirt | VNet/Subnet | VPC/Subnet |
| Compute | Red Hat VM | Linux VM (B1s) | EC2 (t2.micro) |
| Kubernetes | K3s | K3s | K3s |
| GitOps | Argo CD | Argo CD | Argo CD |
| PKI | EJBCA | EJBCA | EJBCA |
| Database | PostgreSQL | PostgreSQL | PostgreSQL |
| Secrets | OpenBao | OpenBao | OpenBao |
| Identity | SPIRE | SPIRE | SPIRE |
| Queue | RabbitMQ | RabbitMQ | RabbitMQ |
| API | cert-api | cert-api | cert-api |
| Worker | cert-worker | cert-worker | cert-worker |

## Next Steps

1. Review Terraform plans
2. Add GitOps overlays for Azure and AWS
3. Create comprehensive documentation
4. Add architecture diagrams
5. Security review
6. Cost analysis
