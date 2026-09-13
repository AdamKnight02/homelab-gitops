# Testing Architecture

## Overview

This document defines the comprehensive testing architecture for the Machine Identity Platform. Testing is layered, from static validation to full lifecycle testing, with machine-readable and human-readable output.

---

## Test Levels

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LEVEL 7: LIFECYCLE TESTS                                                     │
│  deploy → health test → destroy → verify cleanup → redeploy → health test   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 6: IDEMPOTENCY TESTS                                                   │
│  deploy → rerun deploy → expect NO unnecessary replacement                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 5: PKI PROTOCOL TESTS                                                  │
│  certificate issuance, chain verification, OCSP, CRL, revocation, ACME, SCEP│
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 4: PLATFORM TESTS                                                      │
│  EJBCA health, PostgreSQL, RabbitMQ, OpenBao, SPIRE, cert-api, cert-worker  │
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 3: KUBERNETES TESTS                                                    │
│  nodes Ready, namespaces, Deployments, StatefulSets, Pods, Services, PVCs   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 2: CLOUD INFRASTRUCTURE TESTS                                          │
│  resource counts, networks, VMs, databases, storage, identities, firewall   │
├─────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 1: STATIC VALIDATION                                                   │
│  schema, terraform fmt/validate, YAML, Helm rendering, K8s YAML, GitOps     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Test Framework

### Directory Structure

```
tests/
├── __init__.py
├── run_tests.py                    # Main test runner
├── lib/
│   ├── __init__.py
│   ├── test_framework.py           # Shared test library
│   └── powershell_fallback.py      # PowerShell static validation
├── config/
│   ├── test-config.yaml            # Test profiles, endpoints
│   └── external-ca-test-config.yaml # External CA test config
├── level1-static/
│   ├── __init__.py
│   └── test_static_validation.py
├── level2-cloud/
│   ├── __init__.py
│   └── test_cloud_infrastructure.py
├── level3-kubernetes/
│   ├── __init__.py
│   └── test_kubernetes.py
├── level4-platform/
│   ├── __init__.py
│   └── test_platform.py
├── level5-pki/
│   ├── __init__.py
│   └── test_pki_protocols.py
├── level6-idempotency/
│   ├── __init__.py
│   └── test_idempotency.py
├── level7-lifecycle/
│   ├── __init__.py
│   └── test_lifecycle.py
└── matrix/
    ├── __init__.py
    ├── external-ca/
    │   ├── __init__.py
    │   └── test_external_ca_matrix.py
    └── provider-tier/
        ├── __init__.py
        └── test_provider_tier_matrix.py
```

### Test Result Format

```json
{
  "test_run_id": "2026-09-12T13:00:00Z",
  "customer_id": "contoso",
  "environment": "prod",
  "provider": "azure",
  "tier": "standard",
  "summary": {
    "total": 45,
    "pass": 38,
    "fail": 2,
    "skip": 3,
    "blocked": 2,
    "error": 0
  },
  "results": [
    {
      "test_id": "L1-001",
      "level": 1,
      "name": "Customer schema validation",
      "status": "PASS",
      "duration_ms": 150,
      "message": "Schema v2 validated successfully"
    },
    {
      "test_id": "L2-001",
      "level": 2,
      "name": "VPC exists",
      "status": "PASS",
      "duration_ms": 2500,
      "message": "VPC vpc-12345 found"
    },
    {
      "test_id": "L5-001",
      "level": 5,
      "name": "Certificate issuance",
      "status": "BLOCKED",
      "duration_ms": 0,
      "message": "External CA credentials not configured"
    }
  ]
}
```

---

## Level 1: Static Validation

### Tests

