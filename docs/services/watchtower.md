# Watchtower: Container Auto-Updates

Watchtower automatically updates running Docker containers to the latest image versions, ensuring a secure and up-to-date homelab environment.

## Configuration

- **Docker Service**: Defined in `stacks/core.yml`.
- **API Access**: Connects to the Docker API securely via the `socket-proxy` service, avoiding direct access to the Docker socket.
- **Polling Interval**: Configured with the `WATCHTOWER_POLL_INTERVAL` variable in `.env`.
- **Container Selection**: Watchtower only updates containers with the label `com.centurylinklabs.watchtower.enable=true`.

## Reasoning

- **Security**: Using `socket-proxy` as an intermediary for Docker API access is a key security decision. It prevents the Watchtower container from having direct, privileged access to the Docker daemon, reducing the potential impact of a compromised container.
- **Controlled Updates**: The use of labels for enabling updates gives granular control over which containers are automatically updated. This is crucial for stateful or critical services where unexpected restarts could cause issues.

## Private Registries (e.g., GHCR)

To pull images from private registries, log in to the registry on the homelab host:

```bash
docker login ghcr.io
```

Watchtower, via `socket-proxy`, will use the host's Docker credentials.

## Troubleshooting

- **Check Logs**:
  - `docker logs watchtower`: For update status and connection errors.
  - `docker logs socket-proxy`: For API request and permission issues.
- **SELinux**: If `socket-proxy` has issues connecting to `/var/run/docker.sock`, a custom SELinux policy may be required. Refer to the `troubleshooting/selinux.md` guide for details.
- **Permissions**: If Watchtower has API errors, the `socket-proxy` environment variables in `stacks/core.yml` may be too restrictive.
