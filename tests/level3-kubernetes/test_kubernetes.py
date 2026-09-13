#!/usr/bin/env python3
"""
LEVEL 3: Kubernetes Tests
Tests that validate Kubernetes cluster state and workload health.
Requires kubectl access to a running cluster.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.test_framework import (
    TestResult, TestStatus, TestSuite, run_command, timed_test, shutil_which
)


def run_all(project_root: str, kubeconfig: str = "") -> TestSuite:
    suite = TestSuite(
        "Kubernetes",
        level=3,
        description="Validate K8s cluster state, workloads, and GitOps sync",
    )
    suite.start()

    env = {}
    if kubeconfig:
        env["KUBECONFIG"] = kubeconfig

    # Pre-check: kubectl available
    kubectl_check = _check_kubectl()
    suite.add_result(kubectl_check)
    if kubectl_check.status in (TestStatus.BLOCKED, TestStatus.FAIL):
        # Add skip results for all remaining tests
        for name in [
            "Nodes Ready", "Namespaces Exist", "Deployments Available",
            "StatefulSets Ready", "Pods Running", "Services Endpoints",
            "PVCs Bound", "ArgoCD Apps Synced", "ArgoCD Apps Healthy",
            "NetworkPolicies Applied", "SPIRE Agent Running",
        ]:
            suite.add_result(TestResult(
                test_id=f"L3-{name.replace(' ', '_').upper()}",
                name=name, level=3,
                status=TestStatus.BLOCKED,
                message="kubectl not available or cluster unreachable",
            ))
        suite.stop()
        return suite

    suite.add_result(_test_nodes_ready(env, test_id="L3-NODES", name="Nodes Ready", level=3))
    suite.add_result(_test_namespaces_exist(env, test_id="L3-NAMESPACES", name="Namespaces Exist", level=3))
    suite.add_result(_test_deployments_available(env, test_id="L3-DEPLOYMENTS", name="Deployments Available", level=3))
    suite.add_result(_test_statefulsets_ready(env, test_id="L3-STATEFULSETS", name="StatefulSets Ready", level=3))
    suite.add_result(_test_pods_running(env, test_id="L3-PODS", name="Pods Running", level=3))
    suite.add_result(_test_services_endpoints(env, test_id="L3-SERVICES", name="Services Endpoints", level=3))
    suite.add_result(_test_pvcs_bound(env, test_id="L3-PVCS", name="PVCs Bound", level=3))
    suite.add_result(_test_argocd_apps_synced(env, test_id="L3-ARGOCD-SYNC", name="ArgoCD Apps Synced", level=3))
    suite.add_result(_test_argocd_apps_healthy(env, test_id="L3-ARGOCD-HEALTH", name="ArgoCD Apps Healthy", level=3))
    suite.add_result(_test_network_policies_applied(env, test_id="L3-NETPOL", name="NetworkPolicies Applied", level=3))
    suite.add_result(_test_spire_agent_running(env, test_id="L3-SPIRE-AGENT", name="SPIRE Agent Running", level=3))

    suite.stop()
    return suite


@timed_test
def _check_kubectl(test_id: str = "L3-KUBECTL", name: str = "kubectl Available", level: int = 3) -> TestResult:
    """Check kubectl is installed and cluster is reachable."""
    if not shutil_which("kubectl"):
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED, message="kubectl not installed",
        )
    rc, stdout, stderr = run_command(["kubectl", "cluster-info"], timeout=10)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.BLOCKED,
            message=f"Cluster unreachable: {stderr[:200]}",
            remediation="Check KUBECONFIG or VPN/network connectivity",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="kubectl available and cluster reachable",
    )


def _kubectl(args: list, env: dict = None, timeout: int = 15) -> tuple:
    """Run kubectl command."""
    cmd = ["kubectl"] + args + ["-o", "json"]
    return run_command(cmd, timeout=timeout, env=env)


@timed_test
def _test_nodes_ready(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check all nodes are Ready."""
    rc, stdout, stderr = _kubectl(["get", "nodes"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get nodes: {stderr[:200]}",
        )
    nodes = json.loads(stdout).get("items", [])
    not_ready = []
    for node in nodes:
        conditions = node.get("status", {}).get("conditions", [])
        ready = next((c for c in conditions if c["type"] == "Ready"), None)
        if not ready or ready["status"] != "True":
            not_ready.append(node["metadata"]["name"])

    if not_ready:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Nodes not Ready: {', '.join(not_ready)}",
            details={"total_nodes": len(nodes), "not_ready": not_ready},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(nodes)} node(s) Ready",
    )


