#!/usr/bin/env python3
"""
PKI Platform Test Runner
Orchestrates all test levels and generates reports.

Usage:
    python3 tests/run_tests.py [--level N] [--provider PROVIDER] [--output-dir DIR] [--kubeconfig PATH]

Levels:
    1 — Static validation (no cluster/cloud needed)
    2 — Cloud infrastructure (needs cloud CLI + credentials)
    3 — Kubernetes (needs kubectl + cluster)
    4 — Platform health (needs kubectl + running platform)
    5 — PKI protocols (needs kubectl + EJBCA)
    6 — Idempotency (needs kubectl + terraform state)
    7 — Lifecycle (needs cloud credentials + ephemeral env)
    matrix — Provider/tier matrix
    extca — External CA matrix
    all — All applicable levels
"""

import argparse
import importlib
import importlib.util
import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.test_framework import TestRunner, TestStatus


def _load_module(module_path: str, module_name: str):
    """Dynamically load a module from a file path (handles hyphenated dirs)."""
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load module from {module_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    parser = argparse.ArgumentParser(description="PKI Platform Test Runner")
    parser.add_argument(
        "--level", "-l",
        type=str,
        default="all",
        help="Test level to run (1-7, matrix, extca, all, all-live, static, quick). Default: all",
    )
    parser.add_argument(
        "--provider", "-p",
        type=str,
        default="all",
        choices=["all", "azure", "aws", "alibaba"],
        help="Cloud provider to test. Default: all",
    )
    parser.add_argument(
        "--output-dir", "-o",
        type=str,
        default=None,
        help="Output directory for reports. Default: tests/reports/<timestamp>",
    )
    parser.add_argument(
        "--kubeconfig", "-k",
        type=str,
        default="",
        help="Path to kubeconfig file",
    )
    parser.add_argument(
        "--project-root",
        type=str,
        default=None,
        help="Project root directory. Default: parent of tests/",
    )
    args = parser.parse_args()

    # Determine project root
    if args.project_root:
        project_root = args.project_root
    else:
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Determine output directory
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    if args.output_dir:
        output_dir = args.output_dir
    else:
        output_dir = os.path.join(project_root, "tests", "reports", timestamp)
    os.makedirs(output_dir, exist_ok=True)

    # Create test runner
    runner = TestRunner(project_root)
    runner.collect_environment()

    levels_to_run = _parse_levels(args.level)
    tests_dir = os.path.dirname(os.path.abspath(__file__))

    print(f"PKI Platform Test Runner")
    print(f"Project root: {project_root}")
    print(f"Output dir:   {output_dir}")
    print(f"Levels:       {', '.join(str(l) for l in levels_to_run)}")
    print(f"Provider:     {args.provider}")
    print()

    # Run test levels
    for level in levels_to_run:
        if level == 1:
            print("Running LEVEL 1: Static Validation...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level1-static", "test_static_validation.py"),
                    "test_static_validation",
                )
                suite = mod.run_all(project_root)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 2:
            print("Running LEVEL 2: Cloud Infrastructure...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level2-cloud", "test_cloud_infrastructure.py"),
                    "test_cloud_infrastructure",
                )
                suite = mod.run_all(project_root, args.provider)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 3:
            print("Running LEVEL 3: Kubernetes...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level3-kubernetes", "test_kubernetes.py"),
                    "test_kubernetes",
                )
                suite = mod.run_all(project_root, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 4:
            print("Running LEVEL 4: Platform Health...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level4-platform", "test_platform.py"),
                    "test_platform",
                )
                suite = mod.run_all(project_root, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 5:
            print("Running LEVEL 5: PKI Protocols...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level5-pki", "test_pki_protocols.py"),
                    "test_pki_protocols",
                )
                suite = mod.run_all(project_root, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 6:
            print("Running LEVEL 6: Idempotency...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level6-idempotency", "test_idempotency.py"),
                    "test_idempotency",
                )
                suite = mod.run_all(project_root, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == 7:
            print("Running LEVEL 7: Lifecycle...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "level7-lifecycle", "test_lifecycle.py"),
                    "test_lifecycle",
                )
                provider = args.provider if args.provider != "all" else "azure"
                suite = mod.run_all(project_root, provider, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == "matrix":
            print("Running Provider/Tier Matrix...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "matrix", "provider-tier", "test_provider_tier_matrix.py"),
                    "test_provider_tier_matrix",
                )
                suite = mod.run_all(project_root)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

        elif level == "extca":
            print("Running External CA Matrix...")
            try:
                mod = _load_module(
                    os.path.join(tests_dir, "matrix", "external-ca", "test_external_ca_matrix.py"),
                    "test_external_ca_matrix",
                )
                suite = mod.run_all(project_root, args.kubeconfig)
                runner.add_suite(suite)
                _print_suite_summary(suite)
            except Exception as e:
                print(f"  ERROR: {e}")

    # Generate reports
    print()
    print("Generating reports...")
    json_path = os.path.join(output_dir, "test-report.json")
    text_path = os.path.join(output_dir, "test-report.txt")

    runner.generate_json_report(json_path)
    runner.generate_text_report(text_path)

    print(f"  JSON report: {json_path}")
    print(f"  Text report: {text_path}")

    # Print summary
    total = sum(s.total for s in runner.suites)
    passed = sum(s.passed for s in runner.suites)
    failed = sum(s.failed for s in runner.suites)
    skipped = sum(s.skipped for s in runner.suites)
    blocked = sum(s.blocked for s in runner.suites)
    errors = sum(s.errors for s in runner.suites)

    print()
    print("=" * 60)
    print(f"TOTAL: {total} | PASS: {passed} | FAIL: {failed} | SKIP: {skipped} | BLOCK: {blocked} | ERROR: {errors}")
    overall = "FAIL" if failed > 0 or errors > 0 else "BLOCKED" if blocked > 0 else "PASS"
    print(f"OVERALL: {overall}")
    print("=" * 60)

    # Exit code
    if failed > 0 or errors > 0:
        sys.exit(1)
    elif blocked > 0:
        sys.exit(2)
    else:
        sys.exit(0)


def _parse_levels(level_str: str) -> list:
    """Parse level argument into list of levels to run."""
    if level_str == "all":
        return [1, "matrix", "extca"]  # Only levels that can run without cluster by default
    if level_str == "all-live":
        return [1, 2, 3, 4, 5, 6, 7, "matrix", "extca"]
    if level_str == "static":
        return [1]
    if level_str == "quick":
        return [1, "matrix"]

    levels = []
    for part in level_str.split(","):
        part = part.strip()
        if part.isdigit():
            levels.append(int(part))
        elif part in ("matrix", "extca"):
            levels.append(part)
    return levels if levels else [1]


def _print_suite_summary(suite):
    """Print a one-line summary of a test suite."""
    status_icon = {
        TestStatus.PASS: "✅",
        TestStatus.FAIL: "❌",
        TestStatus.SKIP: "⏭️",
        TestStatus.BLOCKED: "🚫",
        TestStatus.ERROR: "💥",
    }
    icon = status_icon.get(suite.overall_status, "?")
    print(f"  {icon} Level {suite.level} ({suite.name}): "
          f"{suite.passed}/{suite.total} passed, "
          f"{suite.failed} failed, {suite.skipped} skipped, "
          f"{suite.blocked} blocked [{suite.duration_ms:.0f}ms]")


if __name__ == "__main__":
    main()
