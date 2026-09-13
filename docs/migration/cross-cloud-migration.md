# Cross-Cloud Migration Orchestrator

## Overview

This document defines the Cross-Cloud Migration Orchestrator — a comprehensive framework for migrating PKI platform workloads between cloud providers. Unlike simple Terraform state moves, this orchestrator handles the full lifecycle: inventory, planning, provisioning, data migration, PKI material handling, validation, and cutover.

**Critical Distinction:** This is NOT `terraform state mv` between providers. Cross-cloud migration requires:
- Re-provisioning infrastructure in the target cloud
- Migrating non-sensitive data and configuration
- Handling PKI material with appropriate security controls
- Validating functional equivalence
- Managing traffic cutover and DNS changes

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CROSS-CLOUD MIGRATION ORCHESTRATOR                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   PHASE 1   │───▶│   PHASE 2   │───▶│   PHASE 3   │───▶│   PHASE 4   │  │
│  │  Inventory  │    │   Export    │    │  Provision  │    │   Deploy    │  │
│  │  & Assess   │    │   Intent    │    │   Target    │    │   Platform  │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   PHASE 5   │───▶│   PHASE 6   │───▶│   PHASE 7   │───▶│   PHASE 8   │  │
│  │   Migrate   │    │   Validate  │    │   Cutover   │    │ Decommission│  │
│  │    Data     │    │   & Test    │    │   Traffic   │    │   Source    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      APPROVAL GATES (Manual)                         │   │
│  │  Gate 1: Pre-migration approval                                      │   │
│  │  Gate 2: Post-provisioning approval                                  │   │
│  │  Gate 3: Pre-cutover approval                                        │   │
│  │  Gate 4: Post-cutover approval                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Migration Manifest Schema

### Complete Schema Definition

