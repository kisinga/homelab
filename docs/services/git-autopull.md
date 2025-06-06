# Git-based Autopull

This document outlines the Git-based automated deployment workflow that keeps the homelab's core infrastructure in sync with this repository.

## Workflow

1.  **Bootstrap**: The initial setup is done via the `scripts/setup.sh` script, which clones the repository, sets up systemd services, and applies initial configurations.
2.  **Automated Pull & Deploy**: A systemd timer (`homelab-gitpull.timer`) triggers a service (`homelab-gitpull.service`) every 5 minutes. This service pulls the latest changes from the `main` branch and redeploys the `stacks/core.yml` Docker Compose stack.
3.  **Manual Trigger**: A `post-merge` Git hook is also in place to automatically redeploy the stack after a manual `git pull`.

## Key Components

- **`scripts/setup.sh`**: The main bootstrap script.
- **`systemd/`**: Contains the systemd unit files (`.service` and `.timer`) that manage the automated pull and deploy process.
- **`stacks/core.yml`**: Defines the core Docker services.
- **`.env`**: A gitignored file on the host for secrets and environment-specific variables.

## Reasoning

- **Infrastructure as Code (IaC)**: This Git-based approach embodies the IaC philosophy. The state of the homelab is defined in code, making it versionable, repeatable, and easy to manage.
- **Automation**: The systemd-based automation ensures that the homelab is always running the latest version of the infrastructure defined in the `main` branch, without manual intervention.
- **Simplicity**: Using standard tools like Git and systemd makes the process transparent and easy to debug.

## Troubleshooting & Manual Operations

- **Check Service Logs**: Use `sudo journalctl -u homelab-gitpull.service` to view logs from the autopull service.
- **Check Timer Status**: Use `sudo systemctl list-timers` to ensure the timer is active.
- **Manual Redeploy**: To force a redeployment, you can either run `sudo bash scripts/deploy.sh` or restart the systemd service with `sudo systemctl restart homelab-gitpull.service`.
- **File Permissions**: Ensure file ownership and SELinux contexts are correct in `/srv/homelab`. The `setup.sh` script handles this, but it's a common area for issues.

## Security

- The `.env` file contains secrets and is ignored by Git.
- The systemd service runs as a non-root user (`groot`) that is part of the `docker` group.
- If using SSH for Git, use a read-only deploy key.
