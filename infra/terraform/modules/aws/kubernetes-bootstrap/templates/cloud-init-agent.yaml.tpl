#cloud-config
# =============================================================================
# Cloud-Init: K3s Agent Node — ${service_tier} tier
# =============================================================================
# Joins an existing K3s server as a worker agent.
# =============================================================================

hostname: ${hostname}
manage_etc_hosts: true

users:
  - name: ${admin_username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}
    groups: users, admin

package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - git
  - jq
  - net-tools
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - software-properties-common
  - conntrack
  - socat
  - nfs-common

runcmd:
  # --- System Preparation ---
  - echo "=== Starting K3s agent installation (${service_tier} tier) ==="
  - sysctl -w net.ipv4.ip_forward=1
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

  # --- Wait for K3s server to be ready ---
  - echo "Waiting for K3s server at ${server_private_ip}:6443..."
  - |
    until curl -k -s https://${server_private_ip}:6443/ping | grep -q "pong"; do
      echo "Waiting for K3s server..."
      sleep 10
    done

  # --- Get node token from server ---
  # NOTE: In production, use AWS SSM Parameter Store or Secrets Manager
  # For lab, we use SSM Run Command to retrieve the token
  - echo "Retrieving K3s node token..."

  # --- Install K3s Agent ---
  # The token is passed via SSM or retrieved from the server
  # For now, use the standard K3s agent install with token from SSM
  - |
    TOKEN=$(aws ssm get-parameter --name "/k3s/${name_prefix}/node-token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    if [ -z "$TOKEN" ]; then
      echo "WARNING: Could not retrieve K3s token from SSM. Agent will not join."
      echo "Manual intervention required: set K3S_TOKEN and re-run installer."
    else
      curl -sfL https://get.k3s.io | \
        INSTALL_K3S_CHANNEL=${k3s_version} \
        K3S_URL="https://${server_private_ip}:6443" \
        K3S_TOKEN="$TOKEN" \
        sh -
    fi

  # --- Post-Install Notes ---
  - echo "=== Agent Installation Complete ==="
  - echo "Tier: ${service_tier}"
  - echo "Node role: agent"
  - echo "Server: ${server_private_ip}"

final_message: "K3s agent bootstrap completed (${service_tier} tier). Check /var/log/cloud-init-output.log for details."
