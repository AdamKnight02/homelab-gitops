# Architecture Diagrams

## Local PKI Architecture

```mermaid
graph TB
    subgraph "Local Homelab"
        CLIENT[Client/Application]
        CLIENT -->|mTLS| CERT_API[cert-api]
        CERT_API -->|AuthN/AuthZ| OPENBAO[OpenBao]
        CERT_API -->|Queue| RABBIT[RabbitMQ]
        RABBIT -->|Consume| WORKER[cert-worker]
        WORKER -->|CA Ops| CA_SVC[ca-service]
        CA_SVC -->|Issue| EJBCA[EJBCA PKI]
        EJBCA -->|Store| POSTGRES[PostgreSQL]
        WORKER -->|Inventory| INV[Certificate Inventory]
        WORKER -->|Audit| AUDIT[Audit Trail]
        SPIRE[SPIRE Server] -->|SVIDs| CERT_API
        SPIRE -->|SVIDs| WORKER
        SPIRE -->|SVIDs| CA_SVC
    end
```

## Cloud-Neutral Architecture

```mermaid
graph TB
    subgraph "Any Cloud"
        C[Client]
        C -->|mTLS| API[Certificate API]
        API -->|Auth| SECRETS[OpenBao]
        API -->|Queue| MQ[RabbitMQ]
        MQ -->|Process| WORKER[Cert Worker]
        WORKER -->|CA| CA_SVC[CA Abstraction]
        CA_SVC -->|Issue| EJBCA[EJBCA]
        EJBCA -->|DB| PG[PostgreSQL]
        WORKER -->|Track| INV[Inventory]
        WORKER -->|Log| AUDIT[Audit]
        SPIRE[SPIRE] -->|Identity| API
        SPIRE -->|Identity| WORKER
        SPIRE -->|Identity| CA_SVC
    end
```

## Azure Architecture

```mermaid
graph TB
    subgraph "Azure"
        RG[Resource Group<br/>pki-lab-azure-rg]
        RG --> VNET[VNet<br/>10.0.0.0/16]
        VNET --> SUBNET[Subnet<br/>10.0.1.0/24]
        SUBNET --> NSG[NSG]
        NSG --> VM[Linux VM<br/>Standard_B1s]
        VM --> K3S[K3s Cluster]
        K3S --> ARGO[Argo CD]
        ARGO -->|GitOps| REPO[Git Repository]
        REPO --> APPS[PKI Workloads]
        APPS --> EJBCA[EJBCA]
        APPS --> OPENBAO[OpenBao]
        APPS --> SPIRE[SPIRE]
        APPS --> RABBIT[RabbitMQ]
    end
```

## AWS Architecture

```mermaid
graph TB
    subgraph "AWS"
        VPC[VPC<br/>10.1.0.0/16]
        VPC --> SUBNET[Subnet<br/>10.1.1.0/24]
        VPC --> IGW[Internet Gateway]
        SUBNET --> SG[Security Group]
        SG --> EC2[EC2 t3.micro]
        EC2 --> K3S[K3s Cluster]
        K3S --> ARGO[Argo CD]
        ARGO -->|GitOps| REPO[Git Repository]
        REPO --> APPS[PKI Workloads]
        APPS --> EJBCA[EJBCA]
        APPS --> OPENBAO[OpenBao]
        APPS --> SPIRE[SPIRE]
        APPS --> RABBIT[RabbitMQ]
    end
```

## Terraform Workflow

```mermaid
graph LR
    A[Terraform Code] --> B[terraform init]
    B --> C[terraform validate]
    C --> D[terraform plan]
    D --> E{Approved?}
    E -->|Azure| F[PLAN ONLY]
    E -->|AWS| G[Ephemeral Test]
    G --> H[terraform apply]
    H --> I[Validate]
    I --> J[terraform destroy]
    J --> K[Verify Cleanup]
```

## K3s Bootstrap

```mermaid
sequenceDiagram
    participant TF as Terraform
    participant VM as Cloud VM
    participant CI as cloud-init
    participant K3S as K3s
    participant ARGO as Argo CD
    participant GIT as Git Repo

    TF->>VM: Create VM
    VM->>CI: Execute cloud-init
    CI->>K3S: Install K3s
    CI->>ARGO: Install Argo CD
    ARGO->>GIT: Connect to Git
    GIT->>ARGO: Pull applications
    ARGO->>K3S: Deploy workloads
```

## Argo CD GitOps Flow

```mermaid
graph LR
    DEV[Developer] -->|Push| GIT[Git Repository]
    GIT -->|Webhook/Poll| ARGO[Argo CD]
    ARGO -->|Sync| K3S[K3s Cluster]
    K3S -->|Run| APP1[EJBCA]
    K3S -->|Run| APP2[OpenBao]
    K3S -->|Run| APP3[SPIRE]
    K3S -->|Run| APP4[cert-api]
    K3S -->|Run| APP5[cert-worker]
```

## SPIFFE Identity Flow

```mermaid
sequenceDiagram
    participant POD as Pod/Workload
    participant AGENT as SPIRE Agent
    participant SERVER as SPIRE Server
    participant CA as EJBCA

    POD->>AGENT: Request SVID
    AGENT->>SERVER: Attest workload
    SERVER->>SERVER: Validate identity
    SERVER->>CA: Request certificate
    CA->>SERVER: Issue certificate
    SERVER->>AGENT: Return SVID
    AGENT->>POD: Provide SVID
```

## Certificate Issuance

```mermaid
sequenceDiagram
    participant CLIENT as Client
    participant API as cert-api
    participant MQ as RabbitMQ
    participant WORKER as cert-worker
    participant CA as ca-service
    participant EJBCA as EJBCA
    participant INV as Inventory
    participant AUDIT as Audit

    CLIENT->>API: Request certificate
    API->>API: Authenticate/Authorize
    API->>MQ: Queue request
    MQ->>WORKER: Deliver request
    WORKER->>CA: CA operation
    CA->>EJBCA: Issue certificate
    EJBCA->>CA: Return certificate
    CA->>WORKER: Return certificate
    WORKER->>INV: Store metadata
    WORKER->>AUDIT: Log event
    WORKER->>CLIENT: Deliver certificate
```

## Certificate Renewal

```mermaid
graph LR
    CRON[CronJob] -->|Check| INV[Inventory]
    INV -->|Expiring| MQ[Queue]
    MQ -->|Process| WORKER[Worker]
    WORKER -->|Renew| CA[CA]
    CA -->|New Cert| EJBCA[EJBCA]
    WORKER -->|Update| INV
    WORKER -->|Log| AUDIT[Audit]
```

## Certificate Revocation

```mermaid
graph LR
    ADMIN[Admin/API] -->|Revoke| API[cert-api]
    API -->|Queue| MQ[RabbitMQ]
    MQ -->|Process| WORKER[cert-worker]
    WORKER -->|Revoke| CA[ca-service]
    CA -->|CRL/OCSP| EJBCA[EJBCA]
    WORKER -->|Update| INV[Inventory]
    WORKER -->|Log| AUDIT[Audit]
```

## Cloud Teardown

```mermaid
graph LR
    TERRAFORM[Terraform] -->|destroy| RESOURCES[Cloud Resources]
    RESOURCES -->|Verify| AWS[AWS API]
    RESOURCES -->|Verify| AZURE[Azure API]
    AWS -->|Confirm| CLEAN[Clean]
    AZURE -->|Confirm| CLEAN
```
