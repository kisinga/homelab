#!/usr/bin/env bash
# labels-fix.sh — reassert SELinux contexts for homelab
set -euo pipefail

for path in /srv/homelab /srv/homelab-data; do
  sudo chcon -Rt svirt_sandbox_file_t "$path"
done

sudo chcon -t svirt_sandbox_file_t /var/run/docker.sock
echo "✓ SELinux labels re-applied to homelab trees & docker.sock"
