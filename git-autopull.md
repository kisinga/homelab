# Homelab Git Autopull & Bootstrap

_Companion to [**Baseline Stack & Architecture**](./README.md)_
_Enables hands-free updates of the core stack and services via Git + systemd._

---

## 0 · Purpose

This document defines how a homelab system:

- Boots from a Git repo
- Pulls latest changes every 5 minutes
- Applies them using Docker Compose
- Does not overwrite local secrets (`.env` is preserved)

Tested on Fedora 42 with systemd, Docker 27, and Git.

---

## 1 · Responsibilities

| Concern               | Handled By                           |
| --------------------- | ------------------------------------ |
| Safe first-run setup  | `scripts/bootstrap.sh`               |
| Continuous deployment | `homelab-gitpull.service` + `.timer` |
| Manual safety net     | `.git/hooks/post-merge`              |
| Secrets hygiene       | `.env` ignored by Git                |

---

## 2 · Workflow Overview

### ✅ 1. **Bootstrap (one-time setup)**

```bash
chmod +x scripts/*.sh
sudo bash scripts/bootstrap.sh
```

Performs:

- Git clone or fast-forward pull
- SELinux relabeling for `/srv/homelab*`
- Copies systemd units to `/etc/systemd/system`
- Enables `homelab-core` and `homelab-gitpull.timer`
- Ensures proper file ownership and permissions

### ✅ 2. **Auto Git Pull (every 5 minutes)**

Triggered by:

```ini
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
```

The paired service unit:

```ini
[Service]
User=groot
WorkingDirectory=/srv/homelab
ExecStart=/usr/bin/git pull --ff-only origin main
ExecStartPost=/usr/bin/docker compose -f stacks/core.yml up -d --pull always
```

### ✅ 3. **Manual Pull (CLI fallback)**

Hooked via `.git/hooks/post-merge`:

```bash
docker compose -f stacks/core.yml up -d
```

---

## 3 · Required Files

| File                              | Purpose                         |
| --------------------------------- | ------------------------------- |
| `scripts/bootstrap.sh`            | Setup logic                     |
| `scripts/deploy.sh`               | Manual redeploy helper          |
| `systemd/homelab-core.service`    | Runs stack at boot              |
| `systemd/homelab-gitpull.service` | Pull + deploy                   |
| `systemd/homelab-gitpull.timer`   | 5-min polling trigger           |
| `.git/hooks/post-merge`           | Pull trigger on manual Git pull |

---

## 4 · Pitfalls & Fixes

| Symptom                    | Diagnostic                              | Resolution                                          |
| -------------------------- | --------------------------------------- | --------------------------------------------------- |
| `.sh` won't execute        | `permission denied`                     | `chmod +x scripts/*.sh`                             |
| Git error in service       | `journalctl -u homelab-gitpull.service` | Check if user has Git SSH access                    |
| Timer doesn't run          | `systemctl list-timers`                 | `sudo systemctl enable --now homelab-gitpull.timer` |
| Wrong systemd unit applies | `systemctl cat <unit>`                  | Re-copy to `/etc/systemd/system` + `daemon-reload`  |
| Repo owned by wrong user   | `ls -l /srv/homelab`                    | `sudo chown -R groot:docker /srv/homelab`           |

---

## 5 · Security Hygiene

- `.env` is **never versioned**
- `.env.example` is tracked for reference
- Permissions on `/srv` are `775` with SELinux context `svirt_sandbox_file_t`
- SSH deploy key must be loaded for `groot` to pull

---

## 6 · Recovery

If the stack breaks:

```bash
cd /srv/homelab
git pull
bash scripts/deploy.sh
```

Or just restart the services:

```bash
sudo systemctl restart homelab-gitpull.service
```

---

## 7 · Future Work

- [ ] Add health check before/after pull
- [ ] Retry failed deployments
- [ ] Add Slack/Matrix alerting on failure
- [ ] Git webhook support (alt to polling)

---

## 8 · Summary

This flow enables GitOps for your homelab — your system:

- Clones itself once
- Reconciles to Git every 5 min
- Only changes if the repo changes

_Maintain the repo → the system follows._
