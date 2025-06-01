# Watchtower Monitoring & Auto-Updates

_Companion to [**Baseline Stack & Architecture**](./README.md)_
_Manages container image freshness and automatic restarts in the homelab stack._

---

## 0 · Purpose

Watchtower ensures all containers stay up-to-date by:

- Polling image registries
- Pulling newer versions
- Restarting affected containers

This helps maintain a secure and evergreen self-hosted stack with minimal human intervention.

---

## 1 · Setup Summary

| Component   | Value                                 |
| ----------- | ------------------------------------- |
| **Image**   | `containrrr/watchtower:latest`        |
| **Restart** | `unless-stopped`                      |
| **Socket**  | `/var/run/docker.sock` (bind-mounted) |
| **Polling** | Every 5 minutes (via `.env` file)     |

---

## 2 · Core `docker-compose` Snippet

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    env_file:
      - ../.env
    environment:
      - WATCHTOWER_CLEANUP=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - com.centurylinklabs.watchtower.enable=true
```

> All managed containers must be labeled with `com.centurylinklabs.watchtower.enable=true` to be tracked.

---

## 3 · `.env` Configuration

```dotenv
WATCHTOWER_POLL_INTERVAL=300
TZ=Africa/Nairobi
```

You may also add:

```dotenv
WATCHTOWER_NOTIFICATIONS=shoutrrr
SHOUTRRR_URL=telegram://... (or other provider)
```

---

## 4 · Logging & Diagnostics

View logs:

```bash
docker logs watchtower
```

Common messages:

| Log Output                        | Meaning                                    |
| --------------------------------- | ------------------------------------------ |
| "Found new image for ..."         | Image was updated and will trigger restart |
| "No new updates found"            | All containers up-to-date                  |
| "Cannot access registry"          | Auth or network issue                      |
| "Permission denied" (docker.sock) | Fix with SELinux relabel                   |

---

## 5 · SELinux Integration

If running on SELinux (e.g., Fedora):

```bash
sudo chcon -t svirt_sandbox_file_t /var/run/docker.sock
```

Also apply recursively on `/srv/homelab` and `/srv/homelab-data`:

```bash
sudo chcon -Rt svirt_sandbox_file_t /srv/homelab /srv/homelab-data
```

---

## 6 · GHCR & Private Registries

If Watchtower is not pulling images hosted on GitHub Container Registry (GHCR):

- Check if the repo is public
- If private, configure Docker auth:

```bash
cat ~/.docker/config.json
```

You may need to:

```bash
docker login ghcr.io
```

And mount your Docker config:

```yaml
volumes:
  - ~/.docker:/config/.docker
```

Then set:

```dotenv
WATCHTOWER_DOCKER_CONFIG=/config/.docker
```

---

## 7 · Limitations

- Does not rollback failed container updates
- No native health check retry logic
- Does not validate Compose service dependencies

Use Watchtower **only** for stateless services or those you can tolerate restarting blindly.

---

## 8 · Future Improvements

- [ ] Replace with custom update handler per `.labels`
- [ ] Add retry + healthcheck monitor wrapper
- [ ] Support `watchtower.yml` override for exceptions
- [ ] Log to syslog or notify via Shoutrrr

---

## 9 · Conclusion

Watchtower is a simple but powerful tool to:

- Keep containers fresh
- Minimize SSH-ing for updates
- Enable a true GitOps + imageOps hybrid model

Still, for mission-critical services, consider layering with health checks or canary patterns.

_Self-updating software is great—until it isn't. Use with awareness._
