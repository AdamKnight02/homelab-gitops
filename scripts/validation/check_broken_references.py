#!/usr/bin/env python3
# Verify that local script/path references in GitHub Actions workflows
# resolve to existing files. Read-only; stdlib only; no regex by design
# (keeps verbatim transcription safe).
import json
import sys
from pathlib import Path

PREFIXES = ('scripts/', 'tests/', 'pipelines/', './')
SUFFIXES = ('.sh', '.py', '.ps1', '.yml', '.yaml')
TRIM = '\'\"),:;#[]{}'


def candidates(text):
    for raw in text.splitlines():
        line = raw.strip()
        tokens = line.replace('=', ' ').split()
        for tok in tokens:
            tok = tok.strip(TRIM)
            if tok.startswith('./'):
                tok = tok[2:]
            if tok.startswith(PREFIXES[:3]) and tok.endswith(SUFFIXES):
                yield tok
        if 'uses:' in line:
            tail = line.split('uses:', 1)[1].strip().strip(TRIM)
            if tail.startswith('./'):
                yield tail[2:]


def main(root):
    root = Path(root)
    findings = []
    wfdir = root / '.github' / 'workflows'
    files = sorted(wfdir.glob('*.yml')) + sorted(wfdir.glob('*.yaml'))
    for wf in files:
        try:
            text = wf.read_text(errors='replace')
        except OSError:
            continue
        for rel in candidates(text):
            if not (root / rel).exists():
                findings.append({
                    'severity': 'CRITICAL',
                    'workflow': str(wf.relative_to(root)),
                    'reference': rel,
                    'problem': 'referenced path does not exist',
                })
    return {'check': 'broken-references', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
