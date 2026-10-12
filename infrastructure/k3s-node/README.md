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

## 4. Mullvad VPN split-tunnel for Cloudflare Tunnel edge (Fedora host)

The Fedora host runs **Mullvad VPN with a killswitch**: all non-LAN traffic
from the host — including forwarded traffic from the k8s01 VM behind libvirt
NAT — is policy-routed into the tunnel (Colombia exit). Cloudflare's
tunnel-edge ranges (`198.41.0.0/16`) proved **unreachable via that exit**
(UDP and TCP both dead), which blocked `cloudflared` on k8s01 entirely while
the same ranges work fine from the open LAN.

Fix (approved by owner 2026-10-11): **split-tunnel only the Cloudflare edge
range** using Mullvad's own bypass marks, killswitch fully intact for
everything else.

Host-level, persisted via `clm-split-tunnel.service`
(`/etc/systemd/system/clm-split-tunnel.service` +
`/etc/clm-split-tunnel.nft`):

```
nftables table inet clm-split:
  mangle-output / mangle-prerouting:
    ip daddr 198.41.0.0/16 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
ip route replace 198.41.0.0/16 via 192.168.1.1 dev wlp2s0
```

Why both marks: `ct mark 0x00000f41` is what Mullvad's killswitch accepts in
its output filter; `meta mark 0x6d6f6c65` is what Mullvad's policy routing
(`ip rule 32765`) excludes from the tunnel table. Mullvad only manages its
own `inet mullvad` table, so `inet clm-split` survives daemon re-renders;
the systemd unit restores everything at boot.

Also note: target `cloudflared` runs `--protocol http2` (see
apps/clm/app/cloudflared.yaml) — TCP/7844 through the consumer-NAT path,
deterministic. QUIC/auto would likely work too now that the route exists.
