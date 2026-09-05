# VM Configuration Framework

This directory contains baseline and role-specific configuration scripts for Windows and Linux VMs.

## Structure

```
configuration/
├── windows/
│   ├── baseline/           # Applied to all Windows VMs
│   │   ├── security-baseline.ps1
│   │   ├── tls-baseline.ps1
│   │   └── logging-baseline.ps1
│   ├── gateway/            # Gateway/reverse proxy role
│   │   └── gateway-config.ps1
│   ├── pki/                # PKI CA/OCSP/CRL role
│   │   └── pki-vm-config.ps1
│   ├── scep/               # SCEP enrollment role
│   │   └── scep-config.ps1
│   └── acme/               # ACME enrollment role
│       └── acme-config.ps1
├── linux/
│   ├── baseline/           # Applied to all Linux VMs
│   │   ├── security-baseline.sh
│   │   ├── tls-baseline.sh
│   │   └── logging-baseline.sh
│   ├── kubernetes/         # Kubernetes node role
│   │   └── k3s-node-config.sh
│   └── monitoring/         # Monitoring agent role
│       └── node-exporter-config.sh
└── schemas/                # JSON schemas for configuration metadata
    └── vm-config-schema.json
```

## Configuration Flow

```
Terraform
    |
    v
VM Created
    |
    v
Baseline Configuration (security, TLS, logging)
    |
    v
Role-Specific Configuration (gateway, PKI, SCEP, ACME)
    |
    v
Validation & Smoke Tests
```

## Template Variables

Scripts use `{{ variable }}` syntax for customer-specific values injected by Terraform:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ customer_id }}` | Customer identifier | `contoso` |
| `{{ environment }}` | Environment name | `prod` |
| `{{ ca_common_name }}` | CA certificate common name | `Contoso Issuing CA` |
| `{{ db_connection_string }}` | Database connection string | `postgresql://...` |
| `{{ hsm_provider }}` | HSM provider | `azure-dedicated-hsm` |
| `{{ log_collector_endpoint }}` | Log collector endpoint | `logs.contoso.com` |

## Adding New Roles

1. Create directory: `configuration/<os>/<role>/`
2. Add configuration script: `<role>-config.ps1` or `<role>-config.sh`
3. Use template variables for customer-specific values
4. Add validation tests
5. Update this README

## Security Notes

- Never hardcode secrets in scripts
- Use Azure Key Vault / Managed Identity for credentials
- All scripts run with least privilege
- Audit logging enabled for all configuration changes
