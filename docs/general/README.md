# Homelab Infrastructure

This repository contains the infrastructure-as-code for a personal homelab, designed for simplicity, security, and automated maintenance.

## Overview

The philosophy of this homelab is to be:

- **Declarative**: The entire state of the system is defined in this Git repository.
- **Automated**: Changes pushed to the `main` branch are automatically deployed.
- **Secure by Default**: Services are not exposed to the internet unless explicitly configured. Access is primarily handled via a Tailscale mesh network.

## Core Concepts

The architecture is built on a few key concepts. For more detailed information, please refer to the specific documentation pages.

- **[Git-based Autopull](./../services/git-autopull.md)**: The homelab automatically stays in sync with this repository using a systemd-based Git pull and redeploy mechanism. This is the backbone of the automated workflow.

- **Container Management**: All services run as Docker containers, defined in Docker Compose files within the `stacks/` directory.

  - **[Watchtower](./../services/watchtower.md)** handles automatic updates for container images.
  - **[Netdata](./../services/netdata.md)** provides real-time performance monitoring.

- **Networking**:

  - Services are accessed internally via the Tailscale network.
  - Public access can be configured using Cloudflare Tunnels (though this is not the default).

- **[Troubleshooting](./../troubleshooting)**: Common issues, especially those related to SELinux, are documented in the troubleshooting section.

## Reasoning

- **Infrastructure as Code**: Using Git as the single source of truth makes the system easy to version, replicate, and recover.
- **Simplicity**: The stack relies on well-known, standard tools like Docker, Docker Compose, systemd, and Git, making it easy to understand and maintain.
- **Security**: The "internal-only by default" approach, combined with the use of `socket-proxy` to limit Docker API exposure, minimizes the attack surface.

## Getting Started

To bootstrap a new homelab host with this configuration, run the following command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kisinga/homelab/main/scripts/setup.sh)"
```

This will clone the repository, set up the required directories, and start the automated deployment services.

**Before running the script**, you will need to create a `.env` file in the root of the repository with your specific environment variables. An example is provided in `.env.example`.

## Directory Structure

- `/srv/homelab`: The Git repository is cloned here.
- `/srv/homelab-data`: Persistent data for services is stored here, outside of the Git repository, to keep data separate from code.

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
| **OS**      | Fedora 42 (**SELinux enforcing**)                          |
| **Network** | 1 Gb fibre → router → **Tailscale** mesh (zero open ports) |

---

## 🗂 Directory Layout

```bash
#  Code & compose files
/srv/homelab
├─ stacks/
│  ├─ core.yml
│  └─ NETDATA_README.md  # Details for Netdata monitoring
├─ scripts/
├─ systemd/
└─ .env

# Persistent volumes (outside Git)
/srv/homelab-data
└─ dukahub/ # Example service data
```

_Ownership_: `groot:docker`, `0775` on both roots.
_SELinux_: `chcon -Rt svirt_sandbox_file_t /srv/homelab /srv/homelab-data`

---

## 📦 Core Stack (`stacks/core.yml`)

_External file—_:

> All services mount subdirs under `/srv/homelab-data`, **never inside the repo**.
> Monitoring services like Netdata use Docker named volumes for their own data.

---

## 🛠 Systemd Units

| Unit                      | Purpose                               |
| ------------------------- | ------------------------------------- |
| `homelab-core.service`    | Starts core stack (no Git dependency) |
| `homelab-gitpull.service` | Pulls latest repo and redeploys stack |
| `homelab-gitpull.timer`   | Triggers the above every 5 minutes    |
| `.git/hooks/post-merge`   | Local fallback redeploy               |

Unit files live in `systemd/` and are deployed via `scripts/setup.sh`. They always run as user `groot`, with `docker` group permissions.

---

## 🌐 Networking Recipes & Service Access

| Scenario       | Command                                                 | Access Example (via Tailscale)            |
| -------------- | ------------------------------------------------------- | ----------------------------------------- |
| Tailnet HTTPS  | `sudo tailscale serve --bg https://localhost:8080`      | `https://your-tailscale-device-name:443`  |
| Public tunnel  | `cloudflared tunnel run homelab` _(automation pending)_ | `https://your-public-domain.com`          |
| **Netdata UI** | (Handled by Docker port mapping)                        | `http://your-tailscale-device-name:19999` |

Always access internal services over port **443** in Tailnet for services exposed via `tailscale serve`. Other services like Netdata are accessed directly via their mapped port over the Tailscale network.

---

## 🔍 Monitoring & Self-Healing

| Concern                  | Tool           | Status | Note                                                                               |
| ------------------------ | -------------- | ------ | ---------------------------------------------------------------------------------- |
| Image freshness          | **Watchtower** | ✅     | `WATCHTOWER_*` in `.env`, uses `socket-proxy`                                      |
| Stack restarts           | **systemd**    | ✅     | `RemainAfterExit=yes`                                                              |
| Host & Container Metrics | **Netdata**    | ✅     | Access: `http://<host-ip-or-tailscale-name>:19999`. See `stacks/NETDATA_README.md` |
| Application Metrics      | Prometheus     | ⏳     | Future drop-in (`monitoring.yml`)                                                  |
| Alerting                 | Shoutrrr       | ⏳     | `SHOUTRRR_URL` in `.env`                                                           |

---

## 🧪 Troubleshooting

| Symptom                        | Diagnostic                              | Resolution                           |
| ------------------------------ | --------------------------------------- | ------------------------------------ |
| Container cannot write         | `docker logs <id>`                      | Relabel `/srv/homelab-data/<svc>`    |
| Watchtower "permission denied" | `docker logs watchtower`                | Check `socket-proxy` logs & config   |
| Netdata permission issues      | `docker logs netdata`                   | Check `socket-proxy` & volume mounts |
| HTTPS fails                    | `curl 127.0.0.1:8080` OK?               | Use `tailscale serve` port 443       |
| Git pull broke stack           | `journalctl -u homelab-gitpull.service` | Roll back commit; volumes safe       |

---

## 🧰 QoL Helpers

- `scripts/mkservice.sh` → scaffolds service + matching `/srv/homelab-data/<svc>`

---

## 🚧 Roadmap

- [ ] Enable Watchtower with private registry (GHCR)
- [ ] Add `.labels` file to auto-run `tailscale serve`
- [ ] Add `monitoring.yml` stack with Prometheus + Grafana (Netdata in `core.yml` provides initial metrics)
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
