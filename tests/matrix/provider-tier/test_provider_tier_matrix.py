#!/usr/bin/env python3
"""
Provider/Tier Test Matrix
Defines and evaluates the test matrix for cloud providers × tiers.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, timed_test, shutil_which
)


# Provider/Tier Test Matrix
# Classification: STATIC, PLAN, LIVE, BLOCKED
PROVIDER_TIER_MATRIX = [
    # Azure
    {
        "provider": "azure",
        "tier": "economy",
        "classification": "STATIC",
        "description": "Azure Economy tier — static validation only",
        "vm_size": "Standard_B1s",
        "estimated_cost": "~$8/month",
        "terraform_dir": "infra/terraform/azure",
        "can_plan": True,
        "can_apply": False,
        "reason": "No Azure credits — PLAN-ONLY mode",
    },
    {
        "provider": "azure",
        "tier": "standard",
        "classification": "STATIC",
        "description": "Azure Standard tier — static validation only",
        "vm_size": "Standard_B2s",
        "estimated_cost": "~$32/month",
        "terraform_dir": "infra/terraform/azure",
        "can_plan": True,
        "can_apply": False,
        "reason": "No Azure credits — PLAN-ONLY mode",
    },
    {
        "provider": "azure",
        "tier": "enterprise",
        "classification": "STATIC",
        "description": "Azure Enterprise tier — static validation only",
        "vm_size": "Standard_D2s_v5",
        "estimated_cost": "~$70/month",
        "terraform_dir": "infra/terraform/azure",
        "can_plan": True,
        "can_apply": False,
        "reason": "No Azure credits — PLAN-ONLY mode",
    },
    # AWS
    {
        "provider": "aws",
        "tier": "economy",
        "classification": "PLAN",
        "description": "AWS Economy tier — terraform plan validated",
        "instance_type": "t3.micro",
        "estimated_cost": "~$8/month (free-tier eligible)",
        "terraform_dir": "infra/terraform/aws",
        "can_plan": True,
        "can_apply": False,
        "reason": "Free-tier eligible but not yet deployed",
    },
    {
        "provider": "aws",
        "tier": "standard",
        "classification": "PLAN",
        "description": "AWS Standard tier — terraform plan validated",
        "instance_type": "t3.small",
        "estimated_cost": "~$15/month",
        "terraform_dir": "infra/terraform/aws",
        "can_plan": True,
        "can_apply": False,
        "reason": "Not yet deployed",
    },
    {
        "provider": "aws",
        "tier": "enterprise",
        "classification": "PLAN",
        "description": "AWS Enterprise tier — terraform plan validated",
        "instance_type": "t3.medium",
        "estimated_cost": "~$30/month",
        "terraform_dir": "infra/terraform/aws",
        "can_plan": True,
        "can_apply": False,
        "reason": "Not yet deployed",
    },
    # Alibaba (future)
    {
        "provider": "alibaba",
        "tier": "economy",
        "classification": "BLOCKED",
        "description": "Alibaba Economy tier — not yet implemented",
        "instance_type": "ecs.t6-c1m1.large",
        "estimated_cost": "~$10/month",
        "terraform_dir": "infra/terraform/alibaba",
        "can_plan": False,
        "can_apply": False,
        "reason": "Alibaba provider not yet implemented",
    },
    {
        "provider": "alibaba",
        "tier": "standard",
        "classification": "BLOCKED",
        "description": "Alibaba Standard tier — not yet implemented",
        "instance_type": "ecs.t6-c1m2.large",
        "estimated_cost": "~$20/month",
        "terraform_dir": "infra/terraform/alibaba",
        "can_plan": False,
        "can_apply": False,
        "reason": "Alibaba provider not yet implemented",
    },
    {
        "provider": "alibaba",
        "tier": "enterprise",
        "classification": "BLOCKED",
        "description": "Alibaba Enterprise tier — not yet implemented",
        "instance_type": "ecs.c6.large",
        "estimated_cost": "~$50/month",
        "terraform_dir": "infra/terraform/alibaba",
        "can_plan": False,
        "can_apply": False,
        "reason": "Alibaba provider not yet implemented",
    },
]


def run_all(project_root: str) -> TestSuite:
    suite = TestSuite(
        "Provider/Tier Test Matrix",
        level=2,
        description="Evaluate test coverage across providers and tiers",
    )
    suite.start()

    for entry in PROVIDER_TIER_MATRIX:
        suite.add_result(_evaluate_entry(entry, project_root))

    suite.stop()
    return suite


def _evaluate_entry(entry: dict, project_root: str) -> TestResult:
    """Evaluate a single provider/tier matrix entry."""
    provider = entry["provider"]
    tier = entry["tier"]
    classification = entry["classification"]
    tf_dir = os.path.join(project_root, entry["terraform_dir"])

    test_id = f"MATRIX-{provider.upper()}-{tier.upper()}"
    name = f"{provider.capitalize()} {tier.capitalize()}"

    if classification == "BLOCKED":
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.BLOCKED,
            message=entry["reason"],
            details={
                "provider": provider,
                "tier": tier,
                "classification": classification,
                "estimated_cost": entry.get("estimated_cost", ""),
            },
        )

    if classification == "STATIC":
        # Run static validation only
        return _run_static_validation(entry, project_root, test_id, name)

    if classification == "PLAN":
        # Run terraform plan
        return _run_plan_validation(entry, project_root, test_id, name)

    if classification == "LIVE":
        # Would run full deployment test
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.BLOCKED,
            message="LIVE testing requires deployment approval",
            details={"classification": classification},
        )

    return TestResult(
        test_id=test_id, name=name, level=2,
        status=TestStatus.SKIP,
        message=f"Unknown classification: {classification}",
    )


def _run_static_validation(entry: dict, project_root: str, test_id: str, name: str) -> TestResult:
    """Run static validation for a provider/tier."""
    tf_dir = os.path.join(project_root, entry["terraform_dir"])

    if not os.path.isdir(tf_dir):
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.FAIL,
            message=f"Terraform directory not found: {tf_dir}",
        )

    # Check terraform fmt
    rc, stdout, stderr = run_command(
        ["terraform", "fmt", "-check", "-recursive"],
        cwd=tf_dir, timeout=30,
    )
    fmt_ok = rc == 0

    # Check terraform validate
    if not os.path.isdir(os.path.join(tf_dir, ".terraform")):
        rc, stdout, stderr = run_command(
            ["terraform", "init", "-backend=false", "-no-color"],
            cwd=tf_dir, timeout=120,
        )
        if rc != 0:
            return TestResult(
                test_id=test_id, name=name, level=2,
                status=TestStatus.FAIL,
                message=f"terraform init failed: {stderr[:200]}",
            )

    rc, stdout, stderr = run_command(
        ["terraform", "validate", "-no-color"],
        cwd=tf_dir, timeout=60,
    )
    validate_ok = rc == 0

    if fmt_ok and validate_ok:
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.PASS,
            message=f"Static validation passed (fmt + validate)",
            details={
                "provider": entry["provider"],
                "tier": entry["tier"],
                "classification": entry["classification"],
                "estimated_cost": entry.get("estimated_cost", ""),
            },
        )

    issues = []
    if not fmt_ok:
        issues.append("terraform fmt check failed")
    if not validate_ok:
        issues.append(f"terraform validate failed: {stderr[:200]}")

    return TestResult(
        test_id=test_id, name=name, level=2,
        status=TestStatus.FAIL,
        message=f"Static validation issues: {'; '.join(issues)}",
    )


def _run_plan_validation(entry: dict, project_root: str, test_id: str, name: str) -> TestResult:
    """Run terraform plan for a provider/tier."""
    tf_dir = os.path.join(project_root, entry["terraform_dir"])

    if not os.path.isdir(tf_dir):
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.FAIL,
            message=f"Terraform directory not found: {tf_dir}",
        )

    # Initialize if needed
    if not os.path.isdir(os.path.join(tf_dir, ".terraform")):
        rc, stdout, stderr = run_command(
            ["terraform", "init", "-backend=false", "-no-color"],
            cwd=tf_dir, timeout=120,
        )
        if rc != 0:
            return TestResult(
                test_id=test_id, name=name, level=2,
                status=TestStatus.FAIL,
                message=f"terraform init failed: {stderr[:200]}",
            )

    # Run plan
    rc, stdout, stderr = run_command(
        ["terraform", "plan", "-no-color", "-input=false"],
        cwd=tf_dir, timeout=120,
    )

    if rc == 0 or rc == 2:  # 0=no changes, 2=changes planned
        # Count resources
        resource_count = stdout.count("will be created") + stdout.count("will be updated")
        return TestResult(
            test_id=test_id, name=name, level=2,
            status=TestStatus.PASS,
            message=f"terraform plan succeeded ({resource_count} resources planned)",
            details={
                "provider": entry["provider"],
                "tier": entry["tier"],
                "classification": entry["classification"],
                "estimated_cost": entry.get("estimated_cost", ""),
                "instance_type": entry.get("instance_type", entry.get("vm_size", "")),
            },
        )

    return TestResult(
        test_id=test_id, name=name, level=2,
        status=TestStatus.FAIL,
        message=f"terraform plan failed: {stderr[:300]}",
    )


def get_matrix() -> list:
    """Return the full provider/tier test matrix."""
    return PROVIDER_TIER_MATRIX


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), "..", ".."))
    suite = run_all(project_root)
    print(json.dumps(suite.to_dict(), indent=2))
