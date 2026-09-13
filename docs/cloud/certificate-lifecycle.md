# Certificate Lifecycle Management

## Overview

This document defines the complete certificate lifecycle for the Machine Identity Platform, covering request, issuance, renewal, revocation, expiration, inventory, and audit.

The architecture is designed to be **cloud-neutral** — the same flows operate identically across local homelab, Azure, and AWS environments.

---

## Certificate Lifecycle States

```
┌──────────┐    request     ┌──────────┐    validate    ┌──────────┐
│  START   │───────────────►│ PENDING  │───────────────►│ APPROVED │
└──────────┘                └──────────┘                └────┬─────┘
                                                             │
                                    ┌────────────────────────┘
                                    │ issue
                                    ▼
┌──────────┐    expire     ┌──────────┐    revoke     ┌──────────┐
│ EXPIRED  │◄──────────────│ ISSUED   │──────────────►│ REVOKED  │
└──────────┘                └────┬─────┘               └──────────┘
                                 │
                                 │ renew
                                 ▼
                          ┌──────────┐
                          │ RENEWED  │
                          │ (new     │
                          │  cert)   │
                          └──────────┘
```

| State | Description | Transitions |
|-------|-------------|-------------|
| **START** | Initial state, no certificate exists | → PENDING (on request) |
| **PENDING** | Request received, awaiting validation | → APPROVED, → REJECTED |
| **APPROVED** | Request validated, ready for issuance | → ISSUED |
| **ISSUED** | Certificate active and valid | → RENEWED, → REVOKED, → EXPIRED |
| **RENEWED** | New certificate issued before expiry | → ISSUED (new cert) |
| **REVOKED** | Certificate explicitly invalidated | → (terminal) |
| **EXPIRED** | Certificate passed NotAfter date | → (terminal) |
| **REJECTED** | Request denied | → (terminal) |

---

## Lifecycle Flows

### 1. Certificate Request Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────►│  cert-api   │────►│   AuthN     │────►│   AuthZ     │
│  (mTLS)     │     │  (FastAPI)  │     │ (SPIFFE/    │     │ (OpenBao    │
│             │     │             │     │  K8s SA)    │     │  policy)    │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                    │
                                                                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  RabbitMQ   │◄────│  Validate   │◄────│   Policy    │◄────│  Authorize  │
│  (Queue)    │     │  (Schema)   │     │  (Rules)    │     │  (Permit)   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Steps:**

1. **Client Request**: Client presents SPIFFE ID via mTLS to cert-api
2. **Authentication**: cert-api validates client SPIFFE ID with SPIRE Agent
3. **Authorization**: cert-api checks OpenBao policy for certificate issuance permission
4. **Policy Validation**: Request validated against certificate profile rules
5. **Schema Validation**: Request structure validated (CSR format, SANs, key type)
6. **Queue Publication**: Valid request published to RabbitMQ `cert.request` exchange

**API Request Example:**
```json
POST /api/v1/certificates
Content-Type: application/json
X-SPIFFE-ID: spiffe://homelab.local/ns/pki/sa/cert-api

{
  "subject": {
    "common_name": "web-server.example.com",
    "organization": "Homelab",
    "country": "US"
  },
  "sans": {
    "dns": ["web-server.example.com", "www.example.com"],
    "ip": ["10.43.123.45"]
  },
  "profile": "tls-server",
  "validity_days": 90,
  "key_type": "ec-p256",
  "csr": "-----BEGIN CERTIFICATE REQUEST-----\n..."
}
```

**RabbitMQ Message:**
```json
{
  "message_id": "cert-req-550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-09-02T23:52:00Z",
  "requester_spiffe_id": "spiffe://homelab.local/ns/apps/sa/web-server",
  "request": {
    "subject": { "common_name": "web-server.example.com" },
    "sans": { "dns": ["web-server.example.com"] },
    "profile": "tls-server",
    "validity_days": 90
  },
  "priority": "normal",
  "ttl": 3600
}
```

---

### 2. Certificate Issuance Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  RabbitMQ   │────►│ cert-worker │────►│ ca-service  │────►│   EJBCA     │
│  (Queue)    │     │  (Consumer) │     │ (Abstraction)│    │   (CA)      │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                    │
                    ┌───────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Audit     │◄────│  Inventory  │◄────│  OpenBao    │◄────│ Certificate │
│   Event     │     │  (Store)    │     │  (Secrets)  │     │  (PEM)      │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Steps:**

