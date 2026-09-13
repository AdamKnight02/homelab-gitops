## Description: <br>
Kubernetes certificate management with cert-manager. Use when managing TLS certificates, configuring issuers, or troubleshooting certificate issues. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[rohitg00](https://clawhub.ai/user/rohitg00) <br>

### License/Terms of Use: <br>


## Use Case: <br>
Developers and platform engineers use this skill to manage Kubernetes TLS certificates with cert-manager, including issuers, certificate requests, troubleshooting, and Ingress-based certificate issuance. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: The skill includes examples that can make persistent changes to live Kubernetes certificate, issuer, and ingress resources. <br>
Mitigation: Use least-privileged Kubernetes credentials, confirm the active cluster and namespace, inspect each manifest, prefer staging or dry-run validation, and require explicit approval before kubectl_apply. <br>
Risk: Production ACME issuer examples can affect real certificate issuance and service availability. <br>
Mitigation: Start with the staging issuer, verify DNS and solver configuration, and only switch to production after review. <br>


## Reference(s): <br>
- [Skill page](https://clawhub.ai/rohitg00/skills/k8s-certs) <br>
- [Let's Encrypt staging ACME directory](https://acme-staging-v02.api.letsencrypt.org/directory) <br>
- [Let's Encrypt production ACME directory](https://acme-v02.api.letsencrypt.org/directory) <br>


## Skill Output: <br>
**Output Type(s):** [guidance, shell commands, configuration] <br>
**Output Format:** [Markdown with kubectl and cert-manager tool examples] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [May include Kubernetes manifests for Certificate, ClusterIssuer, and Ingress resources.] <br>

## Skill Version(s): <br>
1.0.0 (source: server-resolved release metadata) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
