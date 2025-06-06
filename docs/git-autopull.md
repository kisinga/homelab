# Homelab Git Autopull & Bootstrap

_Companion to [\*\*Baseline Stack & Architecture](./README.md)\*\*_
_Enables hands-free updates of the core Docker stack and services via Git + systemd._

---

## 0 · Purpose

This document defines how a homelab system, bootstrapped from this Git repository, maintains itself by:

- Automatically pulling the latest Git `main` branch changes every 5 minutes.
- Applying these changes to the running Docker Compose stack (defined in `stacks/core.yml`).
- Preserving local secrets (e.g., `.env` file) which are not versioned in Git.

This setup has been tested on Fedora 42 with systemd, Docker 27, and Git.

---

## 1 · Responsibilities

| Concern                           | Handled By                                           |
| --------------------------------- | ---------------------------------------------------- |
| Initial safe first-run setup      | `scripts/setup.sh`                                   |
| Continuous deployment from Git    | `homelab-gitpull.service` + `homelab-gitpull.timer`  |
| Manual deployment safety net      | `.git/hooks/post-merge` (for local `git pull/merge`) |
| Secrets hygiene                   | `.env` file is gitignored and managed on the host.   |
| Core application stack definition | `stacks/core.yml`                                    |

---

## 2 · Workflow Overview

### ✅ 1. **Bootstrap (One-Time Initial Setup)**

Executed via `scripts/setup.sh`:

```bash
# Ensure scripts are executable if cloned manually
# chmod +x scripts/*.sh
sudo bash scripts/setup.sh
```

This script performs critical initial setup tasks:

- Clones the `kisinga/homelab` repository to `/srv/homelab` or fast-forwards it if already present.
- Applies necessary SELinux context labels (e.g., `svirt_sandbox_file_t`) to `/srv/homelab` and `/srv/homelab-data`.
- Copies systemd unit files from `systemd/` to `/etc/systemd/system/` and reloads the systemd daemon.
- Enables and starts `homelab-core.service` (to bring up the stack from `stacks/core.yml`) and `homelab-gitpull.timer`.
- Ensures correct file ownership (`groot:docker`) and permissions.

### ✅ 2. **Automated Git Pull & Redeploy (Every 5 Minutes)**

- **Trigger:** `homelab-gitpull.timer`
  ```ini
  # systemd/homelab-gitpull.timer
  [Timer]
  OnBootSec=2min
  OnUnitActiveSec=5min # Adjust interval as needed
  Unit=homelab-gitpull.service
  ```
- **Action:** `homelab-gitpull.service`
  ```ini
  # systemd/homelab-gitpull.service
  [Service]
  Type=oneshot
  User=groot
  Group=docker
  WorkingDirectory=/srv/homelab
  # Step 1: Pull latest changes from the 'main' branch
  ExecStart=/usr/bin/git pull --ff-only origin main
  # Step 2: Redeploy the core stack using Docker Compose
  # '--pull always' can be used if images in core.yml are 'latest' and might change upstream
  # For images updated by Watchtower, '--pull missing' or no pull flag is also fine.
  ExecStartPost=/usr/bin/docker compose -f /srv/homelab/stacks/core.yml up -d --remove-orphans
  ```
  This service ensures that any changes committed and pushed to the `main` branch of the Git repository are automatically reflected in the running homelab services.

### ✅ 3. **Manual Pull & Redeploy (CLI Fallback)**

For immediate changes after a manual `git pull` or `git merge` in `/srv/homelab` on the host:

- **Hook:** `.git/hooks/post-merge` (symlinked or copied from `scripts/git-hooks/post-merge` during `setup.sh`)
  ```bash
  #!/bin/sh
  echo "Git hook: post-merge detected. Redeploying core stack..."
  /usr/bin/docker compose -f /srv/homelab/stacks/core.yml up -d --remove-orphans
  exit 0
  ```

---

## 3 · Required Files & Directories

