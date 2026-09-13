#cloud-config
# =============================================================================
# Cloud-Init Configuration for Azure VM — K3s + Argo CD Bootstrap
# =============================================================================
# This template is rendered by Terraform and passed as custom_data to the VM.
# DESIGN PRINCIPLES:
#   - NO secrets, passwords, or private keys are embedded
#   - NO long-lived tokens or cloud credentials
#   - All sensitive config is applied post-boot via secure channels
#   - K3s is installed with default settings (suitable for single-node lab)
#   - Argo CD is installed via manifest; initial password retrieved via kubectl
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

# Update packages and install dependencies
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

# Install K3s (single-node, suitable for lab)
runcmd:
  # --- System Preparation ---
  - echo "=== Starting K3s installation ==="
  - sysctl -w net.ipv4.ip_forward=1
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

  # --- Install K3s ---
  # Disable Traefik (we'll use ingress-nginx or none for lab)
  # Disable ServiceLB (not needed for single-node)
  - |
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_CHANNEL=${k3s_version} \
      INSTALL_K3S_EXEC="server --disable=traefik --disable=servicelb --write-kubeconfig-mode=644" \
      sh -

  # --- Wait for K3s to be ready ---
  - sleep 30
  - |
    until kubectl get nodes | grep -q " Ready"; do
      echo "Waiting for K3s node to be ready..."
      sleep 10
    done

  # --- Install Argo CD ---
  - echo "=== Installing Argo CD ==="
  - kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  - kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${argocd_version}/manifests/install.yaml

  # --- Wait for Argo CD ---
  - |
    until kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; do
      echo "Waiting for Argo CD server..."
      sleep 10
    done

  # --- Configure Argo CD Application (root app) ---
  - echo "=== Configuring Argo CD root application ==="
  - |
    cat <<EOF | kubectl apply -f -
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: homelab
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${git_repo_url}
        targetRevision: ${git_target_revision}
        path: apps
        directory:
          recurse: true
          include: '*/application.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
    EOF

  # --- Post-Install Notes ---
  - echo "=== Installation Complete ==="
  - echo "K3s kubeconfig: /etc/rancher/k3s/k3s.yaml"
  - echo "Argo CD initial password:"
  - kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  - echo ""
  - echo "To access Argo CD locally: kubectl port-forward svc/argocd-server -n argocd 8080:443"

# Final message
final_message: "K3s and Argo CD bootstrap completed. Check /var/log/cloud-init-output.log for details."
