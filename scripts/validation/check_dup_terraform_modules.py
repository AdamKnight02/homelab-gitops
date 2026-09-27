#!/usr/bin/env python3
# Detect terraform module labels defined more than once across roots.
# Read-only; stdlib only; no regex by design.
import json
import sys
from pathlib import Path


def main(root):
    root = Path(root)
    defs = {}
    for f in (root / 'infra' / 'terraform').rglob('*.tf'):
        try:
            lines = f.read_text(errors='replace').splitlines()
        except OSError:
            continue
        for line in lines:
            s = line.strip()
            if s.startswith('module ') and s.count('"') >= 2:
                name = s.split('"')[1]
                defs.setdefault(name, set()).add(str(f.relative_to(root)))
    findings = []
    for name, files in sorted(defs.items()):
        if len(files) > 1:
            findings.append({
                'severity': 'WARN', 'module': name,
                'definitions': sorted(files),
                'problem': 'module "' + name + '" defined in '
                + str(len(files)) + ' files'})
    return {'check': 'dup-terraform-modules', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
