#!/usr/bin/env bash
# mkservice.sh — scaffold a new Compose service + data dir
set -euo pipefail

usage() { echo "Usage: $0 <service-name> [image[:tag]]" >&2; exit 1; }
[[ $# -lt 1 ]] && usage

SERVICE="$1";              shift
IMAGE="${1:-nginx:latest}" # sane default
DATA_ROOT="/srv/homelab-data"
STACK_FILE="/srv/homelab/stacks/core.yml"

sudo mkdir -p "$DATA_ROOT/$SERVICE"
sudo chown -R groot:docker "$DATA_ROOT/$SERVICE"
sudo chcon -Rt svirt_sandbox_file_t "$DATA_ROOT/$SERVICE"

cat <<EOF

# ---- YAML snippet (append to $STACK_FILE) ----
  $SERVICE:
    image: $IMAGE
    container_name: $SERVICE
    restart: unless-stopped
    volumes:
      - $DATA_ROOT/$SERVICE:/data
    labels:
      - com.centurylinklabs.watchtower.enable=true
# ---- end snippet ----

EOF

echo "✓ Data dir ready at $DATA_ROOT/$SERVICE (SELinux labelled)."
echo "→ Append the snippet above to $STACK_FILE and commit."
