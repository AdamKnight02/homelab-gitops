#!/usr/bin/env python3
"""
LEVEL 1: Static Validation Tests
Tests that validate code, configuration, and structure without deploying anything.
Can run entirely offline / in CI.
"""

import json
import os
import re
import sys
import yaml
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, find_files, timed_test
)


def run_all(project_root: str) -> TestSuite:
    suite = TestSuite("Static Validation", level=1, description="Schema, format, and structural validation")
    suite.start()

    # --- Terraform Format Check ---
    suite.add_result(_test_terraform_fmt(project_root, test_id="L1-TF-FMT", name="Terraform Format", level=1))
    # --- Terraform Validate ---
    suite.add_result(_test_terraform_validate(project_root, "azure", test_id="L1-TF-VALIDATE-AZURE", name="Terraform Validate (Azure)", level=1))
    suite.add_result(_test_terraform_validate(project_root, "aws", test_id="L1-TF-VALIDATE-AWS", name="Terraform Validate (AWS)", level=1))
    # --- YAML Syntax ---
    suite.add_result(_test_yaml_syntax(project_root, test_id="L1-YAML-SYNTAX", name="YAML Syntax", level=1))
    # --- K8s Manifest Structure ---
    suite.add_result(_test_k8s_manifest_structure(project_root, test_id="L1-K8S-MANIFEST", name="K8s Manifest Structure", level=1))
    # --- ArgoCD Application Structure ---
    suite.add_result(_test_argocd_app_structure(project_root, test_id="L1-ARGOCD-APP", name="ArgoCD Application Structure", level=1))
    # --- Kustomization Structure ---
    suite.add_result(_test_kustomization_structure(project_root, test_id="L1-KUSTOMIZE", name="Kustomization Structure", level=1))
    # --- GitOps Directory Structure ---
    suite.add_result(_test_gitops_structure(project_root, test_id="L1-GITOPS", name="GitOps Directory Structure", level=1))
    # --- Terraform Variable Validation ---
    suite.add_result(_test_terraform_variable_defaults(project_root, test_id="L1-TF-VARS", name="Terraform Variable Defaults", level=1))
    # --- No Secrets in Code ---
    suite.add_result(_test_no_secrets_in_code(project_root, test_id="L1-NO-SECRETS", name="No Secrets in Code", level=1))
    # --- Tagging Standards ---
    suite.add_result(_test_tagging_standards(project_root, test_id="L1-TAGGING", name="Tagging Standards", level=1))
    # --- Network Policy Presence ---
    suite.add_result(_test_network_policy_presence(project_root, test_id="L1-NETPOL", name="Network Policy Presence", level=1))
    # --- PowerShell Availability ---
    suite.add_result(_test_pwsh_availability(test_id="L1-PWSH", name="PowerShell Availability", level=1))

    suite.stop()
    return suite


