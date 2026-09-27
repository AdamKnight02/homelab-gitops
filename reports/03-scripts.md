# Scripts Stage

## Bash Scripts

### scripts/state-backup.sh
- [INFO] Purpose: Terraform State Backup Script

### scripts/state-guard.sh
- [INFO] Purpose: Terraform State Safety Guard — validates before plan/apply/destroy/import/migration.

### scripts/state-validate.sh
- [INFO] Purpose: Terraform State Validation Script that validates provider/customer/environment/component identity, state integrity, and safety rules before any plan/apply/destroy operation.

### homelab-gitops/scripts/migration-orchestrator.sh
- [INFO] Purpose: Cross-Cloud Migration Orchestrator for PKI Platform

### homelab-gitops/scripts/state-migrate.sh
- [INFO] Purpose: Migrates Terraform state from local backend to Azure remote backend with comprehensive safety checks, backup, and validation.

### homelab-gitops/configuration/linux/baseline/logging-baseline.sh
- [INFO] Purpose: Linux Logging Baseline for PKI Platform - Configures centralized logging and log forwarding

### homelab-gitops/configuration/linux/baseline/security-baseline.sh
- [INFO] Purpose: Linux Security Baseline for PKI Platform

### homelab-gitops/configuration/linux/baseline/tls-baseline.sh
- [INFO] Purpose: Linux TLS Baseline for PKI Platform - Configures TLS certificates and settings

## PowerShell Scripts

### configuration/windows/acme/acme-config.ps1
- [INFO] Purpose: Configures a Windows Server as an ACME enrollment server. This script is applied after the baseline configuration.

### configuration/windows/baseline/logging-baseline.ps1
- [INFO] Purpose: Windows Logging Baseline for PKI Platform VMs that configures Windows Event Log sizes, retention, forwarding (if applicable), and PowerShell logging for PKI platform VMs.

### configuration/windows/baseline/security-baseline.ps1
- [INFO] Purpose: Applies foundational security hardening to Windows Server VMs in the PKI platform. Covers account policies, audit policies, Windows Defender, firewall, and SMB hardening.

### configuration/windows/baseline/tls-baseline.ps1
- [INFO] Purpose: Configure TLS/SSL protocol versions, cipher suites, and certificate settings on Windows Server VMs to disable legacy protocols and enforce modern cryptographic standards

### configuration/windows/gateway/gateway-config.ps1
- [WARN] Script contains multiple TODO stubs indicating incomplete implementation
- [INFO] Purpose: Configure Windows Server as IIS/ARR reverse-proxy gateway for PKI services

### configuration/windows/pki/pki-vm-config.ps1
- [INFO] Purpose: Configures a Windows Server as a PKI CA/OCSP/CRL server. This script is applied after the baseline configuration and requires parameters for customer ID, environment, and CA type.

### configuration/windows/scep/scep-config.ps1
- [INFO] Purpose: Configures a Windows Server as a SCEP enrollment server. This script is applied after the baseline configuration.

## Python Scripts

### tests/run_tests.py
- [INFO] Purpose: PKI Platform Test Runner: orchestrates test levels 1-7 plus provider/tier and external-CA matrices, generates JSON and text reports

### tests/level1-static/test_static_validation.py
- [INFO] Purpose: Syntax check for static validation test file

### tests/level2-cloud/test_cloud_infrastructure.py
- [INFO] Purpose: Level 2 tests validating Azure/AWS cloud infrastructure (CLI auth, resource groups/VPCs, VMs/EC2, NSG/SG rules, public IPs, EBS encryption) via cloud CLIs.

### tests/level3-kubernetes/test_kubernetes.py
- [INFO] Purpose: Syntax-check Kubernetes tests for level 3

### tests/level4-platform/test_platform.py
- [INFO] Purpose: Level 4 platform health tests (needs kubectl and a running platform)

### tests/level5-pki/test_pki_protocols.py
- [INFO] Purpose: Level 5 PKI protocol tests (needs kubectl and EJBCA)

### tests/level6-idempotency/test_idempotency.py
- [INFO] Purpose: Level 6 idempotency tests (needs kubectl and terraform state)

### tests/level7-lifecycle/test_lifecycle.py
- [INFO] Purpose: Level 7 lifecycle tests (needs cloud credentials and an ephemeral env)