| Test ID | Name | Description | Tool |
|---------|------|-------------|------|
| L1-001 | Customer schema validation | Validate customer config against schema v2 | Python |
| L1-002 | Terraform fmt | Check Terraform formatting | terraform fmt |
| L1-003 | Terraform validate | Validate Terraform configuration | terraform validate |
| L1-004 | Pipeline YAML validation | Validate Azure DevOps pipeline YAML | Python/yamllint |
| L1-005 | Helm rendering | Render Helm templates | helm template |
| L1-006 | Kubernetes YAML validation | Validate K8s manifests | kubectl apply --dry-run |
| L1-007 | JSON/YAML syntax | Validate JSON/YAML syntax | Python |
| L1-008 | GitOps structure | Validate GitOps directory structure | Python |
| L1-009 | PowerShell static validation | Validate PowerShell scripts (static) | Python |
| L1-010 | External CA schema validation | Validate external CA config | Python |

### PowerShell Fallback

Since PowerShell is not installed, static validation is performed:

```python
# tests/lib/powershell_fallback.py
def validate_powershell_static(script_path: str) -> TestResult:
    """
    Static validation of PowerShell scripts without executing them.
    Checks:
    - Syntax (basic)
    - Module dependencies
    - Configuration schema
    - Best practices
    """
    result = TestResult(
        test_id="L1-009",
        level=1,
        name="PowerShell static validation",
        status=TestStatus.BLOCKED,
        message="PowerShell not installed — static validation only"
    )

    # Perform static checks
    # ... (syntax, dependencies, schema)

    return result
```

---

## Level 2: Cloud Infrastructure Tests

### Tests

| Test ID | Name | Description | Provider |
|---------|------|-------------|----------|
| L2-001 | VPC/VNet exists | Verify VPC/VNet was created | All |
| L2-002 | Subnets correct | Verify subnets are configured correctly | All |
| L2-003 | VMs expected | Verify expected number of VMs | All |
| L2-004 | Database expected | Verify database exists (if configured) | All |
| L2-005 | Storage expected | Verify storage exists (if configured) | All |
| L2-006 | Identities expected | Verify IAM/RAM identities exist | All |
| L2-007 | Firewall rules expected | Verify security groups/NSGs | All |
| L2-008 | No unexpected public exposure | Verify no unexpected public IPs | All |
| L2-009 | Resource count matches tier | Verify resource counts match tier | All |
| L2-010 | Cost within limits | Verify estimated cost within limits | All |

### Provider-Specific Tests

| Provider | Test ID | Name | Description |
|----------|---------|------|-------------|
| Azure | L2-AZ-001 | Resource Group exists | Verify Azure Resource Group |
| Azure | L2-AZ-002 | VNet exists | Verify Azure Virtual Network |
| Azure | L2-AZ-003 | NSG configured | Verify Network Security Group |
| AWS | L2-AWS-001 | VPC exists | Verify AWS VPC |
| AWS | L2-AWS-002 | Security Group configured | Verify Security Group |
| AWS | L2-AWS-003 | IAM Role configured | Verify IAM Role |
| Alibaba | L2-ALI-001 | VPC exists | Verify Alibaba VPC |
| Alibaba | L2-ALI-002 | VSwitch configured | Verify VSwitch |
| Alibaba | L2-ALI-003 | Security Group configured | Verify Security Group |

---

## Level 3: Kubernetes Tests

### Tests

| Test ID | Name | Description |
|---------|------|-------------|
| L3-001 | Nodes Ready | Verify all nodes are Ready |
| L3-002 | Namespaces present | Verify required namespaces exist |
| L3-003 | Deployments Available | Verify all Deployments are Available |
| L3-004 | StatefulSets Ready | Verify all StatefulSets are Ready |
| L3-005 | Pods Running | Verify all Pods are Running |
| L3-006 | Services created | Verify all Services are created |
| L3-007 | Ingress routes healthy | Verify Ingress routes are healthy |
| L3-008 | PVCs bound | Verify all PVCs are Bound |
| L3-009 | Argo apps Synced | Verify all Argo CD apps are Synced |
| L3-010 | Argo apps Healthy | Verify all Argo CD apps are Healthy |

---

## Level 4: Platform Tests

### Tests

