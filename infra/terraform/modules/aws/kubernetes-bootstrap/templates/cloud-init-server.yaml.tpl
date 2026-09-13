#cloud-config
# =============================================================================
# Cloud-Init: K3s Server Node — ${service_tier} tier
# =============================================================================
# DESIGN PRINCIPLES:
#   - NO secrets, passwords, or private keys embedded
#   - All sensitive config applied post-boot via secure channels
#   - Tier-aware: economy=single-node, standard=multi-node, enterprise=HA
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
  - echo "=== Starting K3s server installation (${service_tier} tier) ==="
  - sysctl -w net.ipv4.ip_forward=1
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

  # --- Install K3s Server ---
  - |
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_CHANNEL=${k3s_version} \
      INSTALL_K3S_EXEC="server ${k3s_server_flags} ${k3s_tls_sans} ${k3s_datastore}" \
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

  # --- Configure Argo CD Root Application ---
  - echo "=== Configuring Argo CD root application ==="
  - |
    cat <<'ARGOAPP' | kubectl apply -f -
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
    ARGOAPP

%{ if s3_bucket_name != "" ~}
  # --- Configure S3 Backup CronJob (Standard+ tier) ---
  - echo "=== Configuring S3 backup ==="
  - |
    cat <<'BACKUPJOB' | kubectl apply -f -
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: etcd-backup
      namespace: kube-system
    spec:
      schedule: "0 2 * * *"
      jobTemplate:
        spec:
          template:
            spec:
              containers:
              - name: backup
                image: amazon/aws-cli:2.15.0
                command:
                - /bin/sh
                - -c
                - |
                  BACKUP_FILE="/backup/etcd-$(date +%Y%m%d-%H%M%S).db"
                  k3s etcd-snapshot save "$${BACKUP_FILE}"
                  aws s3 cp "$${BACKUP_FILE}" "s3://${s3_bucket_name}/etcd/"
                volumeMounts:
                - name: backup-dir
                  mountPath: /backup
              volumes:
              - name: backup-dir
                hostPath:
                  path: /var/lib/rancher/k3s/server/db/snapshots
              restartPolicy: OnFailure
    BACKUPJOB
%{ endif ~}

  # --- Post-Install Notes ---
  - echo "=== Installation Complete ==="
  - echo "K3s kubeconfig: /etc/rancher/k3s/k3s.yaml"
  - echo "Argo CD initial password:"
  - kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  - echo ""
  - echo "Tier: ${service_tier}"
  - echo "Node role: server"

final_message: "K3s server bootstrap completed (${service_tier} tier). Check /var/log/cloud-init-output.log for details."
