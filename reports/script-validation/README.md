# Script Validation Findings

This directory contains the results of script validation checks.

## Summary

- **Total Scripts**: 23
- **Failing Scripts**: 1

## Script Categories

- **Bash Scripts**: 8
- **PowerShell Scripts**: 7
- **Python Scripts**: 8

## Details

### Bash Scripts
- `homelab-gitops/scripts/migration-orchestrator.sh`
- `scripts/state-backup.sh`
- `scripts/state-guard.sh`
- `./homelab-gitops/scripts/state-migrate.sh`
- `scripts/state-validate.sh`
- `./homelab-gitops/configuration/linux/baseline/logging-baseline.sh`
- `configuration/linux/baseline/security-baseline.sh`
- `./homelab-gitops/configuration/linux/baseline/tls-baseline.sh`

### PowerShell Scripts
- `configuration/windows/acme/acme-config.ps1`
- `configuration/windows/baseline/logging-baseline.ps1`
- `configuration/windows/baseline/security-baseline.ps1`
- `configuration/windows/baseline/tls-baseline.ps1`
- `configuration/windows/gateway/gateway-config.ps1` - **Failing**
- `configuration/windows/pki/pki-vm-config.ps1`
- `configuration/windows/scep/scep-config.ps1`

### Python Scripts
- `tests/run_tests.py`
- `tests/level1-static/test_static_validation.py`
- `tests/level2-cloud/test_cloud_infrastructure.py`
- `tests/level3-kubernetes/test_kubernetes.py`
- `tests/level4-platform/test_platform.py`
- `tests/level5-pki/test_pki_protocols.py`
- `tests/level6-idempotency/test_idempotency.py`
- `tests/level7-lifecycle/test_lifecycle.py`

The failing script is `configuration/windows/gateway/gateway-config.ps1` which contains TODO stubs indicating incomplete implementation.
