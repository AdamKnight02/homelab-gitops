#cloud-config
# =============================================================================
# Cloud-Init Configuration for Azure VM — K3s + Argo CD Bootstrap
# =============================================================================
# Tier-aware template supporting single-node (economy) and multi-node
# (standard/enterprise) K3s clusters.
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

write_files:
  # K3s config for server nodes
  - path: /etc/rancher/k3s/config.yaml
    content: |
%{ if node_role == "server" ~}
      # Server configuration
      write-kubeconfig-mode: "644"
      disable:
        - traefik
        - servicelb
%{ if node_index == 0 ~}
      # First server — cluster init
      cluster-init: true
%{ else ~}
      # Additional server — join existing
      server: ${k3s_server_url}
      token: ${k3s_token}
%{ endif ~}
%{ if enable_azure_ccm ~}
      # Azure Cloud Controller Manager
      disable-cloud-controller: true
      disable-kube-proxy: false
%{ endif ~}
%{ if enable_azure_csi ~}
      # Azure CSI drivers will be installed post-boot
%{ endif ~}
%{ else ~}
      # Agent configuration
      server: ${k3s_server_url}
      token: ${k3s_token}
%{ endif ~}

%{ if enable_azure_ccm ~}
  # Azure Cloud Provider config
  - path: /etc/rancher/k3s/azure.json
    content: |
      {
        "cloud": "AzurePublicCloud",
        "tenantId": "${azure_tenant_id}",
        "subscriptionId": "${azure_subscription_id}",
        "aadClientId": "${azure_client_id}",
        "resourceGroup": "${azure_resource_group}",
        "location": "eastus",
        "vnetName": "${azure_vnet_name}",
        "vnetResourceGroup": "${azure_resource_group}",
        "subnetName": "${azure_subnet_name}",
        "securityGroupName": "${azure_nsg_name}",
        "loadBalancerName": "${azure_lb_name}",
        "useInstanceMetadata": true,
        "useManagedIdentityExtension": true
      }
    permissions: "0600"
%{ endif ~}

runcmd:
  # --- System Preparation ---
  - echo "=== Starting K3s installation (role: ${node_role}, index: ${node_index}) ==="
  - sysctl -w net.ipv4.ip_forward=1
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

%{ if node_role == "server" && node_index == 0 ~}
  # --- Install K3s Server (first node — cluster init) ---
  - |
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_CHANNEL=${k3s_version} \
      INSTALL_K3S_EXEC="server" \
      sh -
%{ endif ~}

%{ if node_role == "server" && node_index > 0 ~}
  # --- Install K3s Server (join existing cluster) ---
  - |
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_CHANNEL=${k3s_version} \
      INSTALL_K3S_EXEC="server" \
      K3S_URL="${k3s_server_url}" \
      K3S_TOKEN="${k3s_token}" \
      sh -
%{ endif ~}

%{ if node_role == "agent" ~}
  # --- Install K3s Agent ---
  - |
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_CHANNEL=${k3s_version} \
      K3S_URL="${k3s_server_url}" \
      K3S_TOKEN="${k3s_token}" \
      sh -
%{ endif ~}

%{ if node_role == "server" && node_index == 0 ~}
  # --- Wait for K3s to be ready ---
  - sleep 30
  - |
    until kubectl get nodes | grep -q " Ready"; do
      echo "Waiting for K3s node to be ready..."
      sleep 10
    done

  # --- Install Azure CSI Driver (if enabled) ---
%{ if enable_azure_csi ~}
  - echo "=== Installing Azure Disk CSI Driver ==="
  - |
    curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh | bash -s master --
  - echo "=== Installing Azure File CSI Driver ==="
  - |
    curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/install-driver.sh | bash -s master --
%{ endif ~}

  # --- Install Azure Cloud Controller Manager (if enabled) ---
%{ if enable_azure_ccm ~}
  - echo "=== Installing Azure Cloud Controller Manager ==="
  - |
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/deploy/azure-cloud-controller-manager.yaml
%{ endif ~}

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
    cat <<'AROEOF' | kubectl apply -f -
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
    AROEOF

  # --- Post-Install Notes ---
  - echo "=== Installation Complete ==="
  - echo "K3s kubeconfig: /etc/rancher/k3s/k3s.yaml"
  - echo "Argo CD initial password:"
  - kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  - echo ""
  - echo "To access Argo CD locally: kubectl port-forward svc/argocd-server -n argocd 8080:443"
%{ endif ~}

final_message: "K3s bootstrap completed (role: ${node_role}, index: ${node_index}). Check /var/log/cloud-init-output.log for details."
