#!/usr/bin/env bash
set -euo pipefail

echo "🔁 Running container-runner.sh..."

for file in /srv/containers/*; do
  case "$file" in
    *.yml)
      echo "🧱 Launching stack: $file"
      docker compose --env-file /srv/homelab/.env -f "$file" up -d
      ;;
    *.sh)
      echo "🚀 Executing custom script: $file"
      bash "$file"
      ;;
    *)
      echo "⚠️ Skipping unrecognized file: $file"
      ;;
  esac
done

echo "✅ All container definitions processed."
