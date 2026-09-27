#!/usr/bin/env python3
"""Detect duplicate monitoring stack definitions (prometheus/grafana/
alertmanager in multiple independent locations). Read-only; stdlib only."""
import json, re, sys
from pathlib import Path

TERM = re.compile(r"prometheus|kube-prometheus-stack|grafana|alertmanager", re.I)

def main(root):
    root = Path(root)
    hits = {}
    skip = {".git", "node_modules", "__pycache__"}
    for p in root.rglob("*"):
        if not p.is_file() or any(s in p.parts for s in skip):
            continue
        if p.suffix not in (".yaml", ".yml", ".json", ".tf"):
            continue
        try:
            text = p.read_text(errors="replace")
        except OSError:
            continue
        if TERM.search(text):
            rel = str(p.relative_to(root))
            top = rel.split("/")[0]
            hits.setdefault(top, []).append(rel)
    findings = []
    if len(hits) > 1:
        findings.append({
            "severity": "INFO",
            "locations": {k: v[:6] for k, v in sorted(hits.items())},
            "problem": f"monitoring stack referenced under {len(hits)} top-level trees"})
    return {"check": "dup-monitoring", "findings": findings}

if __name__ == "__main__":
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else "."), indent=1))
