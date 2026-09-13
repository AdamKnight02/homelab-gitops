# State Management UI — `gitops/state-ui` + `gitops/state-api`

A **safe** operations interface for Terraform state across the PKI platform's
multi-cloud expansion (Azure / AWS / Alibaba). It shows **sanitized metadata
and operational health — never raw state**.

## Architecture

```
┌──────────────┐   /api/v1 (proxied)   ┌──────────────┐   workload identity   ┌─────────────────┐
│   state-ui   │ ───────────────────▶  │   state-api  │ ───────────────────▶  │  Cloud backends │
│  (React SPA, │   bearer token        │  (FastAPI,   │  (IRSA / WI / RRSA)   │  S3+DynamoDB    │
│   nginx)     │ ◀───────────────────  │  sanitized)  │                       │  Blob+Lease     │
└──────────────┘   sanitized JSON      └──────┬───────┘                       │  OSS+TableStore │
       ▲                                      │ /metrics                      └─────────────────┘
       │ internal ingress + SSO proxy         ▼
       │ (opt-in overlay)               Prometheus
```

- **State identity:** `provider/customer/environment/component`
  (e.g. `azure/default/lab/core`), components: `core`, `addons`, `monitoring`.
- **Registry-driven:** the API only serves states pre-registered in its
  ConfigMap. Callers cannot point it at arbitrary buckets/keys.
- **Provider adapter pattern:** `adapters.py` — `AzureBlobAdapter`,
  `AwsS3Adapter`, `AlibabaOssAdapter` behind a common interface
  (status / pull / lock / versions / backup).

## Security model (hard rules)

1. **No raw state, ever.** All state content passes through `sanitize.py`
   (deny-by-default allowlist: version, serial, lineage, terraform_version,
   resource *counts*, sanitized outputs). Sensitive outputs, private keys,
   JWTs, connection strings, and `password|secret|token`-shaped values are
   redacted server-side before anything leaves the API.
2. **Auth required on every endpoint** (OIDC bearer, K8s TokenReview
   fallback). No anonymous access. `/healthz`/`/livez` are the only
   unauthenticated routes and expose nothing.
3. **Read-only by default.** Roles:
   - `state-viewer` — list, detail, metadata, versions (default)
   - `state-operator` — + validate, drift-check, backup
   - `state-privileged` — + initiate migration, drift-report (pipeline SA)
4. **No `state rm` / `state push` / `force-unlock` from the UI.** Those are
   pipeline-only operations behind human approval. "Initiate Migration"
   creates an **audited approval request** — execution happens in the
   deployment pipeline (see `scripts/migration-orchestrator.sh`).
5. **Audit logging** — every read and action emits a structured JSON audit
   event with correlation ID, subject, identity, and outcome.
6. **Internal-only by default** — ClusterIP services, default-deny
   NetworkPolicies, no Ingress in base. The `overlays/internal-ingress`
   overlay adds an internal-class Ingress behind an SSO proxy, and only when
   explicitly enabled.

## API surface

| Method | Path | Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/states` | viewer | Inventory with health summary |
| GET | `/api/v1/states/{p}/{c}/{e}/{comp}` | viewer | Detail: backend, health, lock, drift, pipeline |
| GET | `…/metadata` | viewer | Sanitized version/serial/resources/outputs |
| GET | `…/versions` | viewer | Backend version history |
| POST | `…/validate` | operator | Parse + integrity checks (read-only) |
| POST | `…/drift-check` | operator | Request drift detection (runs in pipeline) |
| POST | `…/drift-report` | privileged | Pipeline reports drift result |
| POST | `…/backup` | operator | Encrypted backup to `backups/` in same backend |
| POST | `…/migrate` | privileged | Create migration **approval request** |
| GET | `/api/v1/migrations` | viewer | List migration requests |
| GET | `/metrics` | viewer | Prometheus metrics |

## Metrics (safe, metadata-only)

`state_backend_reachable`, `state_locked`, `state_version`,
`state_resource_count`, `state_drift_detected`,
`state_last_operation_timestamp` — all labeled
`{provider, customer, environment, component}`.

## UI features

- Inventory grouped by provider / customer / environment / component, with
  health strip (healthy / locked / unreachable / missing) and free-text filter.
- Detail view: backend type + state key, current version, last update, lock
  status/holder, drift status, last pipeline run, tracked resource count.
- Tabs: Overview · **View Metadata** (sanitized outputs table, resources by
  type) · **Version History**.
- Safe actions: Validate State, Run Drift Detection, Backup State, View
  Version History, Initiate Migration (approval dialog), View Pipeline, View
  Metadata.
- Tokens held in `sessionStorage` only; CSP locked to `self`; no raw state
  fields exist in the UI data model at all.

## Build & deploy (GitOps)

```bash
# Build images (CI)
docker build -t registry.pki.platform.io/state-api:1.0.0 gitops/state-api
docker build -t registry.pki.platform.io/state-ui:1.0.0  gitops/state-ui

# Deploy via Argo CD (internal-only base)
kubectl apply -f gitops/state-api/argocd/application.yaml
kubectl apply -f gitops/state-ui/argocd/application.yaml
```

- **Provider identity overlays:** `state-api/overlays/{azure,aws,alibaba}`
  annotate the ServiceAccount for Workload Identity / IRSA / RRSA. Cloud IAM
  roles must grant read on state objects + lock tables, and `PutObject` on
  `backups/*` only.
- **Internal exposure (opt-in):** switch the state-ui Application path to
  `gitops/state-ui/overlays/internal-ingress` after setting the internal
  ingress class, SSO proxy auth-url/signin, and TLS secret.
- **Registry:** edit `state-api/base/configmap-registry.yaml` to register
  states per customer/environment/component. Never put credentials here —
  coordinates only.

## Files

```
state-api/
  Dockerfile                  # non-root python:3.12-slim
  src/app/
    main.py                   # FastAPI routes, caches, metrics refresher
    models.py                 # StateIdentity (provider/customer/env/component)
    adapters.py               # Azure/AWS/Alibaba backend adapters
    sanitize.py               # redaction — the security core
    auth.py                   # OIDC + TokenReview, 3 roles
    audit.py                  # structured audit events
    metrics.py                # 6 required Prometheus series
    registry.py               # config-driven state registry
  base/                       # namespace, SA, RBAC(TokenReview only), registry
                              # ConfigMap, Deployment (hardened), ClusterIP
                              # Service, default-deny NetworkPolicy,
                              # ServiceMonitor
  overlays/{azure,aws,alibaba}/  # workload identity SA patches
  argocd/application.yaml
state-ui/
  Dockerfile                  # vite build → nginx non-root on 8080
  nginx.conf                  # CSP/security headers, /api proxy to state-api
  src/                        # React SPA (list, detail, login, styles)
  base/                       # Deployment (hardened), ClusterIP Service,
                              # default-deny NetworkPolicy
  overlays/internal-ingress/  # opt-in internal Ingress + SSO proxy
  argocd/application.yaml
```
