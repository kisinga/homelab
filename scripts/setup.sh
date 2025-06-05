#!/usr/bin/env bash
# Setup or re-deploy homelab
set -euo pipefail

REPO_URL="${REPO_URL:-git@github.com:kisinga/homelab.git}"
DEST_DIR="/srv/homelab"
DATA_DIR="/srv/homelab-data"
BRANCH="${BRANCH:-main}"

for cmd in git sudo docker; do
  command -v "$cmd" >/dev/null || { echo "✖ $cmd missing"; exit 1; }
done

echo "📦 Ensuring directories..."
sudo mkdir -p "$DEST_DIR" "$DATA_DIR"

if [ ! -d "$DEST_DIR/.git" ]; then
  echo "🔄 Cloning homelab repo..."
  sudo git clone -b "$BRANCH" "$REPO_URL" "$DEST_DIR"
fi

echo "🔧 Setting permissions and SELinux context..."
sudo chown -R groot:docker "$DEST_DIR" "$DATA_DIR"
sudo chmod -R g+w "$DEST_DIR" "$DATA_DIR"
sudo chcon -Rt svirt_sandbox_file_t "$DEST_DIR" "$DATA_DIR"
sudo chcon -t svirt_sandbox_file_t /var/run/docker.sock

echo "🔐 Ensuring scripts are executable..."
find "$DEST_DIR/scripts/" -type f -name "*.sh" -exec chmod +x {} \;

echo "🧷 Installing systemd units..."
sudo cp "$DEST_DIR/systemd/"*.service "$DEST_DIR/systemd/"*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-core.service homelab-gitpull.timer

echo "🚀 Running full deploy (core + containers)..."
bash "$DEST_DIR/scripts/deploy.sh"

echo "✅ Setup & deploy complete."