```yaml
# migration-manifest.yaml
apiVersion: pki.platform/v1alpha1
kind: CrossCloudMigration
metadata:
  name: azure-to-aws-lab-migration
  namespace: migration
  labels:
    migration.pki.platform/source: azure
    migration.pki.platform/target: aws
    migration.pki.platform/environment: lab
  annotations:
    migration.pki.platform/created-by: "migration-orchestrator"
    migration.pki.platform/created-at: "2026-09-12T13:00:00Z"

spec:
  # =========================================================================
  # SOURCE AND TARGET CONFIGURATION
  # =========================================================================
  source:
    provider: azure
    environment: lab
    customer: default
    region: eastus
    stateBackend:
      type: azurerm
      config:
        resourceGroupName: pki-terraform-state-rg
        storageAccountName: pkterraformstate
        containerName: tfstate
        key: azure/default/lab/terraform.tfstate
    credentials:
      type: azure-cli
      # or: service-principal, managed-identity

  target:
    provider: aws
    environment: lab
    customer: default
    region: us-east-1
    stateBackend:
      type: s3
      config:
        bucket: pki-terraform-state-123456789012
        key: aws/default/lab/terraform.tfstate
        region: us-east-1
        dynamodbTable: terraform-state-locks
    credentials:
      type: aws-profile
      profile: default
      # or: access-key, iam-role, sso

  # =========================================================================
  # MIGRATION SCOPE
  # =========================================================================
  scope:
    # Infrastructure components to migrate
    infrastructure:
      network: true
      compute: true
      storage: true
      security: true
      monitoring: false  # Optional: skip monitoring for lab

    # PKI components to migrate
    pki:
      rootCA: false           # NEVER auto-migrate root CA keys
      issuingCA: false        # NEVER auto-migrate issuing CA keys
      certificates: true      # Migrate issued certificates (public data)
      crls: true              # Migrate CRLs (public data)
      ocsp: true              # Migrate OCSP responders
      hsmKeys: false          # NEVER auto-migrate HSM key material

    # Data classification for migration
    dataClassification:
      portableConfig: true    # Configuration files, templates
      portableData: true      # Non-sensitive operational data
      requiresSecureMigration: false  # Encrypted data requiring secure channel
      nonExportableKeyMaterial: false # HSM-protected keys (manual process)
      requiresManualApproval: false   # Items requiring explicit approval

  # =========================================================================
  # MIGRATION STRATEGY
  # =========================================================================
  strategy:
    type: blue-green  # or: rolling, canary, big-bang
    
    # Blue-green specific
    blueGreen:
      activeColor: blue
      targetColor: green
      switchoverMethod: dns  # or: load-balancer, manual
    
    # Rollback configuration
    rollback:
      enabled: true
      automatic: false  # Require manual approval for rollback
      retentionPeriod: 720h  # 30 days
      backupLocation: s3://pki-migration-backups/

  # =========================================================================
  # APPROVAL GATES
  # =========================================================================
  approvalGates:
    # Gate 1: Pre-migration approval
    preMigration:
      required: true
      approvers:
        - security-team@example.com
        - platform-team@example.com
      timeout: 72h
      autoApprove: false
      conditions:
        - sourceBackupCompleted: true
        - targetBackendReady: true
        - pkiMaterialClassified: true

    # Gate 2: Post-provisioning approval
    postProvisioning:
      required: true
      approvers:
        - platform-team@example.com
      timeout: 48h
      autoApprove: false
      conditions:
        - infrastructureProvisioned: true
        - networkConnectivityVerified: true
        - securityGroupsConfigured: true

    # Gate 3: Pre-cutover approval
    preCutover:
      required: true
      approvers:
        - security-team@example.com
        - business-owner@example.com
      timeout: 24h
      autoApprove: false
      conditions:
        - dataMigrationCompleted: true
        - smokeTestsPassed: true
        - pkiValidationCompleted: true
        - rollbackPlanVerified: true

    # Gate 4: Post-cutover approval
    postCutover:
      required: true
      approvers:
        - business-owner@example.com
      timeout: 168h  # 1 week
      autoApprove: false
      conditions:
        - trafficVerified: true
        - monitoringActive: true
        - noCriticalAlerts: true

  # =========================================================================
  # PKI MATERIAL CLASSIFICATION
  # =========================================================================
  pkiMaterial:
    # Classification of all PKI material
    classifications:
      # Root CA private keys — NEVER auto-migrate
      - name: root-ca-private-key
        type: NON_EXPORTABLE_KEY_MATERIAL
        location: hsm  # or: software, external-ca
        migrationMethod: manual-ceremony
        approvalRequired: true
        approvers:
          - pki-security-officer@example.com
          - ciso@example.com

      # Issuing CA private keys — NEVER auto-migrate
      - name: issuing-ca-private-key
        type: NON_EXPORTABLE_KEY_MATERIAL
        location: hsm
        migrationMethod: manual-ceremony
        approvalRequired: true
        approvers:
          - pki-security-officer@example.com

      # Issued certificates — Public data, safe to migrate
      - name: issued-certificates
        type: PORTABLE_DATA
        location: database
        migrationMethod: export-import
        approvalRequired: false

      # CRLs — Public data, safe to migrate
      - name: certificate-revocation-lists
        type: PORTABLE_DATA
        location: storage
        migrationMethod: export-import
        approvalRequired: false

      # OCSP responder configuration — Configuration data
      - name: ocsp-responder-config
        type: PORTABLE_CONFIG
        location: configmap
        migrationMethod: template-render
        approvalRequired: false

      # HSM partition credentials — Requires secure migration
      - name: hsm-partition-credentials
        type: REQUIRES_SECURE_MIGRATION
        location: hsm
        migrationMethod: secure-channel
        approvalRequired: true
        approvers:
          - hsm-admin@example.com

  # =========================================================================
  # VALIDATION AND TESTING
  # =========================================================================
  validation:
    # Smoke tests to run after migration
    smokeTests:
      - name: network-connectivity
        type: connectivity
        targets:
          - target-vpc
          - target-subnet
        timeout: 5m

      - name: k3s-cluster-ready
        type: kubernetes
        checks:
          - node-ready
          - pods-running
          - dns-resolution
        timeout: 10m

      - name: argocd-accessible
        type: http
        url: https://argocd.target.example.com
        expectedStatus: 200
        timeout: 5m

      - name: pki-issuance-test
        type: pki
        testCertificate:
          commonName: test.migration.pki
          validity: 24h
        timeout: 10m

    # Comparison checks between source and target
    comparison:
      enabled: true
      checks:
        - name: resource-count
          type: terraform
          compare: state-list-count
          tolerance: 0  # Exact match required

        - name: network-cidr
          type: terraform
          compare: output-value
          outputName: network_cidr
          expectedMatch: true

        - name: vm-count
          type: terraform
          compare: output-value
          outputName: vm_count
          expectedMatch: true

  # =========================================================================
  # CUTOVER CONFIGURATION
  # =========================================================================
  cutover:
    # DNS cutover configuration
    dns:
      enabled: true
      provider: route53  # or: azure-dns, cloudflare, manual
      zone: example.com
      records:
        - name: pki.example.com
          type: A
          ttl: 300
          sourceValue: azure-lb-ip
          targetValue: aws-lb-ip
          switchoverMethod: weighted  # or: failover, simple

      # Weighted DNS for gradual cutover
      weighted:
        enabled: true
        steps:
          - weight: 10   # 10% traffic to target
            duration: 1h
          - weight: 50   # 50% traffic to target
            duration: 2h
          - weight: 100  # 100% traffic to target
            duration: 0    # Permanent

    # Load balancer cutover (alternative to DNS)
    loadBalancer:
      enabled: false
      type: global-accelerator  # or: azure-front-door, cloudflare-lb

  # =========================================================================
  # DECOMMISSIONING
  # =========================================================================
  decommission:
    # Source environment decommissioning
    source:
      enabled: true
      method: terraform-destroy  # or: manual, script
      approvalRequired: true
      retentionPeriod: 720h  # 30 days before destroy
      
      # Resources to preserve (not destroy)
      preserve:
        - type: backup
          location: s3://pki-migration-backups/
        - type: logs
          location: cloudwatch-logs
          retention: 90d

    # Cleanup tasks
    cleanup:
      - name: remove-dns-records
        type: dns
        enabled: true
      - name: revoke-source-certificates
        type: pki
        enabled: false  # Manual process
      - name: delete-source-state
        type: terraform
        enabled: true
        backupFirst: true

  # =========================================================================
  # NOTIFICATIONS AND REPORTING
  # =========================================================================
  notifications:
    channels:
      - type: email
        recipients:
          - platform-team@example.com
          - security-team@example.com
        events:
          - migration-started
          - approval-required
          - migration-completed
          - migration-failed
          - rollback-initiated

      - type: slack
        webhook: https://hooks.slack.com/services/XXX/YYY/ZZZ
        channel: "#pki-migrations"
        events:
          - migration-started
          - migration-completed
          - migration-failed

    reporting:
      enabled: true
      format: html  # or: pdf, json
      location: s3://pki-migration-reports/
      include:
        - resource-inventory
        - validation-results
        - pki-material-audit
        - cost-analysis

status:
  # Populated by orchestrator
  phase: pending  # pending, inventory, export, provision, deploy, migrate, validate, cutover, decommission, completed, failed
  currentGate: none  # none, pre-migration, post-provisioning, pre-cutover, post-cutover
  approvals:
    preMigration:
      status: pending  # pending, approved, rejected, expired
      approvedBy: ""
      approvedAt: ""
    postProvisioning:
      status: pending
      approvedBy: ""
      approvedAt: ""
    preCutover:
      status: pending
      approvedBy: ""
      approvedAt: ""
    postCutover:
      status: pending
      approvedBy: ""
      approvedAt: ""
  
  conditions:
    - type: SourceBackupCompleted
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
    - type: TargetBackendReady
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
    - type: InfrastructureProvisioned
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
    - type: DataMigrationCompleted
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
    - type: SmokeTestsPassed
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
    - type: TrafficVerified
      status: "False"
      lastTransitionTime: "2026-09-12T13:00:00Z"
```

