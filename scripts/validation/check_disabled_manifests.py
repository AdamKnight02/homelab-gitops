#!/usr/bin/env python3
# Find disabled or inert automation manifests: workflows gated off,
# disabled-suffix files, and missing-trigger workflows.
# Read-only; stdlib only; no regex by design.
import json
import sys
from pathlib import Path


def main(root):
    root = Path(root)
    findings = []
    wfdir = root / '.github' / 'workflows'
    files = sorted(wfdir.glob('*.yml')) + sorted(wfdir.glob('*.yaml'))
    for wf in files:
        text = wf.read_text(errors='replace')
        rel = str(wf.relative_to(root))
        has_on = False
        for line in text.splitlines():
            s = line.strip()
            if s == 'if: false':
                findings.append({'severity': 'WARN', 'file': rel,
                                 'problem': 'job/workflow gated with if: false'})
                break
        for line in text.splitlines():
            s = line.strip()
            if s.startswith('on:') or s == 'on':
                has_on = True
                break
        if not has_on and 'workflow_dispatch' not in text:
            findings.append({'severity': 'WARN', 'file': rel,
                             'problem': 'no trigger (on:) block found'})
    for p in root.rglob('*'):
        if p.is_file() and p.suffix in ('.disabled', '.skip', '.bak', '.orig'):
            findings.append({'severity': 'INFO', 'file': str(p.relative_to(root)),
                             'problem': 'disabled-suffix file (*' + p.suffix + ')'})
    return {'check': 'disabled-manifests', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
