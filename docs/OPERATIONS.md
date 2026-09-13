# Machine Identity Platform Operations Guide

## Daily Operations

### Check Certificate Health

```bash
# Check expiring certificates
kubectl exec -n pki deploy/cert-api -- curl -s http://localhost:8000/api/v1/certificates/expiring?days=30

# Check system stats
kubectl exec -n pki deploy/cert-api -- curl -s http://localhost:8000/api/v1/stats
```

### Monitor Alerts

- CertificateExpiringSoon: Warning at 30 days
- CertificateExpired: Critical immediately
- WeakCertificateKey: Warning for < 2048 bit keys
- CertAPIDown: Critical for API availability

### Review Discovery Jobs

```bash
# Check discovery job status
kubectl get cronjobs -n pki

# View recent discovery runs
kubectl get jobs -n pki | grep discovery
```

## Weekly Operations

### Run Failure Tests

```bash
# Trigger failure test job
kubectl create job -n pki --from=cronjob/cert-failure-test-scheduled failure-test-manual-$(date +%s)
```

### Review PQC Readiness

```bash
# Check PQC scan results
kubectl logs -n pki job/pqc-readiness-scan
```

### Backup Verification

```bash
# List backups
kubectl exec -n pki deploy/cert-worker -- ls -la /backup/

# Verify backup integrity
kubectl create job -n pki --from=cronjob/cert-inventory-backup backup-verify-$(date +%s)
```

## Monthly Operations

### Policy Review

```bash
# Check policy violations
kubectl logs -n pki job/cert-policy-check
```

### Certificate Renewal Review

```bash
# Check renewal success rate
kubectl logs -n pki cronjob/cert-renewal-check
```

### Security Audit

```bash
# Check network policies
kubectl get networkpolicies -n pki

# Review RBAC
kubectl get rolebindings -n pki
```

## Troubleshooting

### cert-api not responding

```bash
# Check pod status
kubectl get pods -n pki -l app=cert-api

# Check logs
kubectl logs -n pki -l app=cert-api --tail=100

# Check database connectivity
kubectl exec -n pki deploy/cert-api -- pg_isready -h pki-database -U certapi
```

### Discovery failing

```bash
# Check discovery job logs
kubectl logs -n pki job/crypto-inventory-scan

# Verify CA connectivity
kubectl exec -n pki deploy/cert-worker -- curl -k https://ejbca-ejbca-ce:8443
kubectl exec -n pki deploy/cert-worker -- curl -k https://openbao:8200/v1/sys/health
```

### Argo CD OutOfSync

```bash
# Check application status
kubectl get applications -n argocd

# Force sync
argocd app sync pki --prune
```

## Emergency Procedures

### Restore from Backup

```bash
# Create restore job
kubectl apply -f apps/pki/cert-worker/job-restore.yaml

# Verify restoration
kubectl logs -n pki job/cert-inventory-restore
```

### Manual Certificate Revocation

```bash
# Revoke via API
curl -X POST http://cert-api:8000/api/v1/certificates/{serial}/revoke \
  -d '{"reason": "keyCompromise"}'
```

### OpenBao Unseal

```bash
# Check seal status
kubectl exec -n openbao openbao-0 -- bao status -tls-skip-verify

# Unseal with keys
kubectl exec -n openbao openbao-0 -- bao operator unseal -tls-skip-verify <key>
```

## Contact

For issues or questions, check:
- Argo CD UI: https://192.168.122.74:30721
- Grafana: https://192.168.122.74:32059
- GitHub Issues: https://github.com/AdamKnight02/homelab-gitops/issues