@timed_test
def _test_terraform_fmt(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Check that all Terraform files are properly formatted."""
    tf_dirs = [
        os.path.join(project_root, "infra", "terraform", "azure"),
        os.path.join(project_root, "infra", "terraform", "aws"),
        os.path.join(project_root, "infra", "terraform", "modules"),
    ]
    issues = []
    for tf_dir in tf_dirs:
        if not os.path.isdir(tf_dir):
            continue
        rc, stdout, stderr = run_command(
            ["terraform", "fmt", "-check", "-recursive", "-diff"],
            cwd=tf_dir, timeout=30
        )
        if rc != 0:
            issues.append(f"{tf_dir}: {stdout.strip()}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Terraform formatting issues found in {len(issues)} directories",
            details={"issues": issues},
            remediation="Run: terraform fmt -recursive",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="All Terraform files properly formatted",
    )


@timed_test
def _test_terraform_validate(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Run terraform validate for a provider directory."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    if not os.path.isdir(tf_dir):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message=f"Terraform directory not found: {tf_dir}",
        )

    # Check if .terraform exists (init has been run)
    if not os.path.isdir(os.path.join(tf_dir, ".terraform")):
        rc, stdout, stderr = run_command(
            ["terraform", "init", "-backend=false", "-no-color"],
            cwd=tf_dir, timeout=120
        )
        if rc != 0:
            return TestResult(
                test_id=test_id, name=name, level=level,
                status=TestStatus.FAIL,
                message=f"terraform init failed: {stderr[:500]}",
                remediation="Check provider configuration and network access",
            )

    rc, stdout, stderr = run_command(
        ["terraform", "validate", "-no-color"],
        cwd=tf_dir, timeout=60
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform validate failed: {stderr[:500]}",
            details={"stderr": stderr[:1000]},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"terraform validate passed for {provider}",
    )


@timed_test
def _test_yaml_syntax(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate YAML syntax for all YAML files."""
    yaml_files = find_files(project_root, "*.yaml") + find_files(project_root, "*.yml")
    # Exclude .terraform and .git
    yaml_files = [f for f in yaml_files if ".terraform" not in f and ".git" not in f]

    errors = []
    for yf in yaml_files:
        try:
            with open(yf, "r") as f:
                # Handle multi-document YAML
                list(yaml.safe_load_all(f))
        except yaml.YAMLError as e:
            errors.append(f"{yf}: {str(e)[:200]}")
        except Exception as e:
            errors.append(f"{yf}: {str(e)[:200]}")

    if errors:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"YAML syntax errors in {len(errors)} files",
            details={"errors": errors[:20]},  # Limit detail output
            remediation="Fix YAML syntax errors listed in details",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(yaml_files)} YAML files have valid syntax",
    )


