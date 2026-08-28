# OpenBao policy for PKI workload authentication
# Allows workloads to authenticate and access their own secrets

# Allow reading own service identity
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow PKI workload authentication
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}

# Allow SPIRE workload authentication
path "auth/spire-cert/login" {
  capabilities = ["create", "update"]
}

path "auth/spire-mtls/login" {
  capabilities = ["create", "update"]
}

# Allow reading certificate data
path "pki/cert/*" {
  capabilities = ["read", "list"]
}

path "pki/certs" {
  capabilities = ["list"]
}

# Allow reading secrets for PKI workloads
path "secret/data/pki/*" {
  capabilities = ["read", "list"]
}

path "secret/data/pki-workloads/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow generating certificates
path "pki/issue/*" {
  capabilities = ["create", "update"]
}

path "pki/sign/*" {
  capabilities = ["create", "update"]
}

# Allow revoking certificates
path "pki/revoke" {
  capabilities = ["create", "update"]
}

# Read health status
path "sys/health" {
  capabilities = ["read", "sudo"]
}