---

## PKI Material Classification

### Classification Levels

| Classification | Description | Migration Method | Approval Required | Examples |
|---------------|-------------|------------------|-------------------|----------|
| **PORTABLE_CONFIG** | Configuration files, templates, non-sensitive settings | Template render, GitOps | No | Cloud-init templates, K8s manifests, ArgoCD apps |
| **PORTABLE_DATA** | Non-sensitive operational data, public certificates | Export/Import, Database dump | No | Issued certificates, CRLs, OCSP responses |
| **REQUIRES_SECURE_MIGRATION** | Sensitive data requiring encrypted channel | Secure channel (mTLS, VPN) | Yes | Database credentials, API keys, HSM partition passwords |
| **NON_EXPORTABLE_KEY_MATERIAL** | Private keys protected by HSM or policy | Manual ceremony, Key ceremony | Yes (Multiple) | Root CA keys, Issuing CA keys, HSM-protected keys |
| **REQUIRES_MANUAL_APPROVAL** | Items requiring explicit security review | Case-by-case | Yes | Custom scripts, Third-party integrations, Legacy configs |

### Classification Rules

```yaml
# pki-material-classification-rules.yaml
rules:
  # Root CA private keys — ALWAYS NON_EXPORTABLE_KEY_MATERIAL
  - match:
      type: private-key
      usage: root-ca
      protection: hsm
    classification: NON_EXPORTABLE_KEY_MATERIAL
    migrationMethod: manual-ceremony
    approvers:
      - pki-security-officer
      - ciso

  # Issuing CA private keys — ALWAYS NON_EXPORTABLE_KEY_MATERIAL
  - match:
      type: private-key
      usage: issuing-ca
      protection: hsm
    classification: NON_EXPORTABLE_KEY_MATERIAL
    migrationMethod: manual-ceremony
    approvers:
      - pki-security-officer

  # Issued certificates — ALWAYS PORTABLE_DATA
  - match:
      type: certificate
      usage: end-entity
    classification: PORTABLE_DATA
    migrationMethod: export-import

  # CRLs — ALWAYS PORTABLE_DATA
  - match:
      type: crl
    classification: PORTABLE_DATA
    migrationMethod: export-import

  # Configuration templates — ALWAYS PORTABLE_CONFIG
  - match:
      type: config-template
      format: [yaml, json, hcl]
    classification: PORTABLE_CONFIG
    migrationMethod: template-render

  # Database credentials — ALWAYS REQUIRES_SECURE_MIGRATION
  - match:
      type: credential
      usage: database
    classification: REQUIRES_SECURE_MIGRATION
    migrationMethod: secure-channel
    approvers:
      - dba-team

  # HSM partition credentials — ALWAYS REQUIRES_SECURE_MIGRATION
  - match:
      type: credential
      usage: hsm-partition
    classification: REQUIRES_SECURE_MIGRATION
    migrationMethod: secure-channel
    approvers:
      - hsm-admin
```

