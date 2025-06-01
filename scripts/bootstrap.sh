#!/usr/bin/env bash
set -euo pipefail
REPO_URL="${REPO_URL:-git@github.com:kisinga/homelab.git}"
DEST_DIR="${DEST_DIR:-/srv/homelab}"
DATA_DIR="/srv/homelab-data"
BRANCH="${BRANCH:-main}"
SYSTEMD_UNIT="homelab-core.service"
trap 'echo "✖ Bootstrap failed (line $LINENO)" >&2' ERR

need() { command -v "$1" >/dev/null 2>&1 || { echo "✖ $1 required"; exit 1; }; }
need git; need sudo
sudo mkdir -p "$DEST_DIR" "$DATA_DIR"

if [ ! -d "$DEST_DIR/.git" ]; then
  [[ $(ls -A "$DEST_DIR") ]] && echo "⚠️  $DEST_DIR not empty, skipping clone." || \
  sudo git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$DEST_DIR"
else
  sudo -u "$(stat -c '%U' "$DEST_DIR")" git -C "$DEST_DIR" pull --ff-only origin "$BRANCH"
fi

sudo chown -R groot:docker "$DEST_DIR" "$DATA_DIR"
sudo find "$DEST_DIR" "$DATA_DIR" -type d -exec chmod 775 {} \;
sudo chcon -Rt svirt_sandbox_file_t "$DEST_DIR" "$DATA_DIR"
/usr/bin/sudo chcon -t svirt_sandbox_file_t /var/run/docker.sock

echo "➜ Installing systemd gitpull unit + timer"
sudo cp "$DEST_DIR/systemd/homelab-gitpull.service" /etc/systemd/system/
sudo cp "$DEST_DIR/systemd/homelab-gitpull.timer" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-gitpull.timer

sudo systemctl daemon-reload
sudo systemctl enable --now "$SYSTEMD_UNIT"
echo "✔ Bootstrap complete."
