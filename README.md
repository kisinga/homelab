# ThinkCentre M900 Homelab — **Baseline Stack & Architecture (v3)**

_Companion to **Git Autopull & Bootstrap (v3)**_

---

## 0 · Prime Directive

Run **any** OCI workload, patch it automatically, and surface it only when expressly allowed—VPN‑first via **Tailscale Serve**, public via **Cloudflare Tunnel** _(DNS TBD)_.  
**One YAML diff → reconciled runtime.**

---

## 1 · Assumptions

| Axis                                  | Assumption                                          | Rationale                                       |
| ------------------------------------- | --------------------------------------------------- | ----------------------------------------------- |
| Docker runs **rootful**               | SELinux relabel is easy; avoids rootless complexity | KISS                                            |
| User **groot** in group **docker**    | Single‑user homelab                                 | Consistent UID/GID for bind mounts              |
| Git branch **main** only              | No env‑specific branches                            | Fast FF‑only deploys                            |
| **Data lives at `/srv/homelab-data`** | Outside repo tree                                   | `rm -rf /srv/homelab` now safe for hard reclone |

---

## 2 · Hardware & OS

| Component   | Detail                                                     |
| ----------- | ---------------------------------------------------------- |
| **Host**    | Lenovo ThinkCentre M900 — i5‑6500 · 32 GB RAM · 1 TB SSD   |
| **OS**      | Fedora 42 (**SELinux enforcing**)                          |
| **Network** | 1 Gb fibre → router → **Tailscale** mesh (zero open ports) |

---

## 3 · Directory Layout

```text
#  Code & compose files
/srv/homelab
├─ stacks/
│  └─ core.yml
├─ scripts/
└─ logs/

#  Persistent volumes (outside Git)
/srv/homelab-data
└─ dukahub/
```

_Ownership_: `groot:docker`, `0775` on both roots.  
_SELinux_: `chcon -Rt svirt_sandbox_file_t /srv/homelab /srv/homelab-data`.

---

## 4 · Core Stack (`stacks/core.yml`)

_External file—changes to note_:

```yaml
services:
  dukahub:
    volumes:
      - /srv/homelab-data/dukahub:/pb_data
```

Every service mounts sub‑dirs beneath `/srv/homelab-data`, **never** the repo path.

---

## 5 · Systemd Units

- `homelab-core.service` → starts stack, untouched by Git logic.
- Unit files live in `systemd/`.

---

## 6 · Networking Recipes

| Scenario      | Command                                                 |
| ------------- | ------------------------------------------------------- |
| Tailnet HTTPS | `sudo tailscale serve --bg https:// localhost:8080`     |
| Public tunnel | `cloudflared tunnel run homelab` _(automation pending)_ |

Always hit **port 443** inside Tailnet.

---

## 7 · Monitoring & Self‑Healing

| Need            | Tool                 | Status | Note                         |
| --------------- | -------------------- | ------ | ---------------------------- |
| Image freshness | **Watchtower**       | ✅     | Label `/var/run/docker.sock` |
| Stack restarts  | **systemd**          | ✅     | `RestartForceExitStatus=1`   |
| Metrics         | Prometheus + Grafana | ⏳     | future `monitoring.yml`      |
| Alerting        | Shoutrrr             | ⏳     | `SHOUTRRR_URL` in `.env`     |

---

## 8 · Troubleshooting

| Symptom                        | Diagnostic                              | Resolution                        |
| ------------------------------ | --------------------------------------- | --------------------------------- |
| Container cannot write         | `docker logs <id>`                      | Relabel `/srv/homelab-data/<svc>` |
| Watchtower “permission denied” | `docker logs watchtower`                | Relabel `docker.sock`             |
| HTTPS fails                    | `curl 127.0.0.1:8080` OK?               | Use `tailscale serve` port 443    |
| Git pull broke stack           | `journalctl -u homelab-gitpull.service` | Roll back commit; volumes safe    |

---

## 9 · QoL Helpers

- `scripts/mkservice.sh` → scaffolds service + matching `/srv/homelab-data/<svc>`
- `scripts/labels-fix.sh` → relabels both trees

---

## 10 · Roadmap

- [ ] SELinux boolean vs relabel for Watchtower
- [ ] `monitoring.yml` drop‑in
- [ ] Cloudflare tunnel unit
- [ ] Matrix alerts on failed units

---

**End‑state:** self‑patching node, zero open ports, bare‑metal recoverable in < 10 min with **two** docs + repo.
