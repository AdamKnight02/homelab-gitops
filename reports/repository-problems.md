# Repository Problems

Aggregated from reports/repo-problems/*.json (severity-ranked).

## broken-references (0 findings)

No findings.

## disabled-manifests (2 findings)

- [INFO] apps/pki/kyverno-policies.yaml.disabled: disabled-suffix file (*.disabled)
- [INFO] apps/pki/podsecuritypolicy.yaml.disabled: disabled-suffix file (*.disabled)

## docs-manifest-drift (16 findings)

- [WARN] docs/architecture/integration-review.md -> infra/terraform/modules/alibaba/*: documented path does not exist
- [WARN] docs/architecture/integration-review.md -> scripts/validate-state-identity.sh: documented path does not exist
- [WARN] docs/architecture/integration-review.md -> gitops/external-ca-gateway/base/networkpolicy.yaml: documented path does not exist
- [WARN] docs/architecture/integration-review.md -> infra/terraform/aws/tier-config/tier-config.tf: documented path does not exist
- [WARN] docs/architecture/integration-review.md -> infra/terraform/modules/aws/*: documented path does not exist
- [WARN] docs/architecture/state-safety.md -> customers/{customer}/{environment}/{provider}/{component}/terraform.tfstate: documented path does not exist
- [WARN] docs/cloud/crash-course.md -> infra/terraform/azure/providers.tf: documented path does not exist
- [WARN] docs/monitoring/alerts.md -> gitops/monitoring/customers/<id>: documented path does not exist
- [WARN] docs/monitoring/prometheus.md -> customers/_template/customer-overlay.yaml: documented path does not exist
- [WARN] docs/operations/customer-deployment.md -> customers/definitions: documented path does not exist
- [WARN] docs/security/security-review.md -> infra/terraform/*/main.tf: documented path does not exist
- [WARN] docs/security/security-review.md -> docs/cloud/manifests/base/networkpolicy-*.yaml: documented path does not exist
- [WARN] docs/security/security-review.md -> infra/terraform/*: documented path does not exist
- [WARN] docs/security/security-review.md -> infra/terraform/modules/*/security: documented path does not exist
- [WARN] docs/testing/smoke-tests.md -> tests/reports/<timestamp>/test-report.json: documented path does not exist
- [WARN] docs/testing/smoke-tests.md -> tests/reports/<timestamp>/test-report.txt: documented path does not exist

## dup-ca-service (0 findings)

No findings.

## dup-monitoring (1 findings)

- [INFO] : monitoring stack referenced under 10 top-level trees

## dup-terraform-modules (11 findings)

- [WARN] compute: module "compute" defined in 3 files
- [WARN] database: module "database" defined in 3 files
- [WARN] identity: module "identity" defined in 3 files
- [WARN] kubernetes_bootstrap: module "kubernetes_bootstrap" defined in 3 files
- [WARN] load_balancer: module "load_balancer" defined in 3 files
- [WARN] monitoring: module "monitoring" defined in 2 files
- [WARN] network: module "network" defined in 2 files
- [WARN] secrets: module "secrets" defined in 3 files
- [WARN] security: module "security" defined in 2 files
- [WARN] storage: module "storage" defined in 3 files
- [WARN] tier_config: module "tier_config" defined in 3 files

## stray-root-artifacts (7 findings)

- [INFO] INVENTORY-REPORT.md: stray root artifact: status/report dump
- [INFO] PHASE5-6-SUMMARY.md: stray root artifact: status/report dump
- [INFO] PHASES-8-24-EXECUTION-REPORT.md: stray root artifact: status/report dump
- [INFO] SESSION-STATE.md: stray root artifact: status/report dump
- [INFO] convert_to_pdf.py: stray root artifact: one-off utility script
- [INFO] openclaw-workspace-state.json: stray root artifact: agent session/state file
- [INFO] test-flush-status.txt: stray root artifact: test/scratch file