| Path                              | Purpose                                                                   |
| --------------------------------- | ------------------------------------------------------------------------- |
| `scripts/setup.sh`                | Orchestrates the initial bootstrap process.                               |
| `scripts/deploy.sh`               | Helper script for manual redeployment (often called by `setup.sh`).       |
| `scripts/git-hooks/post-merge`    | Git hook script template.                                                 |
| `systemd/homelab-core.service`    | Systemd unit to start the core Docker stack at boot.                      |
| `systemd/homelab-gitpull.service` | Systemd unit to perform `git pull` and `docker compose up`.               |
| `systemd/homelab-gitpull.timer`   | Systemd timer to periodically trigger `homelab-gitpull.service`.          |
| `stacks/core.yml`                 | Docker Compose file defining the core services (e.g., Watchtower, proxy). |
| `.env` (on host, gitignored)      | Stores secrets and environment-specific configurations.                   |
| `.env.example` (in Git)           | Template for the `.env` file.                                             |

---

## 4 · Pitfalls & Common Fixes

| Symptom                                       | Diagnostic Command(s)                                                    | Common Resolution(s)                                                                                               |
| --------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `.sh` scripts won't execute                   | Check `ls -l scripts/` for execute permissions.                          | `chmod +x scripts/*.sh`                                                                                            |
| `homelab-gitpull.service` fails on `git pull` | `sudo journalctl -u homelab-gitpull.service`                             | Ensure SSH keys for Git are correctly set up for user `groot` if using SSH Git URLs. Ensure network access.        |
| Timer not running / not triggering service    | `sudo systemctl list-timers`, `sudo journalctl -u homelab-gitpull.timer` | `sudo systemctl enable --now homelab-gitpull.timer`                                                                |
| Systemd units not found or outdated           | `sudo systemctl status <unit>`, `sudo systemctl cat <unit>`              | Re-run `scripts/setup.sh` or manually copy units to `/etc/systemd/system/` and run `sudo systemctl daemon-reload`. |
| Incorrect file ownership in `/srv/homelab`    | `ls -ld /srv/homelab`, `ls -lR /srv/homelab`                             | `sudo chown -R groot:docker /srv/homelab`                                                                          |
| Docker Compose errors in service logs         | `sudo journalctl -u homelab-gitpull.service`                             | Check `stacks/core.yml` for syntax errors. Ensure `.env` file has all required variables.                          |

---

## 5 · Security & Best Practices

- **`.env` File**: Contains secrets and **must never be committed to Git.** Use `.env.example` as a template.
- **Permissions**: `/srv/homelab` and `/srv/homelab-data` should generally be `0775` (`rwxrwxr-x`) with `groot:docker` ownership.
- **SELinux Contexts**: Ensure `svirt_sandbox_file_t` (or another appropriate context) is applied to `/srv/homelab` and `/srv/homelab-data` for container volume access.
- **Git Access**: If using SSH for Git pulls, the SSH key used by `groot` should be a deploy key with read-only access to the repository.
- **Principle of Least Privilege**: The systemd services run as `groot` (who is in the `docker` group) to manage Docker. Avoid running unnecessary processes as root.

---

## 6 · Manual Recovery & Redeployment

If the automated stack breaks or needs immediate intervention:

1.  **Log in to the host.**
2.  **Navigate to the repo directory:** `cd /srv/homelab`
3.  **Attempt a manual pull (if network/Git issues are suspected):** `sudo -u groot git pull --ff-only origin main`
4.  **Run the manual deploy script:** `sudo bash scripts/deploy.sh`
    (This script typically runs `docker compose -f stacks/core.yml up -d --remove-orphans`)

Alternatively, to restart the automated pull and deploy process:

```bash
sudo systemctl restart homelab-gitpull.service
```

To restart just the core services without a Git pull:

```bash
sudo systemctl restart homelab-core.service
```

---

## 7 · Future Enhancements

- [ ] Add a health check step in `homelab-gitpull.service` before and after `docker compose up` to verify deployment success.
- [ ] Implement retry logic for failed deployments within the service unit.
- [ ] Integrate notifications (e.g., via Shoutrrr from `.env`) on deployment success or failure.
- [ ] Explore Git webhook support as an alternative to polling, for more immediate deployments (requires exposing an endpoint).

---

## 8 · Summary

This Git-centric autopull and bootstrap mechanism forms the backbone of a dynamic and maintainable homelab. By defining your infrastructure as code within this repository, your physical system consistently aligns with the desired state defined in the `main` branch.

_Maintain the Git repository → the homelab system follows suit._