@timed_test
def _test_namespaces_exist(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check expected namespaces exist."""
    expected = ["argocd", "cert-manager", "ejbca", "monitoring", "openbao", "pki", "rabbitmq", "registry", "spire"]
    rc, stdout, stderr = _kubectl(["get", "namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get namespaces: {stderr[:200]}",
        )
    existing = {ns["metadata"]["name"] for ns in json.loads(stdout).get("items", [])}
    missing = [ns for ns in expected if ns not in existing]

    if missing:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Missing namespaces: {', '.join(missing)}",
            details={"expected": expected, "existing": sorted(existing)},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(expected)} expected namespaces exist",
    )


@timed_test
def _test_deployments_available(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check all Deployments are Available."""
    rc, stdout, stderr = _kubectl(["get", "deployments", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get deployments: {stderr[:200]}",
        )
    deployments = json.loads(stdout).get("items", [])
    unavailable = []
    for d in deployments:
        desired = d.get("spec", {}).get("replicas", 1)
        available = d.get("status", {}).get("availableReplicas", 0)
        if available < desired:
            unavailable.append(f"{d['metadata']['namespace']}/{d['metadata']['name']} ({available}/{desired})")

    if unavailable:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Unavailable deployments: {len(unavailable)}",
            details={"unavailable": unavailable},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(deployments)} deployment(s) available",
    )


@timed_test
def _test_statefulsets_ready(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check all StatefulSets are Ready."""
    rc, stdout, stderr = _kubectl(["get", "statefulsets", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get statefulsets: {stderr[:200]}",
        )
    sts_list = json.loads(stdout).get("items", [])
    not_ready = []
    for s in sts_list:
        desired = s.get("spec", {}).get("replicas", 1)
        ready = s.get("status", {}).get("readyReplicas", 0)
        if ready < desired:
            not_ready.append(f"{s['metadata']['namespace']}/{s['metadata']['name']} ({ready}/{desired})")

    if not_ready:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"StatefulSets not ready: {len(not_ready)}",
            details={"not_ready": not_ready},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(sts_list)} StatefulSet(s) ready",
    )


@timed_test
def _test_pods_running(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check for pods not in Running/Succeeded state."""
    rc, stdout, stderr = _kubectl(["get", "pods", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get pods: {stderr[:200]}",
        )
    pods = json.loads(stdout).get("items", [])
    not_running = []
    for p in pods:
        phase = p.get("status", {}).get("phase", "Unknown")
        if phase not in ("Running", "Succeeded"):
            ns = p["metadata"]["namespace"]
            name_p = p["metadata"]["name"]
            reason = ""
            container_statuses = p.get("status", {}).get("containerStatuses", [])
            if container_statuses:
                waiting = container_statuses[0].get("state", {}).get("waiting", {})
                reason = waiting.get("reason", "")
            not_running.append(f"{ns}/{name_p} ({phase}: {reason})")

    if not_running:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Pods not running: {len(not_running)}",
            details={"not_running": not_running[:20]},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(pods)} pod(s) Running or Succeeded",
    )


