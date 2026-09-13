#!/bin/bash
# Linux TLS Baseline for PKI Platform
# Configures TLS certificates and settings

set -euo pipefail

# TODO: Customer-specific values injected via Terraform templatefile()
CUSTOMER_ID="${CUSTOMER_ID:-{{ customer_id }}}"
ENVIRONMENT="${ENVIRONMENT:-{{ environment }}}"
LOG_FILE="/var/log/tls-baseline.log"

exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Linux TLS Baseline ==="
echo "Customer: $CUSTOMER_ID"
echo "Environment: $ENVIRONMENT"

# Install certbot for ACME (if needed)
echo "Installing certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Configure TLS settings
echo "Configuring TLS settings..."

# Create strong DH parameters
echo "Generating DH parameters (this may take a while)..."
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# Configure OpenSSL
echo "Configuring OpenSSL..."
cat > /etc/ssl/openssl.cnf.d/99-pki-baseline.cnf <<EOF
# PKI Platform TLS Configuration

[system_default_sect]
MinProtocol = TLSv1.2
CipherString = DEFAULT@SECLEVEL=2
Options = ServerPreference,PrioritizeChaCha
EOF

# Configure certificate directories
echo "Configuring certificate directories..."
mkdir -p /etc/pki/tls/{certs,private}
chmod 755 /etc/pki/tls
chmod 755 /etc/pki/tls/certs
chmod 750 /etc/pki/tls/private

# TODO: Retrieve certificates from Azure Key Vault using Managed Identity
echo "TODO: Retrieve TLS certificates from Azure Key Vault"
echo "TODO: Configure automatic certificate renewal"

# Configure certificate monitoring
echo "Configuring certificate monitoring..."
cat > /etc/cron.daily/check-certs <<'EOF'
#!/bin/bash
# Check certificate expiration
for cert in /etc/pki/tls/certs/*.crt; do
    if [ -f "$cert" ]; then
        expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry" +%s)
        now_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
        
        if [ $days_left -lt 30 ]; then
            echo "WARNING: Certificate $cert expires in $days_left days"
            # TODO: Send alert
        fi
    fi
done
EOF

chmod +x /etc/cron.daily/check-certs

echo "=== Linux TLS Baseline Complete ==="
