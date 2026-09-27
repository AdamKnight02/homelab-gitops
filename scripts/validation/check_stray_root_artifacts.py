#!/usr/bin/env python3
# Find stray artifacts at the repository root: one-off scripts, state
# files, session dumps, and other non-project clutter.
# Read-only; stdlib only; no regex by design.
import json
import sys
from pathlib import Path

ARTIFACT_SUFFIXES = ('.pyc', '.pyo', '.bak', '.orig', '.tmp', '.log', '.swp')
SCRATCH_PREFIXES = ('test-', 'flush-', 'tmp-', 'scratch-')
STATE_PREFIXES = ('openclaw-', 'session-', 'workspace-')
STATUS_PREFIXES = ('PHASE', 'INVENTORY', 'SESSION')
KEEP = ('README.md', 'AGENTS.md')


def classify(name):
    if name.endswith(ARTIFACT_SUFFIXES):
        return 'build/editor artifact'
    if name.startswith(SCRATCH_PREFIXES):
        return 'test/scratch file'
    if name.startswith(STATE_PREFIXES) and name.endswith(('.json', '.md')):
        return 'agent session/state file'
    if name.startswith('convert_to_') and name.endswith('.py'):
        return 'one-off utility script'
    if name.startswith(STATUS_PREFIXES) and name.endswith('.md'):
        return 'status/report dump'
    return None


def main(root):
    root = Path(root)
    findings = []
    for p in sorted(root.iterdir()):
        if p.name.startswith('.') or p.name in KEEP:
            continue
        reason = classify(p.name)
        if reason:
            findings.append({'severity': 'INFO', 'file': p.name,
                             'problem': 'stray root artifact: ' + reason})
    return {'check': 'stray-root-artifacts', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
