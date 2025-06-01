# Watchtower: Container Monitoring & Auto-Updates

_Companion to [\*\*Baseline Stack & Architecture](./README.md)\*\*_
_Manages container image freshness and automatic restarts in the homelab stack, operating securely via `socket-proxy`._

---

## 0 · Purpose

Watchtower ensures your Docker containers stay up-to-date by:

- Polling image registries for new versions.
- Pulling newer images if available.
- Gracefully restarting affected containers with the new image.

This helps maintain a secure and evergreen self-hosted stack with minimal human intervention, while adhering to security best practices by not accessing the Docker socket directly.

---

## 1 · Setup Summary

| Component             | Value                                                            | Notes                                                        |
| --------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------ |
| **Image**             | `containrrr/watchtower:latest`                                   |                                                              |
| **Restart Policy**    | `unless-stopped`                                                 | Ensures Watchtower runs reliably.                            |
| **Docker API Access** | Via `socket-proxy` service (`tcp://socket-proxy:2375`)           | **No direct Docker socket mount.** Enhances security.        |
| **Dependency**        | `socket-proxy` service                                           | Must be running for Watchtower to connect to the Docker API. |
| **Polling Interval**  | Configured via `WATCHTOWER_POLL_INTERVAL` in `.env` (e.g., 300s) | Defines how often Watchtower checks for updates.             |

---

## 2 · Core `docker-compose.yml` Snippet (in `stacks/core.yml`)

This shows Watchtower configured to use `socket-proxy`:

```yaml
services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: socket-proxy
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:z # Proxy mounts the actual socket
    ports:
      - "127.0.0.1:2375:2375" # Expose proxy only on host's localhost
    environment:
      # Restrictive API permissions for the proxy (adjust as needed for Watchtower)
      - LOG_LEVEL=info
      - POST=0
      - PUT=0
      - DELETE=0
      - CONTAINERS=1
      - IMAGES=1
      - INFO=1
      - VERSION=1
      - EVENTS=1
      - PING=1
      # Deny others by default if not listed

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    depends_on: # Ensures socket-proxy is started first
      - socket-proxy
    env_file:
      - ../.env # For WATCHTOWER_POLL_INTERVAL, TZ, etc.
    environment:
      # Tell Watchtower to use the socket-proxy
      - DOCKER_HOST=tcp://socket-proxy:2375
      - WATCHTOWER_CLEANUP=true # Example: remove old images
    # Note: No direct 'volumes' entry for /var/run/docker.sock here!
    labels:
      # Label Watchtower itself if you want it to auto-update (optional)
      # - com.centurylinklabs.watchtower.enable=true
```

> **Important:** All other containers that you want Watchtower to manage must be labeled with `com.centurylinklabs.watchtower.enable=true`.

---

## 3 · `.env` Configuration Examples

Relevant variables for Watchtower:

```dotenv
# /srv/homelab/.env
WATCHTOWER_POLL_INTERVAL=300 # Check for updates every 5 minutes
TZ=Africa/Nairobi            # Set timezone for logs

# Optional: Notifications via Shoutrrr
# WATCHTOWER_NOTIFICATIONS=shoutrrr
# SHOUTRRR_URL=telegram://YOUR_BOT_TOKEN@YOUR_CHAT_ID
```

---

## 4 · Logging & Diagnostics

- **Watchtower Logs:**

  ```bash
  sudo docker logs watchtower
  ```

  Look for messages about connecting to `tcp://socket-proxy:2375`, finding images, or any errors.

- **Socket Proxy Logs:**
  ```bash
  sudo docker logs socket-proxy
  ```
  These logs will show API requests received from Watchtower and whether they were allowed or denied by the proxy's configuration. Also shows if `socket-proxy` itself has issues connecting to `/var/run/docker.sock`.

Common messages & issues:

| Log Output / Symptom (Watchtower)                                    | Meaning / Potential Cause                                                                                                                    |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| "Found new image for ..."                                            | Image was updated and will trigger restart.                                                                                                  |
| "No new updates found"                                               | All monitored containers are up-to-date.                                                                                                     |
| Connection errors to `socket-proxy:2375`                             | `socket-proxy` might be down, misconfigured, or network issue between containers.                                                            |
| API errors after connecting                                          | The `socket-proxy` environment variables might be too restrictive, denying a needed API call. Check `socket-proxy` logs for denied requests. |
| **Symptom (Socket Proxy):** Cannot connect to `/var/run/docker.sock` | Likely an SELinux issue on the host. See section 5.                                                                                          |

---

## 5 · SELinux Integration (Host-Level)

If running on an SELinux-enforced system (e.g., Fedora):

- **`socket-proxy` SELinux Policy:** The `socket-proxy` container requires a custom SELinux policy to allow its internal process (e.g., `haproxy`) to connect to `/var/run/docker.sock`. Refer to the detailed guide: [**Troubleshooting SELinux for Docker Socket Proxy**](./TROUBLESHOOTING_SELINUX_PROXY.md).
- **General Volume Labeling:** Ensure your main Docker directories are correctly labeled:
  ```bash
  # During initial setup or if permissions issues arise:
  sudo chcon -Rt svirt_sandbox_file_t /srv/homelab
  sudo chcon -Rt svirt_sandbox_file_t /srv/homelab-data
  ```
  The `:z` or `:Z` flag on volume mounts in `docker-compose.yml` (e.g., for `socket-proxy`'s mount of `/var/run/docker.sock`) handles relabeling for container access.

---

## 6 · GHCR & Private Registries

For Watchtower to pull images from private registries (including GHCR private repos) when using `socket-proxy`:

1.  **Docker Login on Host:** Ensure Docker on the _host machine_ is logged into the private registry:

    ```bash
    docker login ghcr.io # Or your private registry
    ```

    This stores credentials in the host's `~/.docker/config.json` (for root, it would be `/root/.docker/config.json`).

2.  **Proxy Configuration:** The `tecnativa/docker-socket-proxy` by default should leverage the host's Docker daemon credentials when accessing registries, as it's merely proxying API calls. No special volume mount for Docker config into Watchtower or the proxy is typically needed if the _host Docker daemon_ is authenticated.

3.  **Testing:** If issues persist, check `socket-proxy` and Watchtower logs for authentication errors when trying to pull from the private registry.

---

## 7 · Limitations & Considerations

- **Stateless Services Preferred:** Watchtower is best for stateless services or those that can tolerate being restarted unexpectedly.
- **No Rollback:** Does not automatically roll back a failed update.
- **Dependency Awareness:** Has limited awareness of complex inter-service dependencies defined in Docker Compose beyond `depends_on`.
- **Proxy Configuration is Key:** The security benefits depend on correctly configuring the `socket-proxy` to allow only necessary API calls.

---

## 8 · Future Improvements

- [ ] More granular per-service update strategies (e.g., via labels).
- [ ] Enhanced notification details through `socket-proxy` logging if possible.

---

## 9 · Conclusion

Using Watchtower via `socket-proxy` provides a robust and more secure method for automating container updates. It keeps your services fresh while minimizing direct exposure of the powerful Docker socket, aligning with the principle of least privilege.

_Self-updating software is convenient; doing so securely is critical._
