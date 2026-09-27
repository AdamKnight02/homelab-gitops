#!/usr/bin/env python3
"""Merge the seven reports/repo-problems/*.json findings files into a
severity-ranked markdown report. Read-only; stdlib only."""
import json, sys
from pathlib import Path

ORDER = {"CRITICAL": 0, "WARN": 1, "INFO": 2}

def main(root):
    root = Path(root)
    rdir = root / "reports" / "repo-problems"
    sections = []
    for f in sorted(rdir.glob("*.json")):
        try:
            data = json.loads(f.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        findings = data.get("findings", [])
        findings.sort(key=lambda x: ORDER.get(x.get("severity", "INFO"), 3))
        lines = [f"## {data.get('check', f.stem)} ({len(findings)} findings)", ""]
        if not findings:
            lines.append("No findings.")
        for fnd in findings:
            sev = fnd.get("severity", "INFO")
            where = fnd.get("file") or fnd.get("doc") or fnd.get("workflow") \
                or fnd.get("module") or fnd.get("ca") or ""
            ref = fnd.get("reference")
            if ref:
                where = f"{where} -> {ref}"
            lines.append(f"- [{sev}] {where}: {fnd.get('problem', '')}")
        lines.append("")
        sections.append("\n".join(lines))
    header = "# Repository Problems\n\nAggregated from reports/repo-problems/*.json (severity-ranked).\n"
    return header + "\n" + "\n".join(sections)

if __name__ == "__main__":
    print(main(sys.argv[1] if len(sys.argv) > 1 else "."))
