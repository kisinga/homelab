# Baseline Stack & Architecture

\*Companion to **Git Autopull & Bootstrap\***

> ✅ This setup is designed to run on **any modern Linux system** with Docker and systemd — but is tested and tailored on a **Lenovo ThinkCentre M900 (Fedora 42)** for real-world reliability.

---

## 🧭 Prime Directive

Run **any** OCI workload, keep it up-to-date, and expose only with intent:

- Internal-only by default
- VPN-first via **Tailscale Serve**
- Public via **Cloudflare Tunnel** _(DNS automation pending)_

> _One YAML diff → reconciled runtime._

---

## ⚙️ Assumptions

| Axis                                  | Assumption                                          | Rationale                                       |
| ------------------------------------- | --------------------------------------------------- | ----------------------------------------------- |
| Docker runs **rootful**               | SELinux relabel is easy; avoids rootless complexity | KISS                                            |
| User **groot** in group **docker**    | Single‑user homelab                                 | Consistent UID/GID for bind mounts              |
| Git branch **main** only              | No env‑specific branches                            | Fast FF‑only deploys                            |
| **Data lives at `/srv/homelab-data`** | Outside repo tree                                   | `rm -rf /srv/homelab` now safe for hard reclone |

---

## 🖥️ Hardware & OS (Test Host)

| Component   | Detail                                                     |
| ----------- | ---------------------------------------------------------- |
| **Host**    | Lenovo ThinkCentre M900 — i5‑6500 · 32 GB RAM · 1 TB SSD   |
| **OS**      | Fedora 42 (**SELinux enforcing**)                          |
| **Network** | 1 Gb fibre → router → **Tailscale** mesh (zero open ports) |

---

## Easy Start

Run this on your homelab host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kisinga/homelab/main/scripts/setup.sh)"
```

## 🗂 Directory Layout

```bash
#  Code & compose files
/srv/homelab
├─ stacks/
│  └─ core.yml
├─ scripts/
├─ systemd/
└─ .env

# Persistent volumes (outside Git)
/srv/homelab-data
└─ dukahub/
```

_Ownership_: `groot:docker`, `0775` on both roots.
_SELinux_: `chcon -Rt svirt_sandbox_file_t /srv/homelab /srv/homelab-data`

---

## 📦 Core Stack (`stacks/core.yml`)

_External file—_:

> All services mount subdirs under `/srv/homelab-data`, **never inside the repo**.

---

## 🛠 Systemd Units

| Unit                      | Purpose                               |
| ------------------------- | ------------------------------------- |
| `homelab-core.service`    | Starts core stack (no Git dependency) |
| `homelab-gitpull.service` | Pulls latest repo and redeploys stack |
| `homelab-gitpull.timer`   | Triggers the above every 5 minutes    |
| `.git/hooks/post-merge`   | Local fallback redeploy               |

Unit files live in `systemd/` and are deployed via `scripts/bootstrap.sh`. They always run as user `groot`, with `docker` group permissions.

---

## 🌐 Networking Recipes

| Scenario      | Command                                                 |
| ------------- | ------------------------------------------------------- |
| Tailnet HTTPS | `sudo tailscale serve --bg https://localhost:8080`      |
| Public tunnel | `cloudflared tunnel run homelab` _(automation pending)_ |

Always access internal services over port **443** in Tailnet.

---

## 🔍 Monitoring & Self-Healing

| Concern         | Tool           | Status | Note                     |
| --------------- | -------------- | ------ | ------------------------ |
| Image freshness | **Watchtower** | ✅     | `WATCHTOWER_*` in `.env` |
| Stack restarts  | **systemd**    | ✅     | `RemainAfterExit=yes`    |
| Metrics         | Prometheus     | ⏳     | Future drop-in           |
| Alerting        | Shoutrrr       | ⏳     | `SHOUTRRR_URL` in `.env` |

---

## 🧪 Troubleshooting

| Symptom                        | Diagnostic                              | Resolution                        |
| ------------------------------ | --------------------------------------- | --------------------------------- |
| Container cannot write         | `docker logs <id>`                      | Relabel `/srv/homelab-data/<svc>` |
| Watchtower “permission denied” | `docker logs watchtower`                | Relabel `docker.sock`             |
| HTTPS fails                    | `curl 127.0.0.1:8080` OK?               | Use `tailscale serve` port 443    |
| Git pull broke stack           | `journalctl -u homelab-gitpull.service` | Roll back commit; volumes safe    |

---

## 🧰 QoL Helpers

- `scripts/mkservice.sh` → scaffolds service + matching `/srv/homelab-data/<svc>`
- `scripts/labels-fix.sh` → relabels both trees

---

## 🚧 Roadmap

- [ ] Enable Watchtower with private registry (GHCR)
- [ ] Add `.labels` file to auto-run `tailscale serve`
- [ ] Add `monitoring.yml` stack with Prometheus + Grafana
- [ ] Add Matrix or Shoutrrr alerts on failed units

---

## 🧵 End-State

A self-healing, self-updating homelab with:

- No open ports
- Config-as-code via Git
- Data-separated from deployment
- Bare-metal recovery in **<10 min**

With just:

- This doc
- Your Git repo
- The Autopull & Bootstrap guide

You're fully back online.

---
