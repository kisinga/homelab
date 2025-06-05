#!/usr/bin/env bash
# Pull latest repo, update core stack, run all containers
set -euo pipefail

echo "→ git pull"
/usr/bin/git -C /srv/homelab pull --ff-only origin main

echo "→ Updating core stack"
/usr/bin/docker compose --env-file /srv/homelab/.env -f /srv/homelab/stacks/core.yml pull
/usr/bin/docker compose --env-file /srv/homelab/.env -f /srv/homelab/stacks/core.yml up -d

echo "→ Running per-app containers"
/srv/homelab/scripts/container-runner.sh

echo "✔ Deploy done"
