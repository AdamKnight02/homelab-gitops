# Smoke Tests

## Overview

Smoke tests provide fast, automated validation that the PKI platform is fundamentally operational. They are designed to run in under 5 minutes and catch critical failures before deeper testing.

**Philosophy:** Never classify an untested component as PASS. Every result must be PASS, FAIL, SKIP, BLOCKED, or ERROR with a clear reason.

---

## Test Levels

| Level | Name | Description | Requires |
|-------|------|-------------|----------|
| 1 | Static Validation | Schema, format, structure checks | Nothing (offline) |
| 2 | Cloud Infrastructure | Cloud resource validation | Cloud CLI + credentials |
| 3 | Kubernetes | Cluster state, workloads, GitOps sync | kubectl + cluster |
| 4 | Platform Health | Component health (EJBCA, PG, Bao, SPIRE, etc.) | kubectl + running platform |
| 5 | PKI Protocols | Certificate issuance, chain, OCSP, CRL, revocation | kubectl + EJBCA |
| 6 | Idempotency | Deploy→redeploy→no changes, GitOps no drift | kubectl + terraform state |
| 7 | Lifecycle | Deploy→test→destroy→verify→redeploy→test | Cloud credentials + ephemeral env |

---

## Running Smoke Tests

### Quick Start (No Cluster)

```bash
# Static validation only — fastest, no dependencies
python3 tests/run_tests.py --level static

# Static + provider/tier matrix
python3 tests/run_tests.py --level quick
```

### With Cluster Access

```bash
# Platform health check
python3 tests/run_tests.py --level 1,3,4

# Full PKI protocol test
python3 tests/run_tests.py --level 1,3,4,5

# Everything (including destructive lifecycle tests)
python3 tests/run_tests.py --level all-live --provider azure
```

### Specific Provider

```bash
# Azure only
python3 tests/run_tests.py --level 2 --provider azure

# AWS only
python3 tests/run_tests.py --level 2 --provider aws
```

### Custom Output Directory

```bash
python3 tests/run_tests.py --level quick --output-dir /tmp/test-results
```

---

## Test Profiles

Use predefined profiles from `tests/config/test-config.yaml`:

| Profile | Levels | Use Case |
|---------|--------|----------|
| `static` | 1, matrix | CI pipeline, pre-commit |
| `quick` | 1, matrix | Quick smoke test |
| `cloud` | 1, 2, matrix | Cloud validation |
| `platform` | 1, 3, 4 | Platform health check |
| `pki` | 1, 3, 4, 5 | PKI operations |
| `full` | all | Complete validation (destructive) |
| `ci` | 1, matrix, extca | CI/CD pipeline |

---

## Level 1: Static Validation

Runs entirely offline. Validates:

- **Terraform formatting** (`terraform fmt -check`)
- **Terraform validation** (`terraform validate`) for Azure and AWS
- **YAML syntax** for all `.yaml`/`.yml` files
- **K8s manifest structure** (apiVersion, kind, metadata.name)
- **ArgoCD Application structure** (spec.destination, spec.source)
- **Kustomization references** (all resources exist)
- **GitOps directory structure** (bootstrap, apps, overlays)
- **Terraform variable defaults** and validation blocks
- **No hardcoded secrets** in code
- **Tagging standards** (Project, Environment, ManagedBy, etc.)
- **NetworkPolicy presence** for PKI namespaces
- **PowerShell availability** (falls back to static validation)

## Level 2: Cloud Infrastructure

Validates deployed cloud resources:

**Azure:**
- CLI authentication
- Resource group existence
- VNet configuration
- VM running state
- NSG rule restrictiveness
- Public IP audit

**AWS:**
- CLI authentication
- VPC configuration
- EC2 instance state
- Security group restrictiveness
- Elastic IP audit
- EBS encryption

**Alibaba:** BLOCKED — `aliyun` CLI not installed

## Level 3: Kubernetes

Validates cluster state:

- Node readiness
- Expected namespaces exist
- Deployment availability
- StatefulSet readiness
- Pod health (Running/Succeeded)
- Service endpoints
- PVC binding
- ArgoCD app sync status
- ArgoCD app health
- NetworkPolicy application
- SPIRE agent DaemonSet

## Level 4: Platform Health

Validates platform components:

- EJBCA health endpoint
- PostgreSQL readiness
- RabbitMQ status
- OpenBao seal status
- SPIRE server health
- cert-api readiness
- cert-worker readiness
- Prometheus target health
- Grafana readiness

## Level 5: PKI Protocols

Validates PKI operations using **dedicated test profiles**:

- Certificate issuance (test end entity + CSR)
- Chain verification (CA hierarchy)
- OCSP responder availability
- CRL retrieval
- Certificate revocation workflow
- ACME endpoint availability
- SCEP endpoint availability
- Certificate inventory database
- Audit trail

**Safety:** Uses `TestServerProfile`, `TestEndEntityProfile`, and `test-qa-*` end entities. Never touches production CA material.

## Level 6: Idempotency

Validates deployment stability:

- Terraform plan shows no changes (idempotent)
- K8s manifest re-apply produces no diff
- ArgoCD sync shows no drift
- Kustomize build is deterministic

## Level 7: Lifecycle

**⚠️ DESTRUCTIVE** — Only run against ephemeral environments.

Full lifecycle: deploy → validate → destroy → verify cleanup → redeploy → validate.

Safety check verifies `ephemeral=true` before proceeding.

---

## Output Formats

### JSON Report

Machine-readable report at `tests/reports/<timestamp>/test-report.json`:

```json
{
  "report_version": "1.0",
  "generated_at": "2026-09-12T18:00:00Z",
  "environment": { ... },
  "summary": {
    "total_suites": 3,
    "total_tests": 25,
    "total_passed": 18,
    "total_failed": 2,
    "total_skipped": 3,
    "total_blocked": 2,
    "overall_status": "FAIL"
  },
  "suites": [ ... ]
}
```

### Text Report

Human-readable report at `tests/reports/<timestamp>/test-report.txt` with environment info, summary, and per-test details.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | One or more tests blocked (no failures) |

---

## PowerShell Fallback

PowerShell (`pwsh`) is not installed on this system. Windows-specific tests use **static validation fallback**:

| PowerShell Test | Static Fallback |
|----------------|-----------------|
| Certificate store validation | YAML manifest store references |
| certutil verification | Certificate chain structure in YAML |
| Windows service check | K8s Service/Deployment manifests |
| Registry key validation | ❌ Requires Windows runner |
| DSC configuration | ❌ Requires Windows runner |

For full PowerShell test coverage, use a Windows CI/CD runner (see `tests/lib/powershell_fallback.py` for pipeline stage template).

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Run Smoke Tests
  run: python3 tests/run_tests.py --level ci --output-dir test-results

- name: Upload Results
  uses: actions/upload-artifact@v4
  with:
    name: smoke-test-results
    path: test-results/
```

### GitLab CI

```yaml
smoke-tests:
  script:
    - python3 tests/run_tests.py --level ci --output-dir test-results
  artifacts:
    reports:
      junit: test-results/test-report.json
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | QA Agent | Initial smoke test documentation |