@timed_test
def _test_k8s_manifest_structure(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate K8s manifests have required fields."""
    manifest_dirs = [
        os.path.join(project_root, "machine-identity-platform", "apps"),
        os.path.join(project_root, "docs", "cloud", "manifests"),
    ]
    required_fields = ["apiVersion", "kind", "metadata"]
    issues = []
    checked = 0

    for mdir in manifest_dirs:
        if not os.path.isdir(mdir):
            continue
        for yf in find_files(mdir, "*.yaml"):
            try:
                with open(yf, "r") as f:
                    docs = list(yaml.safe_load_all(f))
                for doc in docs:
                    if doc is None:
                        continue
                    checked += 1
                    for field in required_fields:
                        if field not in doc:
                            issues.append(f"{yf}: missing '{field}'")
                    if "metadata" in doc and isinstance(doc["metadata"], dict):
                        if "name" not in doc["metadata"]:
                            issues.append(f"{yf}: missing 'metadata.name'")
            except Exception as e:
                issues.append(f"{yf}: parse error: {str(e)[:100]}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"K8s manifest structural issues in {len(issues)} documents",
            details={"issues": issues[:20]},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {checked} K8s manifest documents have required fields",
    )


@timed_test
def _test_argocd_app_structure(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate ArgoCD Application manifests."""
    app_files = find_files(
        os.path.join(project_root, "machine-identity-platform"), "application.yaml"
    )
    app_files += find_files(
        os.path.join(project_root, "machine-identity-platform", "bootstrap"), "*.yaml"
    )
    issues = []
    checked = 0

    for af in app_files:
        try:
            with open(af, "r") as f:
                docs = list(yaml.safe_load_all(f))
            for doc in docs:
                if doc is None:
                    continue
                if doc.get("kind") != "Application":
                    continue
                checked += 1
                spec = doc.get("spec", {})
                if "destination" not in spec:
                    issues.append(f"{af}: missing spec.destination")
                if "source" not in spec and "sources" not in spec:
                    issues.append(f"{af}: missing spec.source or spec.sources")
                dest = spec.get("destination", {})
                if "server" not in dest:
                    issues.append(f"{af}: missing spec.destination.server")
        except Exception as e:
            issues.append(f"{af}: {str(e)[:100]}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"ArgoCD Application issues: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {checked} ArgoCD Applications properly structured",
    )


@timed_test
def _test_kustomization_structure(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate kustomization.yaml files reference existing resources."""
    kustom_files = find_files(project_root, "kustomization.yaml")
    kustom_files = [f for f in kustom_files if ".git" not in f]
    issues = []
    checked = 0

    for kf in kustom_files:
        try:
            with open(kf, "r") as f:
                doc = yaml.safe_load(f)
            if doc is None or doc.get("kind") != "Kustomization":
                continue
            checked += 1
            kdir = os.path.dirname(kf)
            for resource in doc.get("resources", []):
                resource_path = os.path.join(kdir, resource)
                if not os.path.exists(resource_path):
                    issues.append(f"{kf}: resource not found: {resource}")
        except Exception as e:
            issues.append(f"{kf}: {str(e)[:100]}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Kustomization issues: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {checked} kustomization files reference valid resources",
    )


@timed_test
def _test_gitops_structure(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate GitOps directory structure follows conventions."""
    mip_root = os.path.join(project_root, "machine-identity-platform")
    issues = []

    # Check bootstrap exists
    bootstrap = os.path.join(mip_root, "bootstrap", "root-app.yaml")
    if not os.path.isfile(bootstrap):
        issues.append("Missing bootstrap/root-app.yaml")

    # Check apps directory
    apps_dir = os.path.join(mip_root, "apps")
    if not os.path.isdir(apps_dir):
        issues.append("Missing apps/ directory")
    else:
        expected_apps = ["ejbca", "postgres", "openbao", "spire", "pki", "cert-manager"]
        for app in expected_apps:
            app_dir = os.path.join(apps_dir, app)
            if not os.path.isdir(app_dir):
                issues.append(f"Missing app directory: apps/{app}")
            elif not os.path.isfile(os.path.join(app_dir, "application.yaml")):
                issues.append(f"Missing application.yaml in apps/{app}")

    # Check overlays in docs/cloud/manifests
    overlays_dir = os.path.join(project_root, "docs", "cloud", "manifests", "overlays")
    if os.path.isdir(overlays_dir):
        expected_overlays = ["homelab", "azure", "aws"]
        for overlay in expected_overlays:
            overlay_dir = os.path.join(overlays_dir, overlay)
            if not os.path.isdir(overlay_dir):
                issues.append(f"Missing overlay: {overlay}")
            elif not os.path.isfile(os.path.join(overlay_dir, "kustomization.yaml")):
                issues.append(f"Missing kustomization.yaml in overlay: {overlay}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"GitOps structure issues: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="GitOps directory structure is valid",
    )


@timed_test
def _test_terraform_variable_defaults(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate Terraform variables have sensible defaults and validation blocks."""
    issues = []

    for provider in ["azure", "aws"]:
        var_file = os.path.join(project_root, "infra", "terraform", provider, "variables.tf")
        if not os.path.isfile(var_file):
            issues.append(f"Missing variables.tf for {provider}")
            continue
        with open(var_file, "r") as f:
            content = f.read()

        # Check that sensitive variables have defaults (not requiring manual input)
        if 'variable "project_name"' in content and 'default' not in content.split('variable "project_name"')[1].split('}')[0]:
            issues.append(f"{provider}: project_name has no default")

        # Check validation blocks exist for critical variables
        if provider == "azure":
            if 'variable "azure_vm_size"' in content and "validation" not in content.split('variable "azure_vm_size"')[1].split('variable')[0]:
                issues.append(f"{provider}: azure_vm_size missing validation block")
        elif provider == "aws":
            if 'variable "aws_instance_type"' in content and "validation" not in content.split('variable "aws_instance_type"')[1].split('variable')[0]:
                issues.append(f"{provider}: aws_instance_type missing validation block")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Variable validation issues: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="Terraform variables have proper defaults and validation",
    )


@timed_test
def _test_no_secrets_in_code(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Scan for potential secrets in code files."""
    secret_patterns = [
        (r'password\s*=\s*"[^"]{8,}"', "hardcoded password"),
        (r'secret_key\s*=\s*"[^"]{8,}"', "hardcoded secret key"),
        (r'api_key\s*=\s*"[^"]{8,}"', "hardcoded API key"),
        (r'private_key\s*=\s*"-----BEGIN', "embedded private key"),
        (r'-----BEGIN (RSA |EC )?PRIVATE KEY-----', "embedded private key"),
        (r'client_secret\s*=\s*"[^"]{8,}"', "hardcoded client secret"),
    ]
    scan_dirs = [
        os.path.join(project_root, "infra", "terraform"),
        os.path.join(project_root, "machine-identity-platform"),
        os.path.join(project_root, "docs", "cloud", "manifests"),
    ]
    findings = []

    for sdir in scan_dirs:
        if not os.path.isdir(sdir):
            continue
        for root, dirs, files in os.walk(sdir):
            dirs[:] = [d for d in dirs if d not in (".git", ".terraform")]
            for fname in files:
                if fname.endswith((".tf", ".yaml", ".yml", ".json", ".tpl", ".py", ".sh")):
                    fpath = os.path.join(root, fname)
                    try:
                        with open(fpath, "r") as f:
                            content = f.read()
                        for pattern, desc in secret_patterns:
                            matches = re.findall(pattern, content, re.IGNORECASE)
                            if matches:
                                # Exclude known safe patterns
                                if "valueFrom" in content and "secretKeyRef" in content:
                                    continue  # K8s secret reference, not hardcoded
                                if "tls_private_key" in fname or "tls_private_key" in content:
                                    continue  # Terraform TLS provider
                                findings.append(f"{fpath}: potential {desc}")
                    except Exception:
                        pass

    if findings:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Potential secrets found in {len(findings)} locations",
            details={"findings": findings[:10]},
            remediation="Move secrets to environment variables, K8s Secrets, or OpenBao",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="No hardcoded secrets detected",
    )


@timed_test
def _test_tagging_standards(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Validate tagging standards are applied in Terraform."""
    tags_file = os.path.join(project_root, "infra", "terraform", "modules", "shared", "tags.tf")
    if not os.path.isfile(tags_file):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message="Shared tags module not found",
        )

    with open(tags_file, "r") as f:
        content = f.read()

    required_tags = ["Project", "Environment", "ManagedBy", "Owner", "Ephemeral", "CostCenter"]
    missing = [t for t in required_tags if t not in content]

    if missing:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Missing required tags: {', '.join(missing)}",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(required_tags)} required tags defined",
    )


@timed_test
def _test_network_policy_presence(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Check that NetworkPolicies exist for all application namespaces."""
    pki_dir = os.path.join(project_root, "machine-identity-platform", "apps", "pki")
    np_files = [f for f in os.listdir(pki_dir) if f.startswith("networkpolicy")] if os.path.isdir(pki_dir) else []

    has_default_deny = any("default-deny" in f for f in np_files)
    has_cert_api = any("cert-api" in f for f in np_files)
    has_cert_worker = any("cert-worker" in f for f in np_files)

    issues = []
    if not has_default_deny:
        issues.append("Missing default-deny NetworkPolicy in pki namespace")
    if not has_cert_api:
        issues.append("Missing cert-api NetworkPolicy")
    if not has_cert_worker:
        issues.append("Missing cert-worker NetworkPolicy")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"NetworkPolicy gaps: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="NetworkPolicies present for all PKI components",
    )


@timed_test
def _test_pwsh_availability(test_id: str, name: str, level: int) -> TestResult:
    """Check if PowerShell is available for Windows-specific tests."""
    rc, stdout, stderr = run_command(["which", "pwsh"], timeout=5)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="PowerShell (pwsh) not available — Windows-specific tests will use static validation fallback",
            details={"fallback": "Static YAML/schema validation will be used instead of PowerShell scripts"},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"PowerShell available: {stdout.strip()}",
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    suite = run_all(project_root)
    print(json.dumps(suite.to_dict(), indent=2))
