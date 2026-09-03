# Certificate Lifecycle Design

> **Status**: Cloud-neutral certificate management architecture

## Certificate Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Client     │────▶│  cert-api    │────▶│  AuthN/AuthZ │
│ Application  │     │   (REST)     │     │  (SPIFFE)    │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   EJBCA      │◀────│  CA Abstraction│◀───│ cert-worker  │
│   (PKI)      │     │    Layer       │     │  (Queue)     │
└──────┬───────┘     └──────────────┘     └──────┬───────┘
       │                                          │
       ▼                                          ▼
┌──────────────┐                         ┌──────────────┐
│  PostgreSQL  │                         │   RabbitMQ   │
│  (Database)  │                         │   (Queue)    │
└──────────────┘                         └──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Inventory   │     │ Audit Trail  │     │   OpenBao    │
│   (PVC)      │     │   (Logs)     │     │  (Secrets)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Lifecycle Stages

### 1. Request

```bash
# Client requests certificate
curl -X POST https://cert-api:8000/v1/certificates \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "CN=app.pki-cloudlab.local",
    "sans": ["app.pki-cloudlab.local", "10.0.0.1"],
    "profile": "tls-server",
    "validity": "720h"
  }'
```

### 2. Authentication

```python
# cert-api validates SPIFFE ID
from spiffe import WorkloadApiClient

client = WorkloadApiClient()
svid = client.fetch_x509_svid()

# Verify caller's SPIFFE ID
if svid.spiffe_id not in allowed_ids:
    raise Unauthorized("Invalid identity")
```

### 3. Authorization

```yaml
# Policy configuration
policies:
  - spiffe_id: "spiffe://pki-cloudlab.local/ns/pki/sa/cert-api"
    allowed_profiles:
      - tls-server
      - tls-client
    max_validity: 720h
    allowed_sans:
      - "*.pki-cloudlab.local"
```

### 4. Queue

```python
# cert-api publishes to RabbitMQ
import pika

connection = pika.BlockingConnection(pika.ConnectionParameters('rabbitmq'))
channel = connection.channel()
channel.queue_declare(queue='certificate_requests')

channel.basic_publish(
    exchange='',
    routing_key='certificate_requests',
    body=json.dumps(request)
)
```

### 5. Processing

```python
# cert-worker consumes from queue
channel.basic_consume(
    queue='certificate_requests',
    on_message_callback=process_request
)

def process_request(ch, method, properties, body):
    request = json.loads(body)
    
    # Call CA abstraction layer
    cert = ca_abstraction.issue(request)
    
    # Store in inventory
    inventory.store(cert)
    
    # Log audit event
    audit.log('certificate_issued', cert)
    
    # Return certificate
    ch.basic_ack(delivery_tag=method.delivery_tag)
```

### 6. CA Abstraction

```python
# CA abstraction layer
class CAAbstraction:
    def issue(self, request):
        # Determine CA (EJBCA, OpenBao, etc.)
        ca = self.select_ca(request)
        
        # Issue certificate
        if ca == 'ejbca':
            return ejbca_client.issue(request)
        elif ca == 'openbao':
            return openbao_client.issue(request)
```

### 7. Storage

```sql
-- Certificate inventory schema
CREATE TABLE certificates (
    id UUID PRIMARY KEY,
    serial_number VARCHAR(255) UNIQUE,
    subject VARCHAR(500),
    issuer VARCHAR(500),
    not_before TIMESTAMP,
    not_after TIMESTAMP,
    profile VARCHAR(100),
    status VARCHAR(20), -- active, revoked, expired
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 8. Audit

```json
{
  "event_type": "certificate_issued",
  "timestamp": "2024-01-15T10:30:00Z",
  "certificate_id": "550e8400-e29b-41d4-a716-446655440000",
  "serial_number": "123456789",
  "subject": "CN=app.pki-cloudlab.local",
  "issuer": "CN=pki-cloudlab-intermediate-ca",
  "requested_by": "spiffe://pki-cloudlab.local/ns/pki/sa/cert-api",
  "validity": "720h",
  "profile": "tls-server"
}
```

## Renewal

### Automatic Renewal

```yaml
# cert-manager Certificate resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-certificate
spec:
  secretName: app-tls
  issuerRef:
    name: pki-issuer
    kind: ClusterIssuer
  dnsNames:
    - app.pki-cloudlab.local
  renewBefore: 168h  # 7 days before expiry
```

### Renewal Workflow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   cert-api  │────▶│  cert-worker │────▶│   EJBCA    │
│  (monitor)  │     │  (renewal)   │     │  (reissue) │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                          │
       ▼                                          ▼
┌─────────────┐                         ┌─────────────┐
│  Inventory  │◀────────────────────────│  New Cert   │
│  (update)   │                         │  (store)    │
└─────────────┘                         └─────────────┘
```

## Revocation

### CRL

```bash
# Generate CRL
ejbca.sh ca getcrl --caname PKI-CloudLab-SubCA --crlfile pki-cloudlab.crl

# Publish CRL
kubectl create configmap crl --from-file=pki-cloudlab.crl
```

### OCSP

```bash
# Configure OCSP responder
ejbca.sh ocsp --configure --caname PKI-CloudLab-SubCA

# Query OCSP
openssl ocsp -issuer issuer.pem -cert cert.pem \
  -url http://ocsp.pki-cloudlab.local \
  -VAfile ocsp-signer.pem
```

## Expiration

### Monitoring

```yaml
# Prometheus alert
- alert: CertificateExpiringSoon
  expr: |
    (
      certmanager_certificate_expiration_timestamp_seconds - time()
    ) / 86400 < 7
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "Certificate expiring in less than 7 days"
```

### Cleanup

```sql
-- Archive expired certificates
INSERT INTO certificates_archive
SELECT * FROM certificates
WHERE not_after < NOW() - INTERVAL '30 days';

DELETE FROM certificates
WHERE not_after < NOW() - INTERVAL '30 days';
```

## Cloud Portability

| Component | Homelab | Azure | AWS |
|-----------|---------|-------|-----|
| cert-api | Deployment | Deployment | Deployment |
| cert-worker | Deployment | Deployment | Deployment |
| RabbitMQ | StatefulSet | StatefulSet | StatefulSet |
| EJBCA | StatefulSet | StatefulSet | StatefulSet |
| PostgreSQL | StatefulSet | StatefulSet | StatefulSet |
| Inventory | PVC | PVC | EBS |
| Audit | Logs | Logs | CloudWatch |
