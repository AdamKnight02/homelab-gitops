# Cert-Worker: Certificate Discovery Service

## Phase 5 — Cryptographic Inventory

The Cert-Worker discovers certificates from multiple sources and populates the inventory database.

### Discovery Sources

1. **EJBCA** — Queries EJBCA REST API for issued certificates
2. **OpenBao PKI** — Discovers certificates from OpenBao PKI engine
3. **Kubernetes Secrets** — Finds TLS secrets across all namespaces
4. **TLS Scanning** — Scans endpoints to discover certificates
5. **Manual Import** — Future: API for importing certificates

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   EJBCA         │     │   OpenBao PKI   │     │   K8s Secrets   │
│   REST API      │     │   API           │     │   API           │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │      Cert-Worker          │
                    │  ┌─────────────────────┐  │
                    │  │ CertificateDiscovery│  │
                    │  │ (Base Class)        │  │
                    │  └─────────────────────┘  │
                    │           │               │
                    │  ┌────────┴────────┐      │
                    │  │ EJBCADiscovery  │      │
                    │  │ OpenBaoDiscovery│      │
                    │  │ K8sDiscovery    │      │
                    │  │ TLSScanDiscovery│      │
                    │  └─────────────────┘      │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   PostgreSQL Database     │
                    │   (Certificate Inventory) │
                    └───────────────────────────┘
```

### Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://certapi:...` |
| `EJBCA_URL` | EJBCA REST API URL | `https://ejbca-ejbca-ce:8443/ejbca` |
| `EJBCA_USERNAME` | EJBCA admin username | `""` |
| `EJBCA_PASSWORD` | EJBCA admin password | `""` |
| `OPENBAO_URL` | OpenBao API URL | `https://openbao:8200` |
| `OPENBAO_TOKEN` | OpenBao token | `""` |
| `KUBERNETES_API_URL` | Kubernetes API URL | `https://kubernetes.default.svc` |
| `TLS_SCAN_TARGETS` | Comma-separated host:port list | `""` |

### Schedule

By default, discovery runs every 6 hours. This is configurable in the discovery_jobs table.

### Extending Discovery

To add a new source:

1. Create a new class inheriting from `CertificateDiscovery`
2. Implement the `discover()` method
3. Add it to the sources list in `run_discovery()`

Example:
```python
class SmallstepDiscovery(CertificateDiscovery):
    def __init__(self):
        super().__init__(DiscoverySource.SMALLSTEP)
    
    def discover(self) -> List[CertificateRecord]:
        # Implement Smallstep CA discovery
        pass
```