1. **Consume Request**: cert-worker consumes message from `cert.issue` queue
2. **Policy Check**: Verify requester authorization with OpenBao
3. **CA Selection**: ca-service selects appropriate CA (LabIssuingCA for TLS)
4. **Certificate Profile**: Apply profile rules (key size, validity, extensions)
5. **EJBCA Enrollment**: Submit to EJBCA via EST/REST API
6. **Certificate Retrieval**: Receive issued certificate from EJBCA
7. **Secret Storage**: Store private key in OpenBao KV (if server-generated)
8. **Inventory Record**: Store certificate metadata in PKI PostgreSQL
9. **Audit Event**: Log issuance event to audit trail
10. **Notification**: Publish completion to RabbitMQ `cert.issued` exchange

**EJBCA EST Enrollment:**
```bash
# EST simpleenroll
curl -X POST https://ejbca.ejbca.svc/ejbca/.well-known/est/cacerts/simpleenroll \
  --cacert ca.crt \
  --cert client.crt \
  --key client.key \
  -H "Content-Type: application/pkcs10" \
  --data-binary @request.csr
```

**Inventory Record:**
```sql
INSERT INTO certificates (
  serial_number,
  subject_dn,
  issuer_dn,
  not_before,
  not_after,
  profile,
  ca_name,
  spiffe_id,
  status,
  pem_certificate,
  issued_at,
  issued_by
) VALUES (
  '045c7b2a1f9e3d8c7a4e2b5f1c8d3e7a',
  'CN=web-server.example.com,O=Homelab,C=US',
  'CN=LabIssuingCA',
  '2026-09-02T00:00:00Z',
  '2026-12-01T00:00:00Z',
  'tls-server',
  'LabIssuingCA',
  'spiffe://homelab.local/ns/apps/sa/web-server',
  'ISSUED',
  '-----BEGIN CERTIFICATE-----\n...',
  '2026-09-02T23:52:00Z',
  'cert-worker-7d9f4b8c5-x2k4m'
);
```

**Audit Event:**
```json
{
  "event_type": "CERTIFICATE_ISSUED",
  "timestamp": "2026-09-02T23:52:00Z",
  "severity": "INFO",
  "certificate_serial": "045c7b2a1f9e3d8c7a4e2b5f1c8d3e7a",
  "subject_dn": "CN=web-server.example.com",
  "issuer_dn": "CN=LabIssuingCA",
  "requester_spiffe_id": "spiffe://homelab.local/ns/apps/sa/web-server",
  "worker_pod": "cert-worker-7d9f4b8c5-x2k4m",
  "profile": "tls-server",
  "validity_days": 90,
  "source_ip": "10.42.0.123",
  "request_id": "cert-req-550e8400-e29b-41d4-a716-446655440000"
}
```

---

### 3. Certificate Renewal Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Inventory  │────►│  Scheduler  │────►│  cert-api   │────►│  RabbitMQ   │
│  (Check)    │     │  (Cron)     │     │  (Request)  │     │  (Queue)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Renewal Triggers:**

| Trigger | Description | Action |
|---------|-------------|--------|
| **Time-based** | Certificate expires in < 30 days | Auto-renewal initiated |
| **Manual** | Admin requests renewal | Immediate renewal |
| **Event-driven** | Key compromise detected | Emergency renewal |
| **Policy** | Profile maximum lifetime reached | Forced renewal |

**Renewal Process:**

1. **Inventory Scan**: Daily scan for certificates expiring within renewal window
2. **Renewal Request**: cert-api creates renewal request with existing certificate reference
3. **Queue Publication**: Published to `cert.renew` queue
4. **Worker Processing**: cert-worker processes with `simplereenroll` (EST) or new CSR
5. **New Certificate**: New certificate issued with same or new key pair
6. **Inventory Update**: Old certificate marked RENEWED, new certificate ISSUED
7. **Secret Rotation**: If private key rotated, update OpenBao KV
8. **Notification**: Notify consuming workloads of new certificate

**Renewal Policy:**
```yaml
renewal_policy:
  auto_renew: true
  renewal_window_days: 30
  max_lifetime_days: 90
  key_rotation:
    on_renewal: optional
    forced_every_n_renewals: 3
  notification:
    before_expiry_days: [30, 14, 7, 1]
    channels: [webhook, email, slack]
```

---

