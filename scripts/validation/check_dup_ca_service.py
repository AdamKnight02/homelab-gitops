#!/usr/bin/env python3
# Detect duplicate/overlapping certificate-authority service definitions
# across the GitOps tree. Read-only; stdlib only.
import json
import re
import sys
from pathlib import Path

CA_TERMS = re.compile(r'kind:\s*(Deployment|StatefulSet)[\s\S]{0,400}?name:\s*[\w-]*(ejbca|step-ca|vault|openbao|cert-manager|cfssl|smallstep)', re.I)


def main(root):
    root = Path(root)
    hits = {}
    for base in ('apps', 'gitops', 'infra', 'infrastructure', 'apps-tf'):
        bdir = root / base
        if not bdir.is_dir():
            continue
        for f in bdir.rglob('*.yaml'):
            text = f.read_text(errors='replace')
            for m in CA_TERMS.finditer(text):
                ca = m.group(2).lower()
                hits.setdefault(ca, set()).add(str(f.relative_to(root)))
    findings = []
    for ca, files in sorted(hits.items()):
        if len(files) > 1:
            findings.append({
                'severity': 'WARN', 'ca': ca,
                'definitions': sorted(files),
                'problem': ca + ' defined in ' + str(len(files)) + ' places'})
    return {'check': 'dup-ca-service', 'findings': findings}


if __name__ == '__main__':
    print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else '.'), indent=1))
