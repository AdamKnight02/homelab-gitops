#!/usr/bin/env python3
"""
PKI Platform Test Framework — Shared Library
Provides test result tracking, reporting, and utility functions.
"""

import json
import os
import subprocess
import sys
import time
import traceback
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class TestStatus(Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    BLOCKED = "BLOCKED"
    ERROR = "ERROR"


class TestResult:
    def __init__(
        self,
        test_id: str,
        name: str,
        level: int,
        status: TestStatus,
        message: str = "",
        duration_ms: float = 0.0,
        details: Optional[Dict[str, Any]] = None,
        remediation: str = "",
    ):
        self.test_id = test_id
        self.name = name
        self.level = level
        self.status = status
        self.message = message
        self.duration_ms = duration_ms
        self.details = details or {}
        self.remediation = remediation
        self.timestamp = datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "test_id": self.test_id,
            "name": self.name,
            "level": self.level,
            "status": self.status.value,
            "message": self.message,
            "duration_ms": round(self.duration_ms, 2),
            "details": self.details,
            "remediation": self.remediation,
            "timestamp": self.timestamp,
        }


class TestSuite:
    def __init__(self, name: str, level: int, description: str = ""):
        self.name = name
        self.level = level
        self.description = description
        self.results: List[TestResult] = []
        self.start_time: Optional[float] = None
        self.end_time: Optional[float] = None

    def start(self):
        self.start_time = time.time()

    def stop(self):
        self.end_time = time.time()

    def add_result(self, result: TestResult):
        self.results.append(result)

    @property
    def duration_ms(self) -> float:
        if self.start_time and self.end_time:
            return (self.end_time - self.start_time) * 1000
        return 0.0

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.PASS)

    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.FAIL)

    @property
    def skipped(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.SKIP)

    @property
    def blocked(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.BLOCKED)

    @property
    def errors(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.ERROR)

    @property
    def total(self) -> int:
        return len(self.results)

    @property
    def overall_status(self) -> TestStatus:
        if self.failed > 0 or self.errors > 0:
            return TestStatus.FAIL
        if self.blocked > 0:
            return TestStatus.BLOCKED
        if self.passed == 0 and self.skipped == self.total:
            return TestStatus.SKIP
        return TestStatus.PASS

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "level": self.level,
            "description": self.description,
            "duration_ms": round(self.duration_ms, 2),
            "total": self.total,
            "passed": self.passed,
            "failed": self.failed,
            "skipped": self.skipped,
            "blocked": self.blocked,
            "errors": self.errors,
            "overall_status": self.overall_status.value,
            "results": [r.to_dict() for r in self.results],
        }


