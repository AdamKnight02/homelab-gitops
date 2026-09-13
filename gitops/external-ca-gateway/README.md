# External CA Gateway — GitOps Deployment Pattern

The external CA gateway bridges the platform to third-party CAs
(DigiCert, Entrust, GlobalSign, Microsoft CA, smallstep, etc.).
Two deployment shapes are supported:

## 1. Containerized (preferred, where supported)

The gateway runs as a container in-cluster. Used for CAs with REST APIs
(DigiCert CertCentral, Entrust CA Gateway, GlobalSign Atlas, smallstep).

```
gitops/external-ca-gateway/
├── base/                       # cloud-neutral Deployment + Service + SA
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── networkpolicy.yaml
│   ├── servicemonitor.yaml
│   └── kustomization.yaml
└── overlays/
    ├── containerized/          # per-provider config (digicert, entrust, ...)
    │   ├── digicert/
    │   ├── entrust/
    │   └── globalsign/
    └── agent/                  # non-containerizable CAs (see below)
```

Per-provider overlay supplies: image tag, env config, credentials via
ExternalSecret/SealedSecret, and a blackbox Probe for reachability.

## 2. Agent pattern (non-containerizable CAs)

Some CAs cannot be containerized — Microsoft ADCS (requires Windows +
domain join), HSM-fronted CAs with host-bound PKCS#11 drivers. For these,
a lightweight **gateway agent** runs on a Windows/Linux host near the CA
and the cluster deploys only the in-cluster **gateway client** (a thin
Deployment that proxies enrollment requests to the agent over mTLS).

The GitOps tree is identical; the `agent` overlay adds:
- the in-cluster client Deployment
- a ConfigMap with the agent's external endpoint
- a Probe with module `tcp_connect` or `https_cert` targeting the agent
- agent installation is handled outside GitOps (Ansible/Winget) since the
  host is not Kubernetes-managed

## Promotion flow

base → provider overlay (digicert) → tier overlay (rate limits, HA) →
customer overlay (which CAs a customer may use, per-customer credentials).