### 4. Certificate Revocation Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Admin /   │────►│  cert-api   │────►│   AuthZ     │────►│  RabbitMQ   │
│   Event     │     │  (Request)  │     │  (Policy)   │     │  (Queue)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Audit     │◄────│  Inventory  │◄────│   EJBCA     │◄────│ cert-worker │
│   Event     │     │  (Update)   │     │  (Revoke)   │     │  (Process)  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
                                                             ┌─────────────┐
                                                             │   OCSP /    │
                                                             │    CRL      │
                                                             │  (Publish)  │
                                                             └─────────────┘
```

**Revocation Reasons:**

| Reason Code | Name | When Used |
|-------------|------|-----------|
| 0 | unspecified | Default |
| 1 | keyCompromise | Private key leaked |
| 2 | cACompromise | CA key compromised |
| 3 | affiliationChanged | Organization change |
| 4 | superseded | Replaced by new cert |
| 5 | cessationOfOperation | Service decommissioned |
| 6 | certificateHold | Temporary suspension |

**Revocation Process:**

1. **Revocation Request**: Admin API call or automated event
2. **Authorization**: Verify requester has revocation permission
3. **Queue Publication**: Published to `cert.revoke` queue
4. **EJBCA Revocation**: cert-worker calls EJBCA revocation API
5. **CRL Update**: EJBCA regenerates CRL with revoked serial
6. **OCSP Update**: OCSP responder updated
7. **Inventory Update**: Certificate status changed to REVOKED
8. **Audit Event**: Log revocation with reason
9. **Notification**: Notify certificate consumers

**Revocation API:**
```json
POST /api/v1/certificates/{serial}/revoke
Content-Type: application/json

{
  "reason": "keyCompromise",
  "reason_description": "Private key exposed in log file",
  "revoked_by": "admin@homelab.local",
  "immediate": true
}
```

**EJBCA Revocation:**
```bash
# Via EJBCA CLI
ejbca.sh ra revokecert \
  --caname LabIssuingCA \
  --serial 045c7b2a1f9e3d8c7a4e2b5f1c8d3e7a \
  --reason KEYCOMPROMISE
```

---

### 5. Certificate Expiration Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Inventory  │────►│  Scheduler  │────►│  Notifier   │────►│   Admin     │
│  (Check)    │     │  (Daily)    │     │  (Alerts)   │     │  (Action)   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
       │
       │ not renewed
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Inventory  │────►│   Audit     │────►│   Cleanup   │
│  (Expire)   │     │   Event     │     │  (Archive)  │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Expiration Handling:**

1. **Daily Check**: Inventory scan for `NotAfter < now()`
2. **Auto-Renewal Attempt**: If auto-renew enabled, attempt renewal
3. **Notification**: Alert if not renewed:
   - 30 days: Warning
   - 14 days: Urgent
   - 7 days: Critical
   - 1 day: Emergency
   - Expired: Final notice
4. **Status Update**: Change status to EXPIRED
5. **Audit Log**: Log expiration event
6. **Archive**: Move to archive table after grace period
7. **Cleanup**: Remove from active monitoring after retention period

---

### 6. Audit Trail Flow

Every certificate lifecycle event generates an audit record:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Event     │────►│  Audit      │────►│  OpenBao    │────►│  PostgreSQL │
│  (Any Op)   │     │  Logger     │     │  (Sign)     │     │  (Store)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Audit Record Schema:**
```sql
CREATE TABLE audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(50) NOT NULL,  -- CERTIFICATE_ISSUED, REVOKED, etc.
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  severity VARCHAR(20) NOT NULL,     -- INFO, WARNING, ERROR, CRITICAL
  certificate_serial VARCHAR(64),
  subject_dn TEXT,
  issuer_dn TEXT,
  requester_spiffe_id VARCHAR(255),
  worker_pod VARCHAR(255),
  profile VARCHAR(50),
  source_ip INET,
  request_id UUID,
  details JSONB,
  signature BYTEA  -- Signed by audit signing key
);
```

**Event Types:**

| Event Type | Description | Severity |
|------------|-------------|----------|
| `CERTIFICATE_REQUESTED` | New certificate request received | INFO |
| `CERTIFICATE_ISSUED` | Certificate successfully issued | INFO |
| `CERTIFICATE_RENEWED` | Certificate renewed | INFO |
| `CERTIFICATE_REVOKED` | Certificate revoked | WARNING |
| `CERTIFICATE_EXPIRED` | Certificate passed expiry | WARNING |
| `CERTIFICATE_REJECTED` | Request rejected | WARNING |
| `AUDIT_LOG_SIGNED` | Audit log entry signed | INFO |
| `POLICY_VIOLATION` | Request violated policy | ERROR |
| `SYSTEM_ERROR` | Internal system error | ERROR |
| `SECURITY_ALERT` | Security-related event | CRITICAL |

---

## Certificate Inventory

### Inventory Schema

```sql
CREATE TABLE certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  serial_number VARCHAR(64) NOT NULL UNIQUE,
  subject_dn TEXT NOT NULL,
  issuer_dn TEXT NOT NULL,
  not_before TIMESTAMPTZ NOT NULL,
  not_after TIMESTAMPTZ NOT NULL,
  profile VARCHAR(50) NOT NULL,
  ca_name VARCHAR(50) NOT NULL,
  spiffe_id VARCHAR(255),
  status VARCHAR(20) NOT NULL,  -- ISSUED, RENEWED, REVOKED, EXPIRED
  revocation_reason VARCHAR(20),
  revoked_at TIMESTAMPTZ,
  pem_certificate TEXT NOT NULL,
  pem_chain TEXT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  issued_by VARCHAR(255),
  renewed_from UUID REFERENCES certificates(id),
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cert_status ON certificates(status);
CREATE INDEX idx_cert_not_after ON certificates(not_after);
CREATE INDEX idx_cert_spiffe ON certificates(spiffe_id);
CREATE INDEX idx_cert_serial ON certificates(serial_number);
CREATE INDEX idx_cert_issued_at ON certificates(issued_at);
```

### Inventory Queries

```sql
-- Find certificates expiring in 30 days
SELECT * FROM certificates
WHERE status = 'ISSUED'
  AND not_after < NOW() + INTERVAL '30 days'