class TestRunner:
    """Collects suites and generates reports."""

    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.suites: List[TestSuite] = []
        self.environment: Dict[str, Any] = {}
        self.start_time = datetime.now(timezone.utc)

    def add_suite(self, suite: TestSuite):
        self.suites.append(suite)

    def collect_environment(self):
        """Gather environment metadata for the report."""
        env = {
            "timestamp": self.start_time.isoformat(),
            "hostname": os.uname().nodename,
            "python_version": sys.version,
            "project_root": str(self.project_root),
        }
        # Tool availability
        for tool in ["terraform", "kubectl", "helm", "kustomize", "pwsh", "jq", "yq"]:
            env[f"tool_{tool}"] = shutil_which(tool)
        # Git info
        try:
            git_hash = subprocess.run(
                ["git", "rev-parse", "--short", "HEAD"],
                capture_output=True, text=True, cwd=self.project_root, timeout=5
            )
            env["git_commit"] = git_hash.stdout.strip() if git_hash.returncode == 0 else "unknown"
        except Exception:
            env["git_commit"] = "unknown"
        try:
            git_branch = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=self.project_root, timeout=5
            )
            env["git_branch"] = git_branch.stdout.strip() if git_branch.returncode == 0 else "unknown"
        except Exception:
            env["git_branch"] = "unknown"
        self.environment = env

    def generate_json_report(self, output_path: str):
        """Write machine-readable JSON report."""
        report = {
            "report_version": "1.0",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "environment": self.environment,
            "summary": {
                "total_suites": len(self.suites),
                "total_tests": sum(s.total for s in self.suites),
                "total_passed": sum(s.passed for s in self.suites),
                "total_failed": sum(s.failed for s in self.suites),
                "total_skipped": sum(s.skipped for s in self.suites),
                "total_blocked": sum(s.blocked for s in self.suites),
                "total_errors": sum(s.errors for s in self.suites),
                "overall_status": (
                    "FAIL" if any(s.overall_status == TestStatus.FAIL for s in self.suites)
                    else "BLOCKED" if any(s.overall_status == TestStatus.BLOCKED for s in self.suites)
                    else "PASS"
                ),
                "total_duration_ms": round(sum(s.duration_ms for s in self.suites), 2),
            },
            "suites": [s.to_dict() for s in self.suites],
        }
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(report, f, indent=2)
        return output_path

    def generate_text_report(self, output_path: str):
        """Write human-readable text report."""
        lines = []
        lines.append("=" * 80)
        lines.append("PKI PLATFORM TEST REPORT")
        lines.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")
        lines.append("=" * 80)
        lines.append("")

        # Environment
        lines.append("ENVIRONMENT")
        lines.append("-" * 40)
        for k, v in self.environment.items():
            lines.append(f"  {k}: {v}")
        lines.append("")

        # Summary
        total_tests = sum(s.total for s in self.suites)
        total_passed = sum(s.passed for s in self.suites)
        total_failed = sum(s.failed for s in self.suites)
        total_skipped = sum(s.skipped for s in self.suites)
        total_blocked = sum(s.blocked for s in self.suites)
        total_errors = sum(s.errors for s in self.suites)
        overall = (
            "FAIL" if any(s.overall_status == TestStatus.FAIL for s in self.suites)
            else "BLOCKED" if any(s.overall_status == TestStatus.BLOCKED for s in self.suites)
            else "PASS"
        )

        lines.append("SUMMARY")
        lines.append("-" * 40)
        lines.append(f"  Overall Status: {overall}")
        lines.append(f"  Total Tests:    {total_tests}")
        lines.append(f"  Passed:         {total_passed}")
        lines.append(f"  Failed:         {total_failed}")
        lines.append(f"  Skipped:        {total_skipped}")
        lines.append(f"  Blocked:        {total_blocked}")
        lines.append(f"  Errors:         {total_errors}")
        lines.append("")

        # Suite details
        for suite in self.suites:
            status_icon = {
                TestStatus.PASS: "✅",
                TestStatus.FAIL: "❌",
                TestStatus.SKIP: "⏭️",
                TestStatus.BLOCKED: "🚫",
                TestStatus.ERROR: "💥",
            }
            lines.append(f"LEVEL {suite.level}: {suite.name}")
            lines.append(f"  Status: {status_icon.get(suite.overall_status, '?')} {suite.overall_status.value}")
            lines.append(f"  Tests: {suite.total} | Pass: {suite.passed} | Fail: {suite.failed} | Skip: {suite.skipped} | Block: {suite.blocked}")
            lines.append(f"  Duration: {suite.duration_ms:.0f}ms")
            lines.append("")

            for r in suite.results:
                icon = status_icon.get(r.status, "?")
                lines.append(f"  {icon} [{r.test_id}] {r.name}")
                if r.message:
                    lines.append(f"     Message: {r.message}")
                if r.remediation:
                    lines.append(f"     Fix: {r.remediation}")
                if r.details:
                    for dk, dv in r.details.items():
                        lines.append(f"     {dk}: {dv}")
            lines.append("")

        lines.append("=" * 80)
        lines.append("END OF REPORT")
        lines.append("=" * 80)

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            f.write("\n".join(lines))
        return output_path


def shutil_which(cmd: str) -> Optional[str]:
    """Find command in PATH."""
    for path_dir in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(path_dir, cmd)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def run_command(
    cmd: List[str],
    cwd: Optional[str] = None,
    timeout: int = 60,
    env: Optional[Dict[str, str]] = None,
) -> Tuple[int, str, str]:
    """Run a command and return (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=timeout,
            env={**os.environ, **(env or {})},
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"Command timed out after {timeout}s"
    except FileNotFoundError:
        return -2, "", f"Command not found: {cmd[0]}"
    except Exception as e:
        return -3, "", str(e)


def timed_test(func):
    """Decorator to time a test function and return a TestResult.
    
    The decorated function must accept test_id, name, level as keyword arguments.
    The wrapper passes through all positional and keyword args, adding timing.
    """
    import functools
    @functools.wraps(func)
    def wrapper(*args, **kwargs) -> TestResult:
        start = time.time()
        # Extract test_id, name, level from kwargs for error reporting
        _test_id = kwargs.get("test_id", "UNKNOWN")
        _name = kwargs.get("name", "UNKNOWN")
        _level = kwargs.get("level", 0)
        try:
            result = func(*args, **kwargs)
            if isinstance(result, TestResult):
                result.duration_ms = (time.time() - start) * 1000
                return result
            return result
        except Exception as e:
            return TestResult(
                test_id=_test_id,
                name=_name,
                level=_level,
                status=TestStatus.ERROR,
                message=f"Unexpected error: {str(e)}",
                duration_ms=(time.time() - start) * 1000,
                details={"traceback": traceback.format_exc()},
            )
    return wrapper


def find_files(root: str, pattern: str, exclude_dirs: Optional[List[str]] = None) -> List[str]:
    """Find files matching a glob pattern, excluding certain directories."""
    import fnmatch
    exclude = set(exclude_dirs or [".git", ".terraform", "node_modules", "__pycache__"])
    matches = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude]
        for filename in fnmatch.filter(filenames, pattern):
            matches.append(os.path.join(dirpath, filename))
    return sorted(matches)
