# PKI Migration Safety Guide

## Overview

This document defines the safety rules, procedures, and controls for migrating PKI (Public Key Infrastructure) material during cross-cloud migrations. PKI migration is the highest-risk phase of any platform migration due to the sensitivity of cryptographic key material.

**Critical Principle:** The security of the PKI platform depends on the confidentiality and integrity of its private keys. Any compromise during migration can invalidate the entire trust chain.

---

## PKI Material Classification

### Classification Levels

| Level | Name | Description | Migration Method | Approval Required |
|-------|------|-------------|------------------|-------------------|
| 1 | **PORTABLE_CONFIG** | Configuration files, templates, non-sensitive settings | Template render, GitOps | No |
| 2 | **PORTABLE_DATA** | Non-sensitive operational data, public certificates | Export/Import, Database dump | No |
| 3 | **REQUIRES_SECURE_MIGRATION** | Sensitive data requiring encrypted channel | Secure channel (mTLS, VPN) | Yes (Single) |
| 4 | **NON_EXPORTABLE_KEY_MATERIAL** | Private keys protected by HSM or policy | Manual ceremony, Key ceremony | Yes (Multiple) |
| 5 | **REQUIRES_MANUAL_APPROVAL** | Items requiring explicit security review | Case-by-case | Yes (Security Officer) |

### Classification Decision Tree

```
Is the material a private key?
├── YES ──▶ Is it protected by HSM?
│           ├── YES ──▶ NON_EXPORTABLE_KEY_MATERIAL
│           └── NO ───▶ Is it a Root CA or Issuing CA key?
│                       ├── YES ──▶ NON_EXPORTABLE_KEY_MATERIAL
│                       └── NO ───▶ REQUIRES_SECURE_MIGRATION
│
└── NO ───▶ Is it a certificate or CRL?
            ├── YES ──▶ PORTABLE_DATA
            └── NO ───▶ Is it a configuration template?
                        ├── YES ──▶ PORTABLE_CONFIG
                        └── NO ───▶ Is it a credential or secret?
                                    ├── YES ──▶ REQUIRES_SECURE_MIGRATION
                                    └── NO ───▶ REQUIRES_MANUAL_APPROVAL
```

---

## Safety Rules

### Rule 1: Never Automatically Export Root CA Private Keys

**Rationale:** Root CA compromise invalidates the entire PKI hierarchy.

**Implementation:**
- Root CA private keys are classified as NON_EXPORTABLE_KEY_MATERIAL
- Migration requires a manual key ceremony with multiple approvers
- Root CA keys should remain in HSM or be migrated via HSM-to-HSM secure transfer

**Procedure:**
1. Generate new Root CA in target environment (preferred)
2. Or: Perform HSM-to-HSM key transfer using vendor-specific secure procedure
3. Or: Export Root CA key to encrypted USB in secure facility (last resort)
4. Import to target HSM with dual control
5. Destroy export media securely

### Rule 2: Never Automatically Export Issuing CA Private Keys

**Rationale:** Issuing CA compromise allows issuance of fraudulent certificates.

**Implementation:**
- Issuing CA private keys are classified as NON_EXPORTABLE_KEY_MATERIAL
- Migration requires security officer approval
- Consider generating new Issuing CA in target and cross-signing

**Procedure:**
1. Generate new Issuing CA in target environment
2. Cross-sign new Issuing CA with existing Root CA
3. Update certificate profiles to use new Issuing CA
4. Revoke old Issuing CA after validation period
5. Or: Migrate via HSM-to-HSM secure transfer with dual control

### Rule 3: Never Automatically Export HSM Key Material

**Rationale:** HSMs are designed to prevent key export. Bypassing this protection defeats the purpose of HSM.

**Implementation:**
- All HSM-protected keys are classified as NON_EXPORTABLE_KEY_MATERIAL
- Migration requires HSM vendor-specific secure procedures
- HSM-to-HSM migration must use encrypted channels

**Procedure:**
1. Verify HSM vendor supports secure key export/import
2. Establish secure channel between source and target HSMs
3. Use HSM vendor tools for key migration
4. Verify key integrity after migration
5. Update HSM access controls

### Rule 4: Always Backup State Before Migration

**Rationale:** State corruption during migration can result in loss of infrastructure management capability.

**Implementation:**
- Automated backup before any migration operation
- Backup verification with checksums
- Multiple backup copies in different locations

**Procedure:**
```bash
# Backup state
terraform state pull > backups/terraform.tfstate.$(date +%Y%m%d-%H%M%S)

# Verify backup
terraform state pull | sha256sum
sha256sum backups/terraform.tfstate.*

# Store in multiple locations
aws s3 cp backups/ s3://pki-backups/state/ --recursive
az storage blob upload-batch --source backups/ --destination state-backups/
```

### Rule 5: After Migration, Terraform Plan Must Show No Unexplained Changes

**Rationale:** Unexplained changes indicate state corruption or configuration drift.

