# k3s node host-level configuration (k8s01)

These settings live on the k8s01 host, not in Kubernetes manifests. They are
documented here as the source of truth; apply manually (documented per file).

## 1. Registry mirrors — `/etc/rancher/k3s/registries.yaml`

Source of truth: `infrastructure/registry/registries.yaml` (applied in
migration stage 3; requires `systemctl restart k3s` after changes).

## 2. firewalld — pod/service networks must be trusted

Applied in migration stage 7. **Required for any ingress controller** (Traefik
dials endpoint pod IPs directly) and for direct pod-to-pod traffic:

```bash
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16   # pod CIDR
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16   # service CIDR
sudo firewall-cmd --reload
```

Symptom without this: ClusterIP/DNS works everywhere, but direct pod-IP
connections fail with `EHOSTUNREACH` (ARP dropped by firewalld/br_netfilter
FORWARD policy), and Traefik returns 502 Bad Gateway on every route.

## 3. kubeconfig readability

`sudo chmod 640 /etc/rancher/k3s/k3s.yaml` — recurs on every k3s restart
(k3s rewrites the file with restrictive permissions).