| Test ID | Name | Description |
|---------|------|-------------|
| L4-001 | EJBCA health | Verify EJBCA is healthy |
| L4-002 | PostgreSQL connectivity | Verify PostgreSQL is accessible |
| L4-003 | RabbitMQ connectivity | Verify RabbitMQ is accessible |
| L4-004 | OpenBao health | Verify OpenBao is healthy |
| L4-005 | SPIRE health | Verify SPIRE is healthy |
| L4-006 | cert-api health | Verify cert-api is healthy |
| L4-007 | cert-worker health | Verify cert-worker is healthy |
| L4-008 | Prometheus targets | Verify Prometheus targets are up |
| L4-009 | Grafana health | Verify Grafana is healthy |
| L4-010 | External CA gateway health | Verify external CA gateway is healthy |

---

## Level 5: PKI Protocol Tests

### Tests

| Test ID | Name | Description | Safety |
|---------|------|-------------|--------|
| L5-001 | Certificate issuance | Issue a test certificate | Test profile |
| L5-002 | Chain verification | Verify certificate chain | Test profile |
| L5-003 | Correct issuer | Verify certificate issuer | Test profile |
| L5-004 | SAN validation | Verify certificate SANs | Test profile |
| L5-005 | Expiration validation | Verify certificate expiration | Test profile |
| L5-006 | OCSP response | Verify OCSP response | Test profile |
| L5-007 | CRL presence | Verify CRL is present | Test profile |
| L5-008 | Revocation | Revoke a test certificate | Test profile |
| L5-009 | Post-revocation validation | Verify revoked certificate is invalid | Test profile |
| L5-010 | ACME enrollment | Test ACME enrollment | Test account |
| L5-011 | SCEP enrollment | Test SCEP enrollment | Test profile |
| L5-012 | Inventory update | Verify inventory is updated | Test profile |
| L5-013 | Audit event creation | Verify audit events are created | Test profile |

**Safety Rules:**
- NEVER use production CA/private-key material for destructive smoke tests
- ALWAYS use dedicated test profiles/end entities
- NEVER consume production issuance quotas unnecessarily
- ALWAYS clean up test certificates after testing

---

## Level 6: Idempotency Tests

### Tests

| Test ID | Name | Description |
|---------|------|-------------|
| L6-001 | Deploy idempotency | Deploy → rerun deploy → expect NO changes |
| L6-002 | GitOps sync idempotency | GitOps sync → rerun sync → expect NO drift |
| L6-003 | Configuration idempotency | Config apply → rerun apply → expect NO destructive change |
| L6-004 | External CA idempotency | Deploy external CA → rerun → expect NO duplicate |
| L6-005 | Monitoring idempotency | Deploy monitoring → rerun → expect NO duplicate |

---

## Level 7: Lifecycle Tests

### Tests

| Test ID | Name | Description | Cost |
|---------|------|-------------|------|
| L7-001 | Deploy | Deploy environment | $$$ |
| L7-002 | Health test | Run health tests | $ |
| L7-003 | Destroy | Destroy environment | $$$ |
| L7-004 | Verify cleanup | Verify all resources removed | $ |
| L7-005 | Redeploy | Redeploy environment | $$$ |
| L7-006 | Health test | Run health tests again | $ |

**Cost Warning:** Lifecycle tests create and destroy real cloud resources. They should only be run when cost and authorization allow.

---

## Test Matrices

### External CA Test Matrix

| Test | Let's Encrypt | DigiCert | Sectigo | Custom |
|------|-------------|----------|---------|--------|
| Deploy Environment + None | N/A | N/A | N/A | N/A |
| Deploy Environment + Provider | STATIC | STATIC | STATIC | STATIC |
| Add-On + Provider | STATIC | STATIC | STATIC | STATIC |
| Add-On rerun + Provider | STATIC | STATIC | STATIC | STATIC |
| Remove Add-On | STATIC | STATIC | STATIC | STATIC |
| Invalid provider | STATIC | STATIC | STATIC | STATIC |
| Missing credentials | N/A | STATIC | STATIC | STATIC |
| Duplicate gateway | STATIC | STATIC | STATIC | STATIC |
| Unsupported capability | STATIC | STATIC | STATIC | STATIC |