---

## Migration Phases

### Phase 1: Inventory and Assessment

**Objective:** Discover and catalog all resources in the source environment.

**Activities:**
1. Run inventory script against source environment
2. Classify all PKI material according to classification rules
3. Identify dependencies between resources
4. Assess migration complexity and risks
5. Generate inventory report

**Script:** `scripts/migration-orchestrator.sh inventory --source azure --environment lab`

**Outputs:**
- `inventory/azure-lab-resources.json`
- `inventory/azure-lab-pki-material.yaml`
- `inventory/azure-lab-dependencies.dot`
- `inventory/azure-lab-assessment.md`

### Phase 2: Export Provider-Neutral Intent

**Objective:** Export source configuration in a provider-neutral format.

**Activities:**
1. Export Terraform state to provider-neutral JSON
2. Extract variable values and local values
3. Generate provider-neutral resource definitions
4. Create target provider variable mappings

**Script:** `scripts/migration-orchestrator.sh export --source azure --target aws --environment lab`

**Outputs:**
- `export/azure-lab-intent.json`
- `export/azure-lab-variables.yaml`
- `export/aws-lab-mappings.yaml`

### Phase 3: Provision Target Infrastructure

**Objective:** Provision infrastructure in the target cloud.

**Activities:**
1. Generate target Terraform configuration
2. Initialize target backend
3. Run Terraform plan
4. Apply Terraform configuration
5. Verify infrastructure provisioning

**Script:** `scripts/migration-orchestrator.sh provision --target aws --environment lab`

**Approval Gate:** Post-provisioning approval required before proceeding

### Phase 4: Deploy PKI Platform

**Objective:** Deploy PKI platform components to target infrastructure.

**Activities:**
1. Deploy K3s cluster (if not already provisioned)
2. Deploy ArgoCD
3. Deploy PKI platform via GitOps
4. Verify platform components are running

**Script:** `scripts/migration-orchestrator.sh deploy --target aws --environment lab`

### Phase 5: Migrate Non-Sensitive Data and Configuration

**Objective:** Migrate portable configuration and data.

**Activities:**
1. Export portable configuration from source
2. Transform configuration for target provider
3. Import configuration to target
4. Export portable data from source
5. Import data to target
6. Verify data integrity

**Script:** `scripts/migration-orchestrator.sh migrate-data --source azure --target aws --environment lab`

### Phase 6: PKI Migration Procedure

**Objective:** Migrate PKI material with appropriate security controls.

**Activities:**
1. Classify all PKI material
2. For PORTABLE_CONFIG and PORTABLE_DATA: Export and import
3. For REQUIRES_SECURE_MIGRATION: Establish secure channel and migrate
4. For NON_EXPORTABLE_KEY_MATERIAL: Execute manual key ceremony
5. For REQUIRES_MANUAL_APPROVAL: Review and approve each item
6. Validate PKI functionality

**Script:** `scripts/migration-orchestrator.sh migrate-pki --source azure --target aws --environment lab`

**Critical Rules:**
- NEVER automatically export Root CA private keys
- NEVER automatically export Issuing CA private keys
- NEVER automatically export HSM key material
- ALWAYS require multiple approvals for key ceremonies
- ALWAYS use secure channels for sensitive material

