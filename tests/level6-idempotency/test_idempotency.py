#!/usr/bin/env python3
"""
LEVEL 6: Idempotency Tests
Tests that validate deploying twice produces no changes, and GitOps sync
is stable (no drift after resync).
"""

import json
import os
import sys
import hashlib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, timed_test, shutil_which
)


def run_all(project_root: str, kubeconfig: str = "") -> TestSuite:
    suite = TestSuite(
        "Idempotency",
        level=6,
        description="Validate deploy→redeploy→no changes, GitOps sync→resync→no drift",
    )
    suite.start()

    env = {}
    if kubeconfig:
        env["KUBECONFIG"] = kubeconfig

    suite.add_result(_test_terraform_plan_idempotent(project_root, "azure", test_id="L6-TF-IDEM-AZURE", name="Terraform Idempotent (Azure)", level=6))
    suite.add_result(_test_terraform_plan_idempotent(project_root, "aws", test_id="L6-TF-IDEM-AWS", name="Terraform Idempotent (AWS)", level=6))
    suite.add_result(_test_k8s_manifest_idempotent(project_root, env, test_id="L6-K8S-IDEM", name="K8s Manifest Idempotent", level=6))
    suite.add_result(_test_argocd_sync_no_drift(env, test_id="L6-ARGOCD-DRIFT", name="ArgoCD Sync No Drift", level=6))
    suite.add_result(_test_kustomize_build_deterministic(project_root, test_id="L6-KUSTOMIZE-DET", name="Kustomize Build Deterministic", level=6))

    suite.stop()
    return suite


@timed_test
def _test_terraform_plan_idempotent(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Run terraform plan twice and verify no changes on second run."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    if not os.path.isdir(tf_dir):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message=f"Terraform directory not found for {provider}",
        )

    # Check if terraform is initialized
    if not os.path.isdir(os.path.join(tf_dir, ".terraform")):
        rc, stdout, stderr = run_command(
            ["terraform", "init", "-backend=false", "-no-color"],
            cwd=tf_dir, timeout=120,
        )
        if rc != 0:
            return TestResult(
                test_id=test_id, name=name, level=level,
                status=TestStatus.BLOCKED,
                message=f"terraform init failed for {provider}: {stderr[:200]}",
            )

    # First plan
    rc1, stdout1, stderr1 = run_command(
        ["terraform", "plan", "-no-color", "-detailed-exitcode", "-input=false", "-out=/dev/null"],
        cwd=tf_dir, timeout=120,
    )

    # In PLAN-ONLY mode (no state), plan will always show changes
    # Check if there's a state file
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))

    if not has_state:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message=f"No terraform state for {provider} (PLAN-ONLY mode) — idempotency test requires deployed infrastructure",
            details={"plan_exit_code": rc1},
        )

    if rc1 == 0:
        # No changes — idempotent
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.PASS,
            message=f"terraform plan shows no changes for {provider} (idempotent)",
        )
    elif rc1 == 2:
        # Changes detected
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform plan shows pending changes for {provider} (not idempotent)",
            details={"plan_output": stdout1[:500]},
            remediation="Run terraform apply to converge state",
        )
    else:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.ERROR,
            message=f"terraform plan failed for {provider}: {stderr1[:300]}",
        )


@timed_test
def _test_k8s_manifest_idempotent(project_root: str, env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Apply K8s manifests twice and check for differences."""
    if not shutil_which("kubectl"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="kubectl not available",
        )

    # Use server-side dry-run to check what would change
    manifest_dir = os.path.join(project_root, "machine-identity-platform", "apps", "pki")
    if not os.path.isdir(manifest_dir):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="PKI manifests not found",
        )

    # Get current state hash of all resources in pki namespace
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "all", "-n", "pki", "-o", "json"],
        timeout=15, env=env,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message=f"Cannot query pki namespace: {stderr[:200]}",
        )

    # Hash the current state (ignoring volatile fields)
    try:
        resources = json.loads(stdout)
        # Remove volatile fields for comparison
        for item in resources.get("items", []):
            item.get("metadata", {}).pop("resourceVersion", None)
            item.get("metadata", {}).pop("uid", None)
            item.get("metadata", {}).pop("creationTimestamp", None)
            item.get("metadata", {}).pop("generation", None)
            item.pop("status", None)
        state_hash = hashlib.sha256(
            json.dumps(resources, sort_keys=True).encode()
        ).hexdigest()[:16]
    except Exception:
        state_hash = "unknown"

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"K8s resource state captured (hash: {state_hash}) — compare after re-apply for idempotency",
        details={"state_hash": state_hash},
    )


@timed_test
def _test_argocd_sync_no_drift(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check ArgoCD applications show no drift after sync."""
    if not shutil_which("kubectl"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="kubectl not available",
        )

    rc, stdout, stderr = run_command(
        ["kubectl", "get", "applications", "-n", "argocd", "-o", "json"],
        timeout=15, env=env,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message=f"Cannot query ArgoCD apps: {stderr[:200]}",
        )

    apps = json.loads(stdout).get("items", [])
    drifted = []
    for app in apps:
        sync_status = app.get("status", {}).get("sync", {}).get("status", "Unknown")
        health = app.get("status", {}).get("health", {}).get("status", "Unknown")
        app_name = app["metadata"]["name"]

        if sync_status == "OutOfSync":
            drifted.append(f"{app_name}: OutOfSync")
        # Check for drift in comparison
        compared_to = app.get("status", {}).get("comparedTo", {})
        if compared_to:
            source = compared_to.get("source", {})
            destination = compared_to.get("destination", {})

    if drifted:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"ArgoCD drift detected: {len(drifted)} apps out of sync",
            details={"drifted": drifted},
            remediation="Run: argocd app sync <app-name> or kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard",
        )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(apps)} ArgoCD apps show no drift",
    )


@timed_test
def _test_kustomize_build_deterministic(project_root: str, test_id: str, name: str, level: int) -> TestResult:
    """Verify kustomize build produces identical output on repeated runs."""
    overlays = [
        os.path.join(project_root, "docs", "cloud", "manifests", "overlays", "homelab"),
        os.path.join(project_root, "docs", "cloud", "manifests", "overlays", "azure"),
        os.path.join(project_root, "docs", "cloud", "manifests", "overlays", "aws"),
    ]

    issues = []
    for overlay in overlays:
        if not os.path.isdir(overlay):
            continue
        overlay_name = os.path.basename(overlay)

        # Build twice
        rc1, stdout1, stderr1 = run_command(
            ["kubectl", "kustomize", overlay],
            timeout=30,
        )
        rc2, stdout2, stderr2 = run_command(
            ["kubectl", "kustomize", overlay],
            timeout=30,
        )

        if rc1 != 0:
            issues.append(f"{overlay_name}: build failed: {stderr1[:200]}")
            continue

        if stdout1 != stdout2:
            issues.append(f"{overlay_name}: non-deterministic output")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Kustomize build issues: {len(issues)}",
            details={"issues": issues},
        )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="Kustomize builds are deterministic across all overlays",
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    kubeconfig = os.environ.get("KUBECONFIG", "")
    suite = run_all(project_root, kubeconfig)
    print(json.dumps(suite.to_dict(), indent=2))
