# Phase 5 & 6 Implementation Summary

## Phase 5 — Cryptographic Inventory Service

### Components Created

1. **Database** (`apps/pki/database/`)
   - PostgreSQL deployment with persistent storage
   - Schema with certificates, discovery_jobs, discovery_runs, audit_log tables
   - Views for common queries (expiring soon, weak keys, PQC vulnerable)
   - Indexes optimized for certificate queries

2. **Cert-API** (`apps/pki/cert-api/`)
   - FastAPI REST service
   - Endpoints:
     - `/health` — Service health
     - `/certificates` — Query with filters
     - `/certificates/{id}` — Get by ID
     - `/certificates/serial/{serial}` — Get by serial
     - `/stats` — Inventory statistics
     - `/queries/expiring-soon` — Expiring certificates
     - `/queries/weak-keys` — Weak RSA keys
     - `/queries/deprecated-algorithms` — Deprecated signatures
     - `/queries/unknown-owners` — Missing owners
     - `/queries/stale` — Not observed recently
     - `/queries/pqc-vulnerable` — Quantum-vulnerable certs

3. **Cert-Worker** (`apps/pki/cert-worker/`)
   - Background discovery service
   - Sources:
     - EJBCA REST API
     - OpenBao PKI API
     - Kubernetes TLS secrets
     - TLS endpoint scanning
   - Runs every 6 hours
   - Parses certificates and extracts inventory fields

### Data Model

```python
CertificateRecord:
  - Identity: hostname, application, service, environment, owner
  - Certificate: subject, SANs, serial, issuer, issuing_ca
  - Crypto: key_algorithm, key_size, signature_algorithm
  - Validity: not_before, not_after, days_remaining
  - Status: status, revocation_status, revocation_date
  - Source: source_ca, certificate_profile, discovery_method, last_seen
  - PQC: pqc_readiness, crypto_policy_compliant
```

### Why Cryptographic Inventory is Critical

**Crypto-Agility**: When vulnerabilities are discovered (SHA-1, RSA-512), you need to find affected certificates instantly. Without inventory, you're grepping across namespaces hoping not to miss anything.

**PQC Migration**: Quantum computers will break RSA and ECC. You need to know:
- Which certificates use vulnerable algorithms
- Their expiration dates
- Which applications/services use them
- Priority order (production > staging, external > internal)

**Compliance**: PCI-DSS, HIPAA, SOC 2 require knowing where certificates are and ensuring they meet minimum standards.

**Incident Response**: When a CA is compromised (DigiNotar), find all certificates from that CA immediately.

---

## Phase 6 — Multi-CA Abstraction Layer

### Components Created

1. **Provider Interface** (`apps/pki/ca-service/src/provider_interface.py`)
   - Abstract base class for all CA providers
   - Methods: issue, revoke, get, get_ca_chain, get_status, renew
   - Capability checking and request validation

2. **EJBCA Provider** (`apps/pki/ca-service/src/providers/ejbca.py`)
   - Full implementation for EJBCA CE
   - Supports: profiles, end entities, CRL, OCSP, renewal
   - Best for: Long-lived certificates, complex profiles

3. **OpenBao Provider** (`apps/pki/ca-service/src/providers/openbao.py`)
   - Implementation for OpenBao PKI
   - Supports: roles, short-lived certs, workload identity
   - Best for: Service mesh, automated infrastructure
   - Limitations: No true renewal (issue new instead)

4. **Certificate Service** (`apps/pki/ca-service/src/certificate_service.py`)
   - Orchestrates operations across providers
   - Provider selection strategies:
     - Priority (lowest number wins)
     - Capability (supports requested operation)
     - Health check (healthiest provider)
     - Round-robin (rotate between providers)
     - Explicit (caller specifies)

5. **CA Service API** (`apps/pki/ca-service/src/main.py`)
   - FastAPI REST service
   - Endpoints:
     - `/providers` — List all providers and capabilities
     - `/providers/{name}/capabilities` — Get provider capabilities
     - `/providers/{name}/status` — Check provider health
     - `/providers/{name}/check/{operation}` — Capability check
     - `/certificates/issue` — Issue certificate
     - `/certificates/revoke` — Revoke certificate
     - `/certificates/{serial}` — Get certificate
     - `/ca-chain` — Get CA chain

### Capability Model

```
Provider: EJBCA
Supports:
  - issuance ✅
  - revocation ✅
  - certificate lookup ✅
  - certificate profiles ✅
  - end entity profiles ✅
  - CRLs ✅
  - OCSP ✅
  - renewal ✅
  - SCEP ✅
  - EST ✅
Does NOT support:
  - short-lived certificates (minutes/hours)
  - ACME

Provider: OpenBao PKI
Supports:
  - issuance ✅
  - revocation ✅
  - short-lived certificates ✅
  - role-based issuance ✅
  - CRLs ✅
  - workload identity ✅
Does NOT support:
  - certificate profiles (uses roles instead)
  - end entity profiles
  - OCSP (limited)
  - true renewal (issue new instead)
  - SCEP/EST

Provider: Smallstep CA
Supports:
  - issuance ✅
  - revocation ✅
  - ACME ✅
  - short-lived certificates ✅
  - workload-oriented enrollment ✅
  - SSH certificates ✅
Does NOT support:
  - certificate profiles
  - end entity profiles
  - SCEP
```

### Design Principles

1. **Normalize, Don't Homogenize**: Different CAs have different capabilities. Don't pretend they're identical. Expose capabilities and let applications decide.

2. **Fail Gracefully**: If one provider fails, try another. Return clear errors with alternatives.

3. **Capability Discovery First**: Always check capabilities before attempting operations.

4. **Preserve Provider-Specific Features**: Don't prevent using EJBCA profiles or OpenBao roles. Expose as optional parameters.

5. **Provider-Native Configuration**: Each provider has its own config. Don't force one-size-fits-all.

---

## Integration with GitOps

All components are added to:
- `apps/pki/kustomization.yaml` — Includes database, cert-api, cert-worker, ca-service
- ArgoCD will auto-sync when pushed to GitHub

## Next Steps

1. Build Docker images for cert-api, cert-worker, ca-service
2. Push to container registry
3. Update image references in deployment YAMLs
4. Configure credentials (Kubernetes secrets for CA auth)
5. Deploy and test

## Phase 7 Preview — HSM and Key Protection

Next phase will cover:
- SoftHVM setup for lab environment
- PKCS#11 architecture (slots, tokens, objects, sessions)
- Key protection concepts (extractable vs non-extractable)
- CA signing key migration to HSM
- FIPS 140-2/140-3 concepts
- Why application -> PKCS#11 -> HSM -> signing is different from filesystem keys