**Implementation:**
- Post-migration plan verification
- Detailed exit code checking
- Manual review of any changes

**Procedure:**
```bash
# Run plan with detailed exit code
terraform plan -detailed-exitcode

# Exit codes:
# 0 = No changes (expected)
# 1 = Error (investigate)
# 2 = Changes present (investigate)

# If changes present, review carefully
terraform plan -out=plan.out
terraform show plan.out

# Only proceed if changes are expected and documented
terraform apply plan.out
```

### Rule 6: Never Commit State Files to Git

**Rationale:** State files contain sensitive data including private keys, passwords, and infrastructure details.

**Implementation:**
- .gitignore includes all state file patterns
- Pre-commit hooks prevent state file commits
- Regular audits of Git history for state files

**Procedure:**
```bash
# .gitignore
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl

# Pre-commit hook
#!/bin/bash
if git diff --cached --name-only | grep -E '\.tfstate'; then
  echo "ERROR: Attempting to commit state file"
  exit 1
fi
```

### Rule 7: Never Print Secrets from State

**Rationale:** State files may contain sensitive data that should not be exposed in logs or console output.

**Implementation:**
- Use `terraform output -json` with jq filtering for non-sensitive outputs only
- Mark sensitive outputs with `sensitive = true`
- Use external secret management for sensitive data

**Procedure:**
```bash
# BAD: Prints all outputs including sensitive
terraform output

# GOOD: Prints only non-sensitive outputs
terraform output -json | jq 'to_entries | map(select(.value.sensitive == false)) | from_entries'

# GOOD: Use external secret management
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "pki-platform/db-password"
}
```

---

## PKI Migration Procedures

### Procedure 1: Certificate Authority Migration

#### Scenario A: New CA Hierarchy in Target (Recommended)

**Advantages:**
- No key material migration required
- Clean separation between old and new
- Easier rollback

**Procedure:**
1. Generate new Root CA in target HSM
2. Generate new Issuing CA in target HSM
3. Cross-sign new Issuing CA with existing Root CA (if continuity required)
4. Issue new certificates from new Issuing CA
5. Update certificate profiles and validation to trust new hierarchy
6. Revoke old certificates after migration period
7. Decommission old CA hierarchy

#### Scenario B: Existing CA Migration (High Risk)

**Only when absolutely necessary (e.g., regulatory requirements)**

**Procedure:**
1. **Pre-migration approval** from security officer and CISO
2. **Backup** all CA certificates and CRLs
3. **Secure channel** establishment between source and target HSMs
4. **Key ceremony** with dual control:
   - Two authorized personnel present
   - HSM vendor tools for key export/import
   - Key integrity verification
   - Audit logging
5. **Post-migration validation**:
   - Verify key functionality
   - Test certificate issuance
   - Verify certificate validation
6. **Update** CA certificates and CRL distribution points
7. **Monitor** for issues

### Procedure 2: Certificate Migration

**Certificates are PORTABLE_DATA — safe to migrate**

**Procedure:**
1. Export certificates from source database
2. Verify certificate integrity (signature validation)
3. Import certificates to target database
4. Verify certificate chain validation
5. Update certificate revocation status

**Script:**
```bash
# Export certificates
step ca certificates --ca-url https://source-ca --root root-ca.crt > certificates.pem

# Verify certificates
step certificate verify certificates.pem --roots root-ca.crt

# Import to target
step ca certificates --ca-url https://target-ca --root root-ca.crt --import certificates.pem
```

### Procedure 3: CRL Migration

**CRLs are PORTABLE_DATA — safe to migrate**

**Procedure:**
1. Export CRLs from source
2. Verify CRL signatures
3. Import CRLs to target
4. Update CRL distribution points
5. Verify CRL accessibility

### Procedure 4: OCSP Responder Migration

**OCSP configuration is PORTABLE_CONFIG**

**Procedure:**
1. Export OCSP responder configuration
2. Update configuration for target environment
3. Deploy OCSP responder in target
4. Update OCSP URLs in certificates
5. Verify OCSP responses

---

## Key Ceremony Procedures

### Root CA Key Ceremony

**Participants:**
- Security Officer (SO)
- PKI Administrator (PA)
- Witness (W)

**Materials:**
- Source HSM with Root CA key
- Target HSM (initialized)
- HSM vendor migration tools
- Encrypted USB drive (if required)
- Audit log book

**Procedure:**

1. **Pre-ceremony checks**
   - [ ] Verify all participants are authorized
   - [ ] Verify HSM firmware versions
   - [ ] Verify secure facility access
   - [ ] Record ceremony start time

2. **Key export (if supported)**
   - [ ] SO authenticates to source HSM
   - [ ] PA authenticates to source HSM (dual control)
   - [ ] Export Root CA key to encrypted USB
   - [ ] Verify export integrity
   - [ ] Record export hash