@timed_test
def _test_services_endpoints(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check that services have endpoints."""
    rc, stdout, stderr = _kubectl(["get", "endpoints", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get endpoints: {stderr[:200]}",
        )
    endpoints = json.loads(stdout).get("items", [])
    no_endpoints = []
    for ep in endpoints:
        subsets = ep.get("subsets", [])
        if not subsets:
            ns = ep["metadata"]["namespace"]
            name_e = ep["metadata"]["name"]
            # Skip kubernetes default service
            if name_e == "kubernetes":
                continue
            no_endpoints.append(f"{ns}/{name_e}")

    if no_endpoints:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Services without endpoints: {len(no_endpoints)}",
            details={"no_endpoints": no_endpoints},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(endpoints)} service(s) have endpoints",
    )


@timed_test
def _test_pvcs_bound(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check all PVCs are Bound."""
    rc, stdout, stderr = _kubectl(["get", "pvc", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get PVCs: {stderr[:200]}",
        )
    pvcs = json.loads(stdout).get("items", [])
    unbound = []
    for pvc in pvcs:
        phase = pvc.get("status", {}).get("phase", "Unknown")
        if phase != "Bound":
            unbound.append(f"{pvc['metadata']['namespace']}/{pvc['metadata']['name']} ({phase})")

    if unbound:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Unbound PVCs: {len(unbound)}",
            details={"unbound": unbound},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(pvcs)} PVC(s) Bound",
    )


@timed_test
def _test_argocd_apps_synced(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check ArgoCD applications are Synced."""
    rc, stdout, stderr = _kubectl(["get", "applications", "-n", "argocd"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get ArgoCD apps: {stderr[:200]}",
        )
    apps = json.loads(stdout).get("items", [])
    not_synced = []
    for app in apps:
        sync_status = app.get("status", {}).get("sync", {}).get("status", "Unknown")
        if sync_status != "Synced":
            not_synced.append(f"{app['metadata']['name']} ({sync_status})")

    if not_synced:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Apps not synced: {len(not_synced)}",
            details={"not_synced": not_synced},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(apps)} ArgoCD app(s) Synced",
    )


@timed_test
def _test_argocd_apps_healthy(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check ArgoCD applications are Healthy."""
    rc, stdout, stderr = _kubectl(["get", "applications", "-n", "argocd"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get ArgoCD apps: {stderr[:200]}",
        )
    apps = json.loads(stdout).get("items", [])
    not_healthy = []
    for app in apps:
        health = app.get("status", {}).get("health", {}).get("status", "Unknown")
        if health not in ("Healthy", "Progressing"):
            not_healthy.append(f"{app['metadata']['name']} ({health})")

    if not_healthy:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Apps not healthy: {len(not_healthy)}",
            details={"not_healthy": not_healthy},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"All {len(apps)} ArgoCD app(s) Healthy",
    )


@timed_test
def _test_network_policies_applied(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check NetworkPolicies are applied in key namespaces."""
    rc, stdout, stderr = _kubectl(["get", "networkpolicies", "--all-namespaces"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get network policies: {stderr[:200]}",
        )
    nps = json.loads(stdout).get("items", [])
    np_namespaces = {np["metadata"]["namespace"] for np in nps}
    expected_ns = {"pki", "openbao", "spire"}
    missing = expected_ns - np_namespaces

    if missing:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"Namespaces missing NetworkPolicies: {', '.join(missing)}",
            details={"found_in": sorted(np_namespaces), "expected": sorted(expected_ns)},
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"NetworkPolicies found in {len(np_namespaces)} namespace(s)",
    )


@timed_test
def _test_spire_agent_running(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check SPIRE agent DaemonSet is running on all nodes."""
    rc, stdout, stderr = _kubectl(["get", "daemonset", "-n", "spire"], env)
    if rc != 0:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message=f"Failed to get DaemonSets: {stderr[:200]}",
        )
    ds_list = json.loads(stdout).get("items", [])
    if not ds_list:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL, message="No SPIRE DaemonSet found",
        )
    issues = []
    for ds in ds_list:
        desired = ds.get("status", {}).get("desiredNumberScheduled", 0)
        ready = ds.get("status", {}).get("numberReady", 0)
        if ready < desired:
            issues.append(f"{ds['metadata']['name']}: {ready}/{desired} ready")

    if issues:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"SPIRE agent issues: {', '.join(issues)}",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message="SPIRE agent running on all nodes",
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    kubeconfig = os.environ.get("KUBECONFIG", "")
    suite = run_all(project_root, kubeconfig)
    print(json.dumps(suite.to_dict(), indent=2))
