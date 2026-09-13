#!/usr/bin/env python3
"""
LEVEL 2: Cloud Infrastructure Tests
Tests that validate cloud resources provisioned by Terraform.
Requires cloud credentials (Azure CLI / AWS CLI) and deployed infrastructure.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, timed_test, shutil_which
)


def run_all(project_root: str, provider: str = "all") -> TestSuite:
    suite = TestSuite(
        "Cloud Infrastructure",
        level=2,
        description=f"Validate cloud resources for provider: {provider}",
    )
    suite.start()

    if provider in ("all", "azure"):
        suite.add_result(_test_azure_cli_auth(test_id="L2-AZ-AUTH", name="Azure CLI Auth", level=2))
        suite.add_result(_test_azure_resource_group(test_id="L2-AZ-RG", name="Azure Resource Group", level=2))
        suite.add_result(_test_azure_network(test_id="L2-AZ-NET", name="Azure Network", level=2))
        suite.add_result(_test_azure_vm(test_id="L2-AZ-VM", name="Azure VM", level=2))
        suite.add_result(_test_azure_nsg_rules(test_id="L2-AZ-NSG", name="Azure NSG Rules", level=2))
        suite.add_result(_test_azure_no_unexpected_public_ips(test_id="L2-AZ-PIP", name="Azure Public IPs", level=2))

    if provider in ("all", "aws"):
        suite.add_result(_test_aws_cli_auth(test_id="L2-AWS-AUTH", name="AWS CLI Auth", level=2))
        suite.add_result(_test_aws_vpc(test_id="L2-AWS-VPC", name="AWS VPC", level=2))
        suite.add_result(_test_aws_ec2(test_id="L2-AWS-EC2", name="AWS EC2", level=2))
        suite.add_result(_test_aws_security_group(test_id="L2-AWS-SG", name="AWS Security Group", level=2))
        suite.add_result(_test_aws_no_unexpected_public_ips(test_id="L2-AWS-EIP", name="AWS Elastic IPs", level=2))
        suite.add_result(_test_aws_ebs_encryption(test_id="L2-AWS-EBS", name="AWS EBS Encryption", level=2))

    suite.stop()
    return suite


# ============================================================================
# Azure Tests
# ============================================================================

@timed_test
def _test_azure_cli_auth(test_id: str, name: str, level: int) -> TestResult:
    """Verify Azure CLI is authenticated."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message="Azure CLI (az) not installed",
        )
    rc, stdout, stderr = run_command(["az", "account", "show", "-o", "json"], timeout=15)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message="Azure CLI not authenticated",
            remediation="Run: az login",
        )
    account = json.loads(stdout)
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Authenticated as {account.get('user', {}).get('name', 'unknown')}",
        details={
            "subscription": account.get("name", ""),
            "tenant": account.get("tenantId", ""),
        },
    )


@timed_test
def _test_azure_resource_group(test_id: str, name: str, level: int) -> TestResult:
    """Check if the expected resource group exists."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["az", "group", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Failed to list resource groups: {stderr[:200]}",
        )
    groups = json.loads(stdout)
    if not groups:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP,
            message="No PKI resource groups found (PLAN-ONLY mode)",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(groups)} resource group(s)",
        details={"groups": [g["name"] for g in groups]},
    )


@timed_test
def _test_azure_network(test_id: str, name: str, level: int) -> TestResult:
    """Validate Azure network resources."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["az", "network", "vnet", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to list VNets: {stderr[:200]}",
        )
    vnets = json.loads(stdout)
    if not vnets:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No PKI VNets found (PLAN-ONLY mode)",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(vnets)} VNet(s)",
        details={"vnets": [{"name": v["name"], "cidr": v.get("addressSpace", {}).get("addressPrefixes", [])} for v in vnets]},
    )


@timed_test
def _test_azure_vm(test_id: str, name: str, level: int) -> TestResult:
    """Validate Azure VM exists and is running."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["az", "vm", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to list VMs: {stderr[:200]}",
        )
    vms = json.loads(stdout)
    if not vms:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No PKI VMs found (PLAN-ONLY mode)",
        )
    running = [v for v in vms if v.get("powerState") == "VM running"]
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS if running else TestStatus.FAIL,
        message=f"VMs: {len(vms)} total, {len(running)} running",
        details={"vms": [{"name": v["name"], "size": v.get("hardwareProfile", {}).get("vmSize", ""), "state": v.get("powerState", "")} for v in vms]},
    )


@timed_test
def _test_azure_nsg_rules(test_id: str, name: str, level: int) -> TestResult:
    """Validate NSG rules are restrictive."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["az", "network", "nsg", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to list NSGs: {stderr[:200]}",
        )
    nsgs = json.loads(stdout)
    if not nsgs:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No NSGs found (PLAN-ONLY mode)",
        )
    issues = []
    for nsg in nsgs:
        for rule in nsg.get("securityRules", []):
            if rule.get("direction") == "Inbound" and rule.get("access") == "Allow":
                if rule.get("sourceAddressPrefix") in ("*", "0.0.0.0/0", "Internet"):
                    if rule.get("destinationPortRange") not in ("22",):
                        issues.append(f"{nsg['name']}/{rule['name']}: overly permissive inbound rule")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Overly permissive NSG rules: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="NSG rules are appropriately restrictive",
    )


