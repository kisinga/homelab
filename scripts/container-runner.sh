#!/usr/bin/env bash
set -euo pipefail

for file in /srv/containers/*; do
  case "$file" in
    *.yml)
      /usr/bin/docker compose \
        --env-file /srv/.env \
        --project-directory /srv/containers \
        -f "$file" up -d
      ;;
    *.sh)
      bash "$file"
      ;;
  esac
done