**Legend:** STATIC = Static validation | PLAN = Terraform plan | LIVE = Live deployment | BLOCKED = Blocked

### Provider/Tier Test Matrix

| Provider | Economy | Standard | Enterprise |
|----------|---------|----------|------------|
| Azure | STATIC | STATIC | STATIC |
| AWS | STATIC | STATIC | STATIC |
| Alibaba | STATIC | STATIC | BLOCKED |

**Legend:** STATIC = Static validation | PLAN = Terraform plan | LIVE = Live deployment | BLOCKED = Blocked (no credentials)

---

## Test Configuration

### Test Profiles

```yaml
# tests/config/test-config.yaml
test_profiles:
  certificate_issuance:
    common_name: "test.pki-platform.local"
    san_dns_names:
      - "test.pki-platform.local"
      - "test2.pki-platform.local"
    validity_days: 30
    key_algorithm: "RSA"
    key_size: 2048

  acme_enrollment:
    domain: "test.pki-platform.local"
    email: "test@pki-platform.local"
    staging: true

  scep_enrollment:
    common_name: "test.pki-platform.local"
    challenge_password: "test-challenge"

test_endpoints:
  ejbca:
    url: "https://ejbca.pki-platform.local:8443/ejbca"
    health_path: "/ejbca/health"

  openbao:
    url: "https://openbao.pki-platform.local:8200"
    health_path: "/v1/sys/health"

  spire:
    url: "https://spire.pki-platform.local:8081"
    health_path: "/health"

  prometheus:
    url: "http://prometheus.monitoring:9090"
    health_path: "/-/healthy"

  grafana:
    url: "http://grafana.monitoring:3000"
    health_path: "/api/health"
```

### External CA Test Configuration

```yaml
# tests/config/external-ca-test-config.yaml
external_ca_tests:
  letsencrypt:
    enabled: true
    staging: true
    test_domain: "test.pki-platform.local"
    test_email: "test@pki-platform.local"

  digicert:
    enabled: false  # Requires credentials
    test_domain: "test.pki-platform.local"
    credential_ref: "digicert/api-key"

  sectigo:
    enabled: false  # Requires credentials
    test_domain: "test.pki-platform.local"
    credential_ref: "sectigo/api-key"

  custom:
    enabled: false  # Requires custom adapter
    test_domain: "test.pki-platform.local"
    credential_ref: "custom/api-key"
```

---

## Test Runner

### Usage

```bash
# Run all tests
python3 tests/run_tests.py --customer contoso --environment prod --provider azure --tier standard

# Run specific level
python3 tests/run_tests.py --level 1 --customer contoso --environment prod

# Run specific test
python3 tests/run_tests.py --test L1-001 --customer contoso --environment prod

# Run with JSON output
python3 tests/run_tests.py --customer contoso --environment prod --output json

# Run with human-readable output
python3 tests/run_tests.py --customer contoso --environment prod --output text
```

### Output Formats

**JSON (machine-readable):**
```json
{
  "test_run_id": "2026-09-12T13:00:00Z",
  "summary": {"total": 45, "pass": 38, "fail": 2, "skip": 3, "blocked": 2},
  "results": [...]
}
```

**Text (human-readable):**
```
================================================
PKI PLATFORM TEST REPORT
================================================

Customer: contoso
Environment: prod
Provider: azure
Tier: standard

SUMMARY:
  Total: 45
  PASS: 38
  FAIL: 2
  SKIP: 3
  BLOCKED: 2

RESULTS:
  [PASS] L1-001: Customer schema validation (150ms)
  [PASS] L1-002: Terraform fmt (50ms)
  [FAIL] L2-001: VPC exists (2500ms) - VPC not found
  [SKIP] L5-001: Certificate issuance (0ms) - Test profile not configured
  [BLOCKED] L5-010: ACME enrollment (0ms) - External CA credentials not configured

================================================
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial testing architecture |
