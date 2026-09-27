#!/usr/bin/env python3
# Detect documentation drift: repo-relative paths referenced in markdown
# docs that no longer exist. Read-only; stdlib only; no regex by design.
import json
import sys
from pathlib import Path

PREFIXES = ('apps/', 'infra/', 'infrastructure/', 'scripts/', 'tests/',
            'docs/', 'pipelines/', 'gitops/', 'configuration/',
            'customers/', 'bootstrap/')
TRIM = '`./,):;'


def main(root):
    root = Path(root)
    findings = []
    docs = list(root.glob('*.md')) + list((root / 'docs').rglob('*.md'))
    for doc in sorted(docs):
        try:
            text = doc.read_text(errors='replace')
        except OSError:
            continue
        for seg in text.split('`'):
            seg = seg.strip().rstrip('./,):;')
            if seg.startswith(PREFIXES) and ' ' not in seg and len(seg) > 8:
                if not (root / seg).exists():
                    findings.append({
                        'severity': 'WARN',
                        'doc': str(doc.relative_to(root)),
                        'reference': seg,
                        'problem': 'documented path does not exist',
                    })
    return {'check': 'docs-manifest-drift', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
