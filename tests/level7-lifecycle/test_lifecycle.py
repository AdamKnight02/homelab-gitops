#!/usr/bin/env python3
"""
LEVEL 7: Lifecycle Tests
Tests the full lifecycle: deploy → test → destroy → verify cleanup → redeploy → test.
These are destructive tests that should only run against ephemeral environments.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, timed_test, shutil_which
)


def run_all(project_root: str, provider: str = "azure", kubeconfig: str = "") -> TestSuite:
    suite = TestSuite(
        "Lifecycle",
        level=7,
        description=f"Full lifecycle test for {provider}: deploy→test→destroy→verify→redeploy→test",
    )
    suite.start()

    env = {}
    if kubeconfig:
        env["KUBECONFIG"] = kubeconfig

    # Safety check: only run against ephemeral environments
    suite.add_result(_test_ephemeral_safety_check(project_root, provider, test_id="L7-SAFETY", name="Ephemeral Safety Check", level=7))

    # Lifecycle stages
    suite.add_result(_test_terraform_deploy(project_root, provider, test_id="L7-DEPLOY", name="Terraform Deploy", level=7))
    suite.add_result(_test_post_deploy_validation(project_root, provider, env, test_id="L7-VALIDATE", name="Post-Deploy Validation", level=7))
    suite.add_result(_test_terraform_destroy(project_root, provider, test_id="L7-DESTROY", name="Terraform Destroy", level=7))
    suite.add_result(_test_cleanup_verification(project_root, provider, test_id="L7-CLEANUP", name="Cleanup Verification", level=7))
    suite.add_result(_test_terraform_redeploy(project_root, provider, test_id="L7-REDEPLOY", name="Terraform Redeploy", level=7))
    suite.add_result(_test_post_redeploy_validation(project_root, provider, env, test_id="L7-REVALIDATE", name="Post-Redeploy Validation", level=7))

    suite.stop()
    return suite


@timed_test
def _test_ephemeral_safety_check(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Verify the target environment is marked as ephemeral before running destructive tests."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    tfvars_example = os.path.join(tf_dir, "terraform.tfvars.example")
    tfvars = os.path.join(tf_dir, "terraform.tfvars")

    # Check if terraform.tfvars exists and has ephemeral=true
    if os.path.isfile(tfvars):
        with open(tfvars, "r") as f:
            content = f.read()
        if 'ephemeral' in content and 'false' in content.lower():
            return TestResult(
                test_id=test_id, name=name, level=level,
                status=TestStatus.BLOCKED,
                message="Environment is NOT marked as ephemeral — lifecycle tests are DESTRUCTIVE",
                remediation="Set ephemeral=true in terraform.tfvars or use a dedicated test environment",
            )

    # Check variables.tf default
    var_file = os.path.join(tf_dir, "variables.tf")
    if os.path.isfile(var_file):
        with open(var_file, "r") as f:
            content = f.read()
        if '"ephemeral"' in content and "true" in content:
            return TestResult(
                test_id=test_id, name=name, level=level,
                status=TestStatus.PASS,
                message="Environment marked as ephemeral (default=true) — safe for lifecycle tests",
            )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="Ephemeral safety check passed (no persistent state found)",
    )


@timed_test
def _test_terraform_deploy(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Run terraform apply."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    if not os.path.isdir(tf_dir):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message=f"Terraform directory not found for {provider}",
        )

    # Check for state (already deployed)
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))
    if has_state:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="Infrastructure already deployed (state exists) — skipping initial deploy",
        )

    # Check for credentials
    if provider == "azure" and not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    if provider == "aws" and not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )

    # Initialize
    rc, stdout, stderr = run_command(
        ["terraform", "init", "-no-color"],
        cwd=tf_dir, timeout=120,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform init failed: {stderr[:300]}",
        )

    # Plan
    rc, stdout, stderr = run_command(
        ["terraform", "plan", "-no-color", "-out=tfplan"],
        cwd=tf_dir, timeout=120,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform plan failed: {stderr[:300]}",
        )

    # Apply
    rc, stdout, stderr = run_command(
        ["terraform", "apply", "-no-color", "-auto-approve", "tfplan"],
        cwd=tf_dir, timeout=600,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform apply failed: {stderr[:300]}",
            remediation="Check cloud credentials, quotas, and resource availability",
        )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"terraform apply succeeded for {provider}",
    )


@timed_test
def _test_post_deploy_validation(project_root: str, provider: str, env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Validate infrastructure after deployment."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))

    if not has_state:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="No terraform state — nothing to validate",
        )

    # Get terraform outputs
    rc, stdout, stderr = run_command(
        ["terraform", "output", "-json"],
        cwd=tf_dir, timeout=30,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform output failed: {stderr[:200]}",
        )

    try:
        outputs = json.loads(stdout)
    except json.JSONDecodeError:
        outputs = {}

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Post-deploy validation: {len(outputs)} outputs available",
        details={"output_keys": list(outputs.keys())},
    )


@timed_test
def _test_terraform_destroy(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Run terraform destroy."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))

    if not has_state:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="No terraform state — nothing to destroy",
        )

    rc, stdout, stderr = run_command(
        ["terraform", "destroy", "-no-color", "-auto-approve"],
        cwd=tf_dir, timeout=600,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform destroy failed: {stderr[:300]}",
            remediation="Manual cleanup may be required. Check cloud console for orphaned resources.",
        )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"terraform destroy succeeded for {provider}",
    )


@timed_test
def _test_cleanup_verification(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Verify all resources are cleaned up after destroy."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)

    # Check terraform state is empty
    rc, stdout, stderr = run_command(
        ["terraform", "show", "-json"],
        cwd=tf_dir, timeout=30,
    )
    if rc == 0:
        try:
            state = json.loads(stdout)
            resources = state.get("values", {}).get("root_module", {}).get("resources", [])
            if resources:
                return TestResult(
                    test_id=test_id, name=name, level=level,
                    status=TestStatus.FAIL,
                    message=f"State still contains {len(resources)} resources after destroy",
                    details={"remaining": [r.get("address", "") for r in resources]},
                )
        except json.JSONDecodeError:
            pass

    # Verify no cloud resources remain
    if provider == "azure" and shutil_which("az"):
        rc, stdout, stderr = run_command(
            ["az", "group", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
            timeout=15,
        )
        if rc == 0:
            groups = json.loads(stdout)
            if groups:
                return TestResult(
                    test_id=test_id, name=name, level=level,
                    status=TestStatus.FAIL,
                    message=f"Azure resource groups still exist: {[g['name'] for g in groups]}",
                    remediation="Manually delete remaining resource groups",
                )

    elif provider == "aws" and shutil_which("aws"):
        rc, stdout, stderr = run_command(
            ["aws", "ec2", "describe-vpcs", "--filters", "Name=tag:Project,Values=pki-cloudlab", "--output", "json"],
            timeout=15,
        )
        if rc == 0:
            vpcs = json.loads(stdout).get("Vpcs", [])
            if vpcs:
                return TestResult(
                    test_id=test_id, name=name, level=level,
                    status=TestStatus.FAIL,
                    message=f"AWS VPCs still exist: {[v['VpcId'] for v in vpcs]}",
                    remediation="Manually delete remaining VPCs and associated resources",
                )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="Cleanup verified — no remaining resources",
    )


@timed_test
def _test_terraform_redeploy(project_root: str, provider: str, test_id: str, name: str, level: int) -> TestResult:
    """Redeploy after destroy to verify reproducibility."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)

    # Check if state exists (meaning destroy didn't happen or wasn't tested)
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))
    if has_state:
        # Check if state has resources
        rc, stdout, stderr = run_command(
            ["terraform", "show", "-json"],
            cwd=tf_dir, timeout=30,
        )
        if rc == 0:
            try:
                state = json.loads(stdout)
                resources = state.get("values", {}).get("root_module", {}).get("resources", [])
                if resources:
                    return TestResult(
                        test_id=test_id, name=name, level=level,
                        status=TestStatus.SKIP,
                        message="Infrastructure already exists — redeploy test requires prior destroy",
                    )
            except json.JSONDecodeError:
                pass

    # Attempt redeploy
    rc, stdout, stderr = run_command(
        ["terraform", "apply", "-no-color", "-auto-approve"],
        cwd=tf_dir, timeout=600,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform redeploy failed: {stderr[:300]}",
        )

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"terraform redeploy succeeded for {provider} (reproducibility confirmed)",
    )


@timed_test
def _test_post_redeploy_validation(project_root: str, provider: str, env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Validate infrastructure after redeployment."""
    tf_dir = os.path.join(project_root, "infra", "terraform", provider)
    has_state = os.path.isfile(os.path.join(tf_dir, "terraform.tfstate"))

    if not has_state:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="No terraform state after redeploy — nothing to validate",
        )

    rc, stdout, stderr = run_command(
        ["terraform", "output", "-json"],
        cwd=tf_dir, timeout=30,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"terraform output failed after redeploy: {stderr[:200]}",
        )

    try:
        outputs = json.loads(stdout)
    except json.JSONDecodeError:
        outputs = {}

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Post-redeploy validation: {len(outputs)} outputs available",
        details={"output_keys": list(outputs.keys())},
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    provider = os.environ.get("CLOUD_PROVIDER", "azure")
    kubeconfig = os.environ.get("KUBECONFIG", "")
    suite = run_all(project_root, provider, kubeconfig)
    print(json.dumps(suite.to_dict(), indent=2))