ORDER BY not_after;

-- Find all certificates for a SPIFFE ID
SELECT * FROM certificates
WHERE spiffe_id = 'spiffe://homelab.local/ns/apps/sa/web-server'
ORDER BY issued_at DESC;

-- Certificate count by profile
SELECT profile, status, COUNT(*) 
FROM certificates
GROUP BY profile, status;

-- Revocation history
SELECT * FROM certificates
WHERE status = 'REVOKED'
ORDER BY revoked_at DESC;
```

---

## CA Abstraction Layer

### Purpose

The CA Abstraction Layer (ca-service) provides a unified interface to multiple CA backends:

| Backend | Protocol | Use Case |
|---------|----------|----------|
| EJBCA | EST, REST, SOAP | Primary enterprise CA |
| cert-manager | Kubernetes CRD | Internal cluster TLS |
| OpenBao PKI | Vault API | Short-lived service certs |
| AWS PCA | AWS API | Cloud-native CA (future) |
| Azure Key Vault | Azure API | Cloud-native CA (future) |

### Abstraction Interface

```python
class CAProvider(ABC):
    @abstractmethod
    async def issue_certificate(self, request: CertRequest) -> Certificate:
        pass
    
    @abstractmethod
    async def renew_certificate(self, serial: str) -> Certificate:
        pass
    
    @abstractmethod
    async def revoke_certificate(self, serial: str, reason: str) -> None:
        pass
    
    @abstractmethod
    async def get_certificate(self, serial: str) -> Certificate:
        pass
    
    @abstractmethod
    async def get_crl(self) -> bytes:
        pass
    
    @abstractmethod
    async def check_ocsp(self, serial: str) -> OCSPResponse:
        pass
```

### Provider Selection Logic

```python
def select_provider(request: CertRequest) -> CAProvider:
    if request.profile == "tls-server" and request.validity_days <= 90:
        return EJBCAProvider()  # Primary CA
    elif request.profile == "internal-service":
        return OpenBaoPKIProvider()  # Short-lived
    elif request.profile == "cloud-native":
        return CloudProvider()  # AWS PCA / Azure KV
    else:
        raise UnsupportedProfileError(request.profile)
```

---

## mTLS Everywhere

### Service-to-Service Communication

All internal services communicate via mTLS with SPIFFE identity:

```
┌─────────────┐         mTLS          ┌─────────────┐
│  cert-api   │◄─────────────────────►│  RabbitMQ   │
│  (SPIFFE)   │  spiffe://.../cert-api│  (SPIFFE)   │
└─────────────┘                       └─────────────┘
       │                                    │
       │ mTLS                              │ mTLS
       ▼                                    ▼
