#!/bin/bash
# Linux Logging Baseline for PKI Platform
# Configures centralized logging and log forwarding

set -euo pipefail

# TODO: Customer-specific values injected via Terraform templatefile()
CUSTOMER_ID="${CUSTOMER_ID:-{{ customer_id }}}"
ENVIRONMENT="${ENVIRONMENT:-{{ environment }}}"
LOG_FILE="/var/log/logging-baseline.log"

exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Linux Logging Baseline ==="
echo "Customer: $CUSTOMER_ID"
echo "Environment: $ENVIRONMENT"

# Install rsyslog
echo "Installing rsyslog..."
apt-get update
apt-get install -y rsyslog rsyslog-gnutls

# Configure rsyslog
echo "Configuring rsyslog..."
cat > /etc/rsyslog.d/99-pki-baseline.conf <<EOF
# PKI Platform Logging Configuration

# Forward all logs to central collector
# TODO: Add customer-specific log collector endpoint
*.* action(
    type="omfwd"
    target="{{ log_collector_endpoint }}"
    port="6514"
    protocol="tcp"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="{{ log_collector_hostname }}"
    action.resumeRetryCount="-1"
    queue.type="linkedList"
    queue.filename="rsyslog_queue"
    queue.maxdiskspace="1g"
    queue.saveonshutdown="on"
)

# Local logging with rotation
$template TraditionalFormat,"%timegenerated% %HOSTNAME% %syslogtag%%msg%\n"

# Auth logs
auth,authpriv.* /var/log/auth.log

# Kernel logs
kern.* /var/log/kern.log

# Mail logs
mail.* /var/log/mail.log

# Cron logs
cron.* /var/log/cron.log

# All other logs
*.*;auth,authpriv.none;kern.none;mail.none;cron.none /var/log/syslog
EOF

# Configure logrotate
echo "Configuring logrotate..."
cat > /etc/logrotate.d/pki-baseline <<EOF
/var/log/auth.log
/var/log/kern.log
/var/log/mail.log
/var/log/cron.log
/var/log/syslog
{
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Configure journald
echo "Configuring journald..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-pki-baseline.conf <<EOF
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=1G
SystemMaxFileSize=100M
MaxRetentionSec=30day
ForwardToSyslog=yes
EOF

systemctl restart systemd-journald
systemctl restart rsyslog

# Install and configure Fluent Bit (for Kubernetes environments)
echo "Installing Fluent Bit..."
# TODO: Add Fluent Bit installation for Kubernetes log forwarding

echo "=== Linux Logging Baseline Complete ==="
