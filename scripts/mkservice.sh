#!/usr/bin/env bash
# Scaffold new container file + data dir
set -euo pipefail
usage(){ echo "Usage: $0 <service-name> [image[:tag]]" >&2; exit 1; }
[[ $# -lt 1 ]] && usage

SERVICE="$1"; shift
IMAGE="${1:-nginx:latest}"

DATA_DIR="/srv/homelab-data/$SERVICE"
YAML="/srv/containers/${SERVICE}.yml"

sudo mkdir -p "$DATA_DIR"
sudo chown -R groot:docker "$DATA_DIR"
sudo chcon -Rt svirt_sandbox_file_t "$DATA_DIR"

cat > "$YAML" <<EOF
services:
  $SERVICE:
    image: $IMAGE
    container_name: $SERVICE
    restart: unless-stopped
    volumes:
      - $DATA_DIR:/data
    labels:
      - com.centurylinklabs.watchtower.enable=true
EOF

echo "✓ Created $YAML and data dir."
