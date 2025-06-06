# Netdata Monitoring

Netdata provides real-time, high-resolution performance monitoring for the homelab host and all running Docker containers.

## Accessing Netdata

The Netdata web UI is accessible on port `19999` of your homelab host.

`http://<your-homelab-host-tailscale-name>:19999`

## Configuration

- **Docker Service**: Defined in `stacks/core.yml`.
- **Metrics**:
  - Securely accesses Docker metrics via the `socket-proxy` service.
  - Host-level metrics are accessed via read-only volume mounts of system paths.
- **Persistent Data**: Uses Docker named volumes for configuration and historical data.
- **Capabilities**: Granted `SYS_PTRACE` and `NET_ADMIN` for comprehensive monitoring.
- **Updates**: Automatically updated by Watchtower.

## Reasoning

The Netdata setup is designed with security and simplicity in mind:

- **Socket Proxy**: Instead of exposing the main Docker socket, Netdata uses a dedicated, secure proxy (`socket-proxy`) to access container metrics. This minimizes the attack surface.
- **SELinux Compatibility**: Volume mounts use the `:z` flag to ensure compatibility with SELinux, which is used in this homelab's environment (Fedora).
- **Read-Only Host Access**: Host system paths are mounted as read-only to prevent Netdata from accidentally modifying host files.

## Netdata Cloud (Optional)

To use Netdata Cloud for centralized dashboards and alerts, add your claim token to the service definition in `stacks/core.yml`. See the [Netdata Cloud docs](https://learn.netdata.cloud/docs/agent/claim) for more details.

## Troubleshooting

- Check `docker logs netdata` for errors.
- Ensure the `socket-proxy` service is running.
- Verify the container is running: `docker ps | grep netdata`.
- Check firewall rules if the UI is not accessible.