@timed_test
def _test_azure_no_unexpected_public_ips(test_id: str, name: str, level: int) -> TestResult:
    """Check for unexpected public IPs."""
    if not shutil_which("az"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="Azure CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["az", "network", "public-ip", "list", "--query", "[?contains(name, 'pki')]", "-o", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to list public IPs: {stderr[:200]}",
        )
    pips = json.loads(stdout)
    if not pips:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.PASS,
            message="No public IPs found (expected for secure deployment)",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(pips)} public IP(s) — review if expected",
        details={"public_ips": [{"name": p["name"], "ip": p.get("ipAddress", "unassigned")} for p in pips]},
    )


# ============================================================================
# AWS Tests
# ============================================================================

@timed_test
def _test_aws_cli_auth(test_id: str, name: str, level: int) -> TestResult:
    """Verify AWS CLI is authenticated."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not installed",
        )
    rc, stdout, stderr = run_command(["aws", "sts", "get-caller-identity", "--output", "json"], timeout=15)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message="AWS CLI not authenticated",
            remediation="Run: aws configure or set AWS_PROFILE",
        )
    identity = json.loads(stdout)
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Authenticated as {identity.get('Arn', 'unknown')}",
        details={"account": identity.get("Account", "")},
    )


@timed_test
def _test_aws_vpc(test_id: str, name: str, level: int) -> TestResult:
    """Validate AWS VPC resources."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["aws", "ec2", "describe-vpcs", "--filters", "Name=tag:Project,Values=pki-cloudlab", "--output", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to describe VPCs: {stderr[:200]}",
        )
    vpcs = json.loads(stdout).get("Vpcs", [])
    if not vpcs:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No PKI VPCs found (PLAN-ONLY mode)",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(vpcs)} VPC(s)",
        details={"vpcs": [{"id": v["VpcId"], "cidr": v.get("CidrBlock", "")} for v in vpcs]},
    )


@timed_test
def _test_aws_ec2(test_id: str, name: str, level: int) -> TestResult:
    """Validate EC2 instances."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["aws", "ec2", "describe-instances",
         "--filters", "Name=tag:Project,Values=pki-cloudlab", "Name=instance-state-name,Values=running,pending",
         "--output", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to describe instances: {stderr[:200]}",
        )
    reservations = json.loads(stdout).get("Reservations", [])
    instances = [i for r in reservations for i in r.get("Instances", [])]
    if not instances:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No PKI EC2 instances found (PLAN-ONLY mode)",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(instances)} EC2 instance(s)",
        details={"instances": [{"id": i["InstanceId"], "type": i.get("InstanceType", ""), "state": i.get("State", {}).get("Name", "")} for i in instances]},
    )


@timed_test
def _test_aws_security_group(test_id: str, name: str, level: int) -> TestResult:
    """Validate security group rules are restrictive."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["aws", "ec2", "describe-security-groups",
         "--filters", "Name=tag:Project,Values=pki-cloudlab",
         "--output", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to describe SGs: {stderr[:200]}",
        )
    sgs = json.loads(stdout).get("SecurityGroups", [])
    if not sgs:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No security groups found (PLAN-ONLY mode)",
        )
    issues = []
    for sg in sgs:
        for rule in sg.get("IpPermissions", []):
            for ip_range in rule.get("IpRanges", []):
                if ip_range.get("CidrIp") == "0.0.0.0/0":
                    port = rule.get("FromPort", "all")
                    if port != 22:
                        issues.append(f"{sg['GroupId']}: 0.0.0.0/0 allowed on port {port}")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Overly permissive SG rules: {len(issues)}",
            details={"issues": issues},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="Security group rules are appropriately restrictive",
    )


@timed_test
def _test_aws_no_unexpected_public_ips(test_id: str, name: str, level: int) -> TestResult:
    """Check for unexpected Elastic IPs."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["aws", "ec2", "describe-addresses", "--output", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to describe EIPs: {stderr[:200]}",
        )
    eips = json.loads(stdout).get("Addresses", [])
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Found {len(eips)} Elastic IP(s) — review if expected",
        details={"eips": [{"ip": e.get("PublicIp", ""), "instance": e.get("InstanceId", "unattached")} for e in eips]},
    )


@timed_test
def _test_aws_ebs_encryption(test_id: str, name: str, level: int) -> TestResult:
    """Verify EBS volumes are encrypted."""
    if not shutil_which("aws"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="AWS CLI not available",
        )
    rc, stdout, stderr = run_command(
        ["aws", "ec2", "describe-volumes",
         "--filters", "Name=tag:Project,Values=pki-cloudlab",
         "--output", "json"],
        timeout=15,
    )
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to describe volumes: {stderr[:200]}",
        )
    volumes = json.loads(stdout).get("Volumes", [])
    if not volumes:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.SKIP, message="No EBS volumes found (PLAN-ONLY mode)",
        )
    unencrypted = [v for v in volumes if not v.get("Encrypted", False)]
    if unencrypted:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"{len(unencrypted)} unencrypted EBS volume(s) found",
            details={"unencrypted": [v["VolumeId"] for v in unencrypted]},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(volumes)} EBS volume(s) encrypted",
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    provider = os.environ.get("CLOUD_PROVIDER", "all")
    suite = run_all(project_root, provider)
    print(json.dumps(suite.to_dict(), indent=2))
