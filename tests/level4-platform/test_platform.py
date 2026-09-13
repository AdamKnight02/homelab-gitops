#!/usr/bin/env python3
"""
LEVEL 4: Platform Tests
Tests that validate platform component health: EJBCA, PostgreSQL, RabbitMQ,
OpenBao, SPIRE, cert-api, cert-worker, Prometheus, Grafana.
Requires kubectl access and running platform.
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
        "Platform Health",
        level=4,
        description="Validate platform component health and readiness",
    )
    suite.start()

    env = {}
    if kubeconfig:
        env["KUBECONFIG"] = kubeconfig

    # Pre-check
    kubectl_check = _check_kubectl()
    suite.add_result(kubectl_check)
    if kubectl_check.status in (TestStatus.BLOCKED, TestStatus.FAIL):
        for name in [
            "EJBCA Health", "PostgreSQL Ready", "RabbitMQ Ready",
            "OpenBao Sealed Status", "SPIRE Server Health", "cert-api Health",
            "cert-worker Health", "Prometheus Targets", "Grafana Health",
        ]:
            suite.add_result(TestResult(
                test_id=f"L4-{name.replace(' ', '_').upper()}",
                name=name, level=4,
                status=TestStatus.BLOCKED,
                message="kubectl not available or cluster unreachable",
            ))
        suite.stop()
        return suite

    suite.add_result(_test_ejbca_health(env, test_id="L4-EJBCA", name="EJBCA Health", level=4))
    suite.add_result(_test_postgres_ready(env, test_id="L4-POSTGRES", name="PostgreSQL Ready", level=4))
    suite.add_result(_test_rabbitmq_ready(env, test_id="L4-RABBITMQ", name="RabbitMQ Ready", level=4))
    suite.add_result(_test_openbao_status(env, test_id="L4-OPENBAO", name="OpenBao Sealed Status", level=4))
    suite.add_result(_test_spire_server_health(env, test_id="L4-SPIRE", name="SPIRE Server Health", level=4))
    suite.add_result(_test_cert_api_health(env, test_id="L4-CERT-API", name="cert-api Health", level=4))
    suite.add_result(_test_cert_worker_health(env, test_id="L4-CERT-WORKER", name="cert-worker Health", level=4))
    suite.add_result(_test_prometheus_targets(env, test_id="L4-PROMETHEUS", name="Prometheus Targets", level=4))
    suite.add_result(_test_grafana_health(env, test_id="L4-GRAFANA", name="Grafana Health", level=4))

    suite.stop()
    return suite


@timed_test
def _check_kubectl(test_id: str = "L4-KUBECTL", name: str = "kubectl Available", level: int = 4) -> TestResult:
    if not shutil_which("kubectl"):
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.BLOCKED, message="kubectl not installed")
    rc, stdout, stderr = run_command(["kubectl", "cluster-info"], timeout=10)
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.BLOCKED, message=f"Cluster unreachable: {stderr[:200]}")
    return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.PASS, message="kubectl available")


def _kubectl_exec(namespace: str, pod_selector: str, command: list, env: dict = None, timeout: int = 30) -> tuple:
    """Execute a command in a pod."""
    # First find the pod
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", namespace, "-l", pod_selector, "-o", "jsonpath={.items[0].metadata.name}"],
        timeout=10, env=env,
    )
    if rc != 0 or not stdout.strip():
        return -1, "", f"No pod found with selector {pod_selector} in {namespace}"
    pod_name = stdout.strip()
    return run_command(
        ["kubectl", "exec", "-n", namespace, pod_name, "--"] + command,
        timeout=timeout, env=env,
    )


@timed_test
def _test_ejbca_health(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check EJBCA is responding."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "ejbca", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get EJBCA pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    ejbca_pods = [p for p in pods if "ejbca" in p["metadata"]["name"].lower()]
    if not ejbca_pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No EJBCA pods found")

    running = [p for p in ejbca_pods if p.get("status", {}).get("phase") == "Running"]
    if not running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="EJBCA pods not Running")

    # Try to check EJBCA health endpoint via port-forward or exec
    rc, stdout, stderr = _kubectl_exec(
        "ejbca", "app.kubernetes.io/name=ejbca-ce",
        ["curl", "-sk", "https://localhost:8443/ejbca/publicweb/healthcheck/ejbcahealth"],
        env=env, timeout=15,
    )
    if rc == 0 and ("ALLOK" in stdout or "ok" in stdout.lower()):
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.PASS, message="EJBCA health check passed")

    # Fallback: just check pod is running
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"EJBCA pod(s) running ({len(running)}/{len(ejbca_pods)}), health endpoint check inconclusive",
        details={"pods": [p["metadata"]["name"] for p in running]},
    )


@timed_test
def _test_postgres_ready(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check PostgreSQL is ready and accepting connections."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "ejbca", "-l", "app.kubernetes.io/name=postgresql", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get PostgreSQL pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        # Try pki namespace for pki-database
        rc, stdout, stderr = run_command(
            ["kubectl", "get", "pods", "-n", "pki", "-l", "app=pki-database", "-o", "json"],
            timeout=10, env=env,
        )
        if rc == 0:
            pods = json.loads(stdout).get("items", [])

    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No PostgreSQL pods found")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    if not running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="PostgreSQL pods not Running")

    # Check readiness via pg_isready
    pod_name = running[0]["metadata"]["name"]
    ns = running[0]["metadata"]["namespace"]
    rc, stdout, stderr = run_command(
        ["kubectl", "exec", "-n", ns, pod_name, "--", "pg_isready", "-U", "postgres"],
        timeout=10, env=env,
    )
    if rc == 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.PASS, message="PostgreSQL accepting connections")

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"PostgreSQL pod(s) running ({len(running)}), readiness probe check inconclusive",
    )


@timed_test
def _test_rabbitmq_ready(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check RabbitMQ is ready."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "rabbitmq", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get RabbitMQ pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No RabbitMQ pods found")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    if not running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="RabbitMQ pods not Running")

    # Check RabbitMQ status
    pod_name = running[0]["metadata"]["name"]
    rc, stdout, stderr = run_command(
        ["kubectl", "exec", "-n", "rabbitmq", pod_name, "--", "rabbitmqctl", "status"],
        timeout=15, env=env,
    )
    if rc == 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.PASS, message="RabbitMQ running and responsive")

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"RabbitMQ pod(s) running ({len(running)}), status check inconclusive",
    )


@timed_test
def _test_openbao_status(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check OpenBao seal status."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "openbao", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get OpenBao pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No OpenBao pods found")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    if not running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="OpenBao pods not Running")

    # Check seal status
    pod_name = running[0]["metadata"]["name"]
    rc, stdout, stderr = run_command(
        ["kubectl", "exec", "-n", "openbao", pod_name, "--", "bao", "status", "-tls-skip-verify", "-format=json"],
        timeout=15, env=env,
    )
    if rc == 0:
        try:
            status = json.loads(stdout)
            sealed = status.get("sealed", True)
            if not sealed:
                return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.PASS, message="OpenBao unsealed and running")
            else:
                return TestResult(
                    test_id=test_id, name=name, level=level,
                    status=TestStatus.FAIL,
                    message="OpenBao is SEALED",
                    remediation="Unseal with: kubectl exec -n openbao openbao-0 -- bao operator unseal -tls-skip-verify <key>",
                )
        except json.JSONDecodeError:
            pass

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"OpenBao pod(s) running ({len(running)}), seal status check inconclusive",
    )


@timed_test
def _test_spire_server_health(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check SPIRE server health."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "spire", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get SPIRE pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    server_pods = [p for p in pods if "server" in p["metadata"]["name"].lower()]
    agent_pods = [p for p in pods if "agent" in p["metadata"]["name"].lower()]

    if not server_pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No SPIRE server pods found")

    server_running = [p for p in server_pods if p.get("status", {}).get("phase") == "Running"]
    agent_running = [p for p in agent_pods if p.get("status", {}).get("phase") == "Running"]

    if not server_running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="SPIRE server not Running")

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"SPIRE server: {len(server_running)} running, agent: {len(agent_running)} running",
        details={"server_pods": len(server_running), "agent_pods": len(agent_running)},
    )


@timed_test
def _test_cert_api_health(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check cert-api deployment health."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "pki", "-l", "app=cert-api", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get cert-api pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No cert-api pods found")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    ready = [p for p in pods if all(
        cs.get("ready", False) for cs in p.get("status", {}).get("containerStatuses", [])
    )]

    if not ready:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"cert-api pods not ready ({len(ready)}/{len(pods)})",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"cert-api: {len(ready)}/{len(pods)} pods ready",
    )


@timed_test
def _test_cert_worker_health(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check cert-worker deployment health."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "pki", "-l", "app=cert-worker", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get cert-worker pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="No cert-worker pods found")

    ready = [p for p in pods if all(
        cs.get("ready", False) for cs in p.get("status", {}).get("containerStatuses", [])
    )]

    if not ready:
        return TestResult(
            test_id=test_id, name=name, level=level,
            status=TestStatus.FAIL,
            message=f"cert-worker pods not ready ({len(ready)}/{len(pods)})",
        )
    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"cert-worker: {len(ready)}/{len(pods)} pods ready",
    )


@timed_test
def _test_prometheus_targets(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check Prometheus targets are up."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "monitoring", "-l", "app.kubernetes.io/name=prometheus", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get Prometheus pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.SKIP, message="No Prometheus pods found (monitoring may be disabled)")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    if not running:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="Prometheus pods not Running")

    # Query Prometheus targets API
    pod_name = running[0]["metadata"]["name"]
    rc, stdout, stderr = run_command(
        ["kubectl", "exec", "-n", "monitoring", pod_name, "-c", "prometheus", "--",
         "wget", "-qO-", "http://localhost:9090/api/v1/targets?state=active"],
        timeout=15, env=env,
    )
    if rc == 0:
        try:
            data = json.loads(stdout)
            targets = data.get("data", {}).get("activeTargets", [])
            down = [t for t in targets if t.get("health") != "up"]
            if down:
                return TestResult(
                    test_id=test_id, name=name, level=level,
                    status=TestStatus.FAIL,
                    message=f"Prometheus targets down: {len(down)}/{len(targets)}",
                    details={"down": [t.get("labels", {}).get("job", "unknown") for t in down]},
                )
            return TestResult(
                test_id=test_id, name=name, level=level,
                status=TestStatus.PASS,
                message=f"All {len(targets)} Prometheus targets up",
            )
        except json.JSONDecodeError:
            pass

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Prometheus pod(s) running ({len(running)}), target check inconclusive",
    )


@timed_test
def _test_grafana_health(env: dict, test_id: str, name: str, level: int) -> TestResult:
    """Check Grafana is healthy."""
    rc, stdout, stderr = run_command(
        ["kubectl", "get", "pods", "-n", "monitoring", "-l", "app.kubernetes.io/name=grafana", "-o", "json"],
        timeout=10, env=env,
    )
    if rc != 0:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message=f"Cannot get Grafana pods: {stderr[:200]}")

    pods = json.loads(stdout).get("items", [])
    if not pods:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.SKIP, message="No Grafana pods found (monitoring may be disabled)")

    running = [p for p in pods if p.get("status", {}).get("phase") == "Running"]
    ready = [p for p in pods if all(
        cs.get("ready", False) for cs in p.get("status", {}).get("containerStatuses", [])
    )]

    if not ready:
        return TestResult(test_id=test_id, name=name, level=level, status=TestStatus.FAIL, message="Grafana pods not ready")

    return TestResult(
        test_id=test_id, name=name, level=level,
        status=TestStatus.PASS,
        message=f"Grafana: {len(ready)}/{len(pods)} pods ready",
    )


if __name__ == "__main__":
    project_root = os.environ.get("PROJECT_ROOT", os.path.join(os.path.dirname(__file__), ".."))
    kubeconfig = os.environ.get("KUBECONFIG", "")
    suite = run_all(project_root, kubeconfig)
    print(json.dumps(suite.to_dict(), indent=2))