### Phase 7: Validation and Smoke Tests

**Objective:** Validate target environment functionality.

**Activities:**
1. Run smoke tests
2. Compare source and target configurations
3. Verify PKI issuance functionality
4. Verify certificate validation
5. Generate validation report

**Script:** `scripts/migration-orchestrator.sh validate --target aws --environment lab`

**Approval Gate:** Pre-cutover approval required before proceeding

### Phase 8: Traffic/DNS Cutover

**Objective:** Switch traffic from source to target.

**Activities:**
1. Update DNS records (weighted or failover)
2. Monitor traffic distribution
3. Verify application functionality
4. Complete cutover

**Script:** `scripts/migration-orchestrator.sh cutover --source azure --target aws --environment lab`

**Approval Gate:** Post-cutover approval required before decommissioning

### Phase 9: Decommission Source

**Objective:** Safely decommission source environment.

**Activities:**
1. Verify all traffic is on target
2. Backup source state and data
3. Destroy source infrastructure
4. Clean up DNS records
5. Archive migration artifacts

**Script:** `scripts/migration-orchestrator.sh decommission --source azure --environment lab`

---

## Approval Gates

### Gate 1: Pre-Migration Approval

**Purpose:** Ensure all prerequisites are met before starting migration.

**Required Approvals:**
- Security team
- Platform team

**Conditions:**
- [ ] Source backup completed
- [ ] Target backend ready
- [ ] PKI material classified
- [ ] Migration manifest reviewed
- [ ] Rollback plan documented

### Gate 2: Post-Provisioning Approval

**Purpose:** Verify target infrastructure is ready for platform deployment.

**Required Approvals:**
- Platform team

**Conditions:**
- [ ] Infrastructure provisioned
- [ ] Network connectivity verified
- [ ] Security groups configured
- [ ] State backend configured

### Gate 3: Pre-Cutover Approval

**Purpose:** Ensure target environment is fully functional before switching traffic.

**Required Approvals:**
- Security team
- Business owner

**Conditions:**
- [ ] Data migration completed
- [ ] Smoke tests passed
- [ ] PKI validation completed
- [ ] Rollback plan verified
- [ ] Monitoring active

### Gate 4: Post-Cutover Approval

**Purpose:** Confirm successful cutover before decommissioning source.

**Required Approvals:**
- Business owner

**Conditions:**
- [ ] Traffic verified on target
- [ ] No critical alerts
- [ ] User acceptance confirmed
- [ ] Documentation updated

---

## Rollback Procedures

### Automatic Rollback Triggers

- Smoke test failures
- Critical alerts during cutover
- PKI validation failures

### Manual Rollback Procedure

```bash
# Step 1: Initiate rollback
scripts/migration-orchestrator.sh rollback --migration-id <id> --reason "<reason>"

# Step 2: Revert DNS records
scripts/migration-orchestrator.sh cutover --revert --migration-id <id>

# Step 3: Verify source environment
scripts/migration-orchestrator.sh validate --source azure --environment lab

# Step 4: Document rollback
scripts/migration-orchestrator.sh report --migration-id <id> --type rollback
```

---

## Security Considerations

1. **PKI Material Handling**
   - Root CA and Issuing CA keys require manual ceremonies
   - HSM key material is never exported automatically
   - Secure channels (mTLS, VPN) for sensitive data migration

2. **State Security**
   - State files are encrypted at rest and in transit
   - State access is logged and audited
   - State backups are encrypted

3. **Network Security**
   - Migration traffic uses encrypted channels
   - Security groups restrict access during migration
   - DNS changes are validated before application

4. **Access Control**
   - Migration orchestrator uses least-privilege credentials
   - Approval gates enforce separation of duties
   - All actions are logged and auditable

---

## Monitoring and Observability

### Metrics

- Migration duration by phase
- Approval gate wait times
- Smoke test success rate
- Resource provisioning success rate
- Data migration integrity check results

### Alerts

- Migration phase failures
- Approval gate timeouts
- Smoke test failures
- PKI validation failures
- Rollback initiations

### Logging

- All migration actions logged with timestamps
- Approval decisions logged with approver identity
- State changes logged with before/after checksums
- PKI material access logged with classification

---

## References

- [Terraform State Migration](https://developer.hashicorp.com/terraform/cli/commands/state/mv)
- [Cross-Cloud Migration Patterns](https://learn.hashicorp.com/tutorials/terraform/cross-cloud-migration)
- [PKI Key Ceremony Best Practices](https://www.cabforum.org/key-ceremony/)
- [DNS Cutover Strategies](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