3. **Key transport**
   - [ ] Transport USB in tamper-evident bag
   - [ ] Maintain chain of custody
   - [ ] Record transport details

4. **Key import**
   - [ ] SO authenticates to target HSM
   - [ ] PA authenticates to target HSM (dual control)
   - [ ] Import Root CA key from USB
   - [ ] Verify import integrity
   - [ ] Record import hash

5. **Post-ceremony**
   - [ ] Destroy USB securely (degauss or shred)
   - [ ] Verify Root CA functionality
   - [ ] Record ceremony completion
   - [ ] Sign audit log

### Issuing CA Key Ceremony

Similar to Root CA ceremony but with Security Officer approval only.

---

## Validation Procedures

### Post-Migration PKI Validation

**Test 1: Certificate Issuance**
```bash
# Issue test certificate
step ca certificate test.migration.pki test.crt test.key --ca-url https://target-ca

# Verify certificate
step certificate inspect test.crt
step certificate verify test.crt --roots root-ca.crt
```

**Test 2: Certificate Validation**
```bash
# Validate existing certificate
step certificate verify existing.crt --roots root-ca.crt --ca-url https://target-ca
```

**Test 3: CRL Verification**
```bash
# Check CRL
step crl inspect https://target-ca/crl
```

**Test 4: OCSP Verification**
```bash
# Check OCSP status
step ca certificate status test.crt --ca-url https://target-ca
```

### State Validation

```bash
# Verify state integrity
terraform state pull | sha256sum
# Compare with backup

# Verify no unexplained changes
terraform plan -detailed-exitcode
# Expected: 0

# Verify resource count
terraform state list | wc -l
# Compare with expected count
```

---

## Incident Response

### Compromise Suspected During Migration

**Immediate Actions:**
1. **STOP** all migration activities
2. **ISOLATE** affected systems
3. **NOTIFY** security team and CISO
4. **PRESERVE** evidence (logs, state files, HSM audit logs)

**Investigation:**
1. Review HSM audit logs
2. Review migration orchestrator logs
3. Review network traffic logs
4. Interview ceremony participants

**Remediation:**
1. If Root CA compromised: Revoke entire hierarchy, rebuild from scratch
2. If Issuing CA compromised: Revoke Issuing CA, issue new one
3. If HSM compromised: Replace HSM, migrate keys securely
4. Document incident and lessons learned

### State Corruption During Migration

**Immediate Actions:**
1. **STOP** migration
2. **RESTORE** state from backup
3. **VERIFY** state integrity

**Procedure:**
```bash
# Restore from backup
terraform state push backups/terraform.tfstate.20260912-120000

# Verify
terraform plan -detailed-exitcode
# Expected: 0
```

---

## Audit and Compliance

### Audit Requirements

| Event | Log Location | Retention |
|-------|-------------|-----------|
| Key ceremony | HSM audit log, Ceremony log book | 7 years |
| State migration | Terraform logs, Orchestrator logs | 3 years |
| Approval decisions | Orchestrator database, Email | 3 years |
| Certificate issuance | CA database, SIEM | 3 years |
| CRL publication | CA database, Web server logs | 1 year |

### Compliance Mapping

| Control | Framework | Implementation |
|---------|-----------|----------------|
| Key protection | NIST SP 800-57 | HSM storage, Dual control |
| Key migration | NIST SP 800-57 | Secure ceremony, Audit logging |
| State encryption | NIST SP 800-53 | KMS encryption, TLS |
| Access control | NIST SP 800-53 | RBAC, Least privilege |
| Audit logging | NIST SP 800-53 | Comprehensive logging, SIEM integration |

---

## Checklists

### Pre-Migration Checklist

- [ ] PKI material classified according to rules
- [ ] Root CA keys identified and protected
- [ ] Issuing CA keys identified and protected
- [ ] HSM key material identified and protected
- [ ] Backup of all state files completed
- [ ] Backup of all PKI data completed
- [ ] Migration manifest reviewed and approved
- [ ] Approval gates configured
- [ ] Rollback plan documented
- [ ] Security team notified
- [ ] Ceremony participants identified and trained

### Post-Migration Checklist

- [ ] State integrity verified (checksums match)
- [ ] Terraform plan shows no unexplained changes
- [ ] PKI validation tests passed
- [ ] Certificate issuance test passed
- [ ] Certificate validation test passed
- [ ] CRL verification passed
- [ ] OCSP verification passed
- [ ] Monitoring active and alerting
- [ ] Documentation updated
- [ ] Audit logs reviewed
- [ ] Approval gates completed

---

## References

- [NIST SP 800-57: Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [NIST SP 800-53: Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [CA/Browser Forum: Key Ceremony](https://cabforum.org/key-ceremony/)
- [HSM Vendor Migration Guides](https://www.thalesgroup.com/en/markets/digital-identity-and-security/data-protection/hardware-security-modules)
- [Terraform State Security](https://developer.hashicorp.com/terraform/language/state/sensitive-data)
