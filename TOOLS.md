# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup: camera names and locations, SSH hosts and aliases, preferred TTS voices, speaker/room names, device nicknames, anything environment-specific.

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

### RedHat VM (k8s01)

- Host: `192.168.122.74`
- User: `openclaw`
- Key: `~/.ssh/openclaw_k8s01`
- Sudo password: `695378`
- K3s kubeconfig: `/etc/rancher/k3s/k3s.yaml` (perms fixed for k3s group)

### OpenBao (namespace: openbao)

- Unseal keys:
  1. `+cPsfgw85mZwRdlxhbJzfQn4fZY+87puHJzcI6bSvIP/`
  2. `14T1I7UVy4S5fTiyBLdabkzYKpUF9OhjFn95del7w+aD`
  3. `tbvkxqdm3SZ9xK6+e+Ii7B567jHnXly1e7yvCHeFOunp`
  4. `DFAYE5aHQPH1ZnuLJ2XfE7iXfvtPwbpte/Gprk00/2IO`
  5. `ZaILJrcGIEu0tVxSlfsdalS5HHBeNnOc5Tg2ovu+pOmv`
- Threshold: 3 of 5
- Status check: `kubectl get pods -n openbao`
- Unseal cmd: `kubectl exec -n openbao openbao-0 -- bao operator unseal -tls-skip-verify <key>`

## Related

- [Agent workspace](/concepts/agent-workspace)