┌─────────────┐                       ┌─────────────┐
│  OpenBao    │                       │ cert-worker │
│  (SPIFFE)   │                       │  (SPIFFE)   │
└─────────────┘                       └─────────────┘
                                              │
                                              │ mTLS
                                              ▼
                                       ┌─────────────┐
                                       │ ca-service  │
                                       │  (SPIFFE)   │
                                       └─────────────┘
```

### SPIFFE ID Patterns

| Workload | SPIFFE ID Pattern | Example |
|----------|-------------------|---------|
| cert-api | `spiffe://{trust_domain}/ns/pki/sa/cert-api` | `spiffe://homelab.local/ns/pki/sa/cert-api` |
| cert-worker | `spiffe://{trust_domain}/ns/pki/sa/cert-worker` | `spiffe://homelab.local/ns/pki/sa/cert-worker` |
| ca-service | `spiffe://{trust_domain}/ns/pki/sa/ca-service` | `spiffe://homelab.local/ns/pki/sa/ca-service` |
| EJBCA | `spiffe://{trust_domain}/ns/ejbca/sa/ejbca` | `spiffe://homelab.local/ns/ejbca/sa/ejbca` |
| OpenBao | `spiffe://{trust_domain}/ns/openbao/sa/openbao` | `spiffe://homelab.local/ns/openbao/sa/openbao` |
| RabbitMQ | `spiffe://{trust_domain}/ns/rabbitmq/sa/rabbitmq` | `spiffe://homelab.local/ns/rabbitmq/sa/rabbitmq` |
| Generic App | `spiffe://{trust_domain}/ns/{namespace}/sa/{sa}` | `spiffe://homelab.local/ns/apps/sa/web-server` |

---

## Operational Procedures

### Daily Operations

```bash
# Check certificate inventory health
curl https://cert-api.pki.svc:8000/api/v1/health

# List certificates expiring soon
curl https://cert-api.pki.svc:8000/api/v1/certificates?status=ISSUED&expiring_within=30d

# Check queue depth
curl https://rabbitmq.rabbitmq.svc:15672/api/queues/%2f/cert.issue

# View audit events
curl https://cert-api.pki.svc:8000/api/v1/audit?limit=100&severity=WARNING
```

### Emergency Procedures

**Key Compromise:**
```bash
# 1. Revoke all certificates signed by compromised key
curl -X POST https://cert-api.pki.svc:8000/api/v1/emergency/revoke-by-ca \
  -H "Content-Type: application/json" \
  -d '{"ca_name": "LabIssuingCA", "reason": "cACompromise"}'

# 2. Generate new CA key
curl -X POST https://cert-api.pki.svc:8000/api/v1/ca/LabIssuingCA/rollover

# 3. Re-issue critical certificates
curl -X POST https://cert-api.pki.svc:8000/api/v1/emergency/reissue \
  -H "Content-Type: application/json" \
  -d '{"priority": "critical", "ca_name": "LabIssuingCA-new"}'
```

**CA Unavailability:**
```bash
# 1. Check CA health
curl https://ca-service.pki.svc:8000/health

# 2. Queue status (requests should accumulate)
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues

# 3. Failover to backup CA (if configured)
curl -X POST https://cert-api.pki.svc:8000/api/v1/failover \
  -d '{"primary": "LabIssuingCA", "backup": "LabIssuingCA-backup"}'
```

---

## Metrics and Monitoring

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `certificates_issued_total` | Counter | Total certificates issued |
| `certificates_revoked_total` | Counter | Total certificates revoked |
| `certificates_expired_total` | Counter | Total certificates expired |
| `certificate_lifetime_days` | Histogram | Days until expiration |
| `queue_depth` | Gauge | Current queue depth |
| `issuance_latency_seconds` | Histogram | Time from request to issuance |
| `revocation_latency_seconds` | Histogram | Time from request to revocation |
| `audit_events_total` | Counter | Total audit events |
| `policy_violations_total` | Counter | Total policy violations |

### Prometheus Queries

```promql
# Certificates expiring in 30 days
count(certificate_lifetime_days < 30)

# Issuance rate
rate(certificates_issued_total[5m])

# Queue depth
queue_depth{queue="cert.issue"}

# Average issuance latency
histogram_quantile(0.95, issuance_latency_seconds)

# Revocation rate
rate(certificates_revoked_total[1h])
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-02 | PKI Platform Engineer | Initial certificate lifecycle documentation |
