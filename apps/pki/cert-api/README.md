# Cert-API: Cryptographic Inventory REST API

## Phase 5 — Cryptographic Inventory

The Cert-API provides a RESTful interface for querying and managing the cryptographic certificate inventory.

### Features

- **Certificate Queries**: Search by hostname, application, environment, owner, status, source CA
- **Time-based Filters**: Find certificates expiring within N days
- **Crypto Policy Filters**: Identify weak keys, deprecated algorithms, PQC vulnerabilities
- **Statistics Dashboard**: Aggregate metrics about certificate landscape
- **Health & Metrics**: Prometheus-compatible metrics endpoint

### API Endpoints

#### Health & Metrics
- `GET /health` — Service health check
- `GET /metrics` — Prometheus metrics

#### Certificate Management
- `GET /certificates` — List certificates with filters
- `GET /certificates/{id}` — Get certificate by ID
- `GET /certificates/serial/{serial}` — Get certificate by serial number

#### Statistics
- `GET /stats` — Inventory statistics

#### Pre-built Queries
- `GET /queries/expiring-soon?days=30` — Certificates expiring within N days
- `GET /queries/weak-keys?min_rsa_size=2048` — Weak RSA keys
- `GET /queries/deprecated-algorithms` — Deprecated signature algorithms
- `GET /queries/unknown-owners` — Certificates with no owner
- `GET /queries/stale?days=7` — Certificates not observed recently
- `GET /queries/pqc-vulnerable` — Quantum-vulnerable certificates

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://certapi:certinventory-password-change-me@pki-database:5432/certinventory` |

### Why Cryptographic Inventory Matters

**Crypto-Agility**: When a vulnerability is discovered (e.g., SHA-1 collision, RSA key factoring), you need to know exactly which certificates are affected, where they are, and who owns them. Without an inventory, you're doing `grep` across hundreds of namespaces and hoping you don't miss anything.

**PQC Migration**: Quantum computers will break RSA and ECC. NIST is standardizing post-quantum algorithms. When you need to migrate:
- You need to know which certificates use vulnerable algorithms
- You need to know their expiration dates (can't migrate expired certs)
- You need to know the applications/services using them
- You need to prioritize by risk (production > staging, external > internal)

**Compliance**: Regulations like PCI-DSS, HIPAA, and SOC 2 require knowing where your certificates are and ensuring they meet minimum cryptographic standards.

**Incident Response**: When a CA is compromised (remember DigiNotar?), you need to find all certificates from that CA immediately.
