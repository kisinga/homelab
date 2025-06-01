# Homelab Git Autopull & Bootstrap

_Companion to [**Baseline Stack & Architecture**](./baseline_stack_architecture_v3.md)_
_Data volumes now live in `/srv/homelab-data` outside the repo._

This document defines how the ThinkCentre pulls configuration from Git, deploys services, and stays in sync — **without manual SSH**. It includes bootstrapping, periodic updates, safety nets, and real-world caveats.

---

## 1 · Responsibilities

| Concern                  | Handled By                                   |
| ------------------------ | -------------------------------------------- |
| Safe first-run bootstrap | `scripts/bootstrap.sh`                       |
| Continuous deployment    | `systemd/homelab-gitpull.service` + `.timer` |
| Manual safety net        | `.git/hooks/post-merge`                      |
| Secrets hygiene          | Never overwrite `.env`, use `.env.example`   |

---

## 2 · Workflow Overview

### ✅ 1. **Bootstrap (initial clone)**

Clone the Git repository to `/srv/homelab` and set up the environment

```bash
chmod +x scripts/*.sh
```

This is **mandatory**. If skipped, systemd and manual executions will fail with `Permission denied`.  
Then execute the bootstrap script:

```bash
sudo bash scripts/bootstrap.sh
```

This performs:

- Git clone (or pull) to `/srv/homelab`
- Sets folder permissions and SELinux labels
- Installs & enables `homelab-core.service`
- (If enabled in the script) copies systemd unit files to `/etc/systemd/system`
- Marks all `*.sh` scripts as executable with `chmod +x`

### ✅ 2. **Autopull Every 5 Minutes**

Enabled via `homelab-gitpull.timer`, this calls `homelab-gitpull.service`:

```ini
ExecStart=/usr/bin/git pull --ff-only origin main
ExecStartPost=/usr/bin/docker compose -f stacks/core.yml up -d --pull always
```

This ensures any update pushed to Git is pulled + deployed automatically.

### ✅ 3. **Manual Git Pull (Safety Net)**

Any manual `git pull` triggers `.git/hooks/post-merge`:

```bash
docker compose -f stacks/core.yml up -d
```

---

## 3 · Required Files (Inventory)

| File                              | Purpose                           |
| --------------------------------- | --------------------------------- |
| `scripts/bootstrap.sh`            | One-shot setup script (see below) |
| `systemd/homelab-gitpull.service` | Pull & redeploy                   |
| `systemd/homelab-gitpull.timer`   | 5-min polling trigger             |
| `.git/hooks/post-merge`           | Manual hot-reload on pull         |

---

## 4 · Common Pitfalls & Remedies

| Symptom                                 | Likely Cause                                    | Fix                                                       |
| --------------------------------------- | ----------------------------------------------- | --------------------------------------------------------- |
| `git@github.com: Permission denied`     | SSH key not loaded / agent issue                | Ensure `groot` or active user can `ssh -T git@github.com` |
| `Could not read from remote repository` | Wrong user or systemd running as root           | Use `User=groot` in systemd service                       |
| `.git/FETCH_HEAD: Permission denied`    | Git repo owned by different user                | Run `sudo chown -R groot:docker /srv/homelab`             |
| `systemctl cat` doesn't reflect changes | Edited wrong path (e.g. repo instead of `/etc`) | Copy unit to `/etc/systemd/system` + `daemon-reload`      |
| Scripts not executable                  | `chmod +x` not run after cloning                | Run `chmod +x scripts/*.sh`                               |
| Service runs manually but not on timer  | Timer not enabled                               | `sudo systemctl enable --now homelab-gitpull.timer`       |

---

## 5 · What We Learned (Lessons from Setup)

- ✅ **Don't edit systemd units inside the repo** unless you're syncing them manually
- ✅ **Always check which unit systemd sees** via `systemctl cat`
- ✅ **Use `User=` in the service unit** to run as `groot`, not `root`
- ✅ **Explicit `chmod +x` is non-negotiable** for shell scripts under version control
- ✅ **Timers won't work unless explicitly enabled**
- ✅ Use `--remove-orphans` in `docker compose` to clean up legacy containers

---

## 6 · Next Steps

- [ ] Add bootstrap logic to deploy systemd units automatically
- [ ] Add recovery script that re-pulls config, resets permissions, and restarts stack
- [ ] Wire Shoutrrr or similar for failure alerts
- [ ] Document safe `.env` creation from `.env.example`

---

## 7 · Reference: Bootstrap Script Actions

`scripts/bootstrap.sh` performs:

```bash
# Clone or pull Git repo
# Set ownership + permissions
# Label with SELinux context
# Enable homelab-core.service
# (Optionally) copy systemd units
# Mark scripts executable
```

Make sure `REPO_URL`, `DEST_DIR`, and `SYSTEMD_UNIT` are defined at the top of the script.

---

### End-State Goal

A low-maintenance, self-updating node where:

- You **push once**
- It **pulls & applies**
- You **never SSH in** unless recovering from disaster

---
