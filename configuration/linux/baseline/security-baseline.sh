#!/bin/bash
# Linux Security Baseline for PKI Platform
# Applied to all Linux VMs before role-specific configuration

set -euo pipefail

# TODO: Customer-specific values injected via Terraform templatefile()
CUSTOMER_ID="${CUSTOMER_ID:-{{ customer_id }}}"
ENVIRONMENT="${ENVIRONMENT:-{{ environment }}}"
LOG_FILE="/var/log/baseline-config.log"

# Logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Linux Security Baseline ==="
echo "Customer: $CUSTOMER_ID"
echo "Environment: $ENVIRONMENT"
echo "Timestamp: $(date -Iseconds)"

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install security tools
echo "Installing security tools..."
apt-get install -y \
    aide \
    auditd \
    clamav \
    clamav-daemon \
    fail2ban \
    libpam-pwquality \
    rkhunter \
    ufw

# Configure firewall
echo "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
# TODO: Add customer-specific allowed ports
ufw allow 22/tcp comment 'SSH'
ufw --force enable

# Configure SSH hardening
echo "Hardening SSH configuration..."
cat > /etc/ssh/sshd_config.d/99-pki-baseline.conf <<EOF
# PKI Platform SSH Hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 5
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
Banner /etc/issue.net
EOF

# Configure password policy
echo "Configuring password policy..."
cat > /etc/security/pwquality.conf <<EOF
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 3
maxrepeat = 2
EOF

# Configure auditd
echo "Configuring auditd..."
cat > /etc/audit/rules.d/pki-baseline.rules <<EOF
# PKI Platform Audit Rules
-D
-b 8192
-f 1

# Monitor authentication
-w /var/log/auth.log -p wa -k authentication
-w /var/log/faillog -p wa -k authentication

# Monitor user/group changes
-w /etc/passwd -p wa -k user_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/gshadow -p wa -k gshadow_changes

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudo_changes
-w /etc/sudoers.d/ -p wa -k sudo_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor network configuration
-w /etc/network/ -p wa -k network_config
-w /etc/netplan/ -p wa -k network_config

# Monitor system calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-w /etc/localtime -p wa -k time_change

# Monitor kernel modules
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Monitor file mounts
-a always,exit -F arch=b64 -S mount -S umount2 -k mounts

# Monitor file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete

# Monitor privileged commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -k privileged
-a always,exit -F path=/usr/bin/su -F perm=x -k privileged
EOF

systemctl enable auditd
systemctl restart auditd

# Configure AIDE
echo "Configuring AIDE..."
aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Configure automatic security updates
echo "Configuring automatic security updates..."
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Disable unused services
echo "Disabling unused services..."
systemctl disable --now avahi-daemon || true
systemctl disable --now cups || true
systemctl disable --now bluetooth || true

# Configure kernel parameters
echo "Configuring kernel parameters..."
cat > /etc/sysctl.d/99-pki-baseline.conf <<EOF
# IP forwarding (disable unless gateway)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# SYN cookies
net.ipv4.tcp_syncookies = 1

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 if not needed
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-pki-baseline.conf

# Configure fail2ban
echo "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = admin@example.com
sendername = Fail2Ban

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Set file permissions
echo "Setting file permissions..."
chmod 600 /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config.d/99-pki-baseline.conf
chmod 600 /etc/security/pwquality.conf
chmod 600 /etc/audit/rules.d/pki-baseline.rules

echo "=== Linux Security Baseline Complete ==="
