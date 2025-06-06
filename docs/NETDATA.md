# Netdata Monitoring Service

## Purpose

Netdata provides real-time, high-resolution performance monitoring for the homelab host and all running Docker containers. It offers detailed insights into:

- Overall system resource utilization (CPU, memory, disk I/O, network).
- Per-container resource utilization, allowing you to drill down into specific services.
- Network traffic details.
- And much more, with hundreds of metrics collected automatically.

It's an invaluable tool for understanding system performance, troubleshooting issues, and observing the behavior of your containerized applications.

## Accessing Netdata

The Netdata web UI is accessible on port `19999` of your homelab host. If you are using Tailscale (as recommended in the main `README.md`), you can access it via:

`http://<your-homelab-host-tailscale-name>:19999`

Replace `<your-homelab-host-tailscale-name>` with the actual Tailscale name or IP address of your homelab machine.

## Configuration Details

- **Docker Service**: Netdata runs as a Docker container, defined in the main `stacks/core.yml` file.
- **Docker Metrics**: To securely access Docker container metrics (like names, status, and individual stats), Netdata is configured to use the `socket-proxy` service. This aligns with the homelab's security principle of not exposing the main Docker socket unnecessarily.
  - `DOCKER_HOST: tcp://socket-proxy:2375`
- **Host Metrics**: Netdata gains access to host-level metrics by mounting necessary system paths in read-only mode:
  - `/proc:/host/proc:ro`
  - `/sys:/host/sys:ro`
  - `/etc/passwd:/host/etc/passwd:ro,z`
  - `/etc/group:/host/etc/group:ro,z`
  - `/etc/os-release:/host/etc/os-release:ro,z`
    The `:z` flag is used on relevant volume mounts to ensure compatibility with SELinux environments (like Fedora).
- **Persistent Data**: Netdata's own configuration, historical metrics, and cache are persisted using Docker named volumes:
  - `netdataconfig:/etc/netdata`
  - `netdatalib:/var/lib/netdata`
  - `netdatacache:/var/cache/netdata`
    These volumes are managed by Docker and will persist across container restarts and updates.
- **Capabilities**: The Netdata container is granted `SYS_PTRACE` capability (essential for process monitoring) and `NET_ADMIN` (for advanced network metrics, including eBPF).
- **Updates**: Netdata will be updated automatically by Watchtower if a new image version is released, as it's part of the `core.yml` stack.

## Key Features Utilized

- **Live Dashboards**: Real-time visualization of metrics.
- **Per-Container Monitoring**: Detailed breakdown of resource usage by each Docker container.
- **Traffic Monitoring**: Insights into network traffic.
- **Low Overhead**: Netdata is designed to be extremely efficient.

## Netdata Cloud (Optional)

This setup does not automatically connect your Netdata instance to Netdata Cloud. If you wish to use Netdata Cloud for centralized dashboards, longer retention, or alerts, you would typically:

1.  Sign up at [Netdata Cloud](https://app.netdata.cloud/).
2.  Obtain a claim token.
3.  Add the following environment variables to the Netdata service definition in `stacks/core.yml`:
    ```yaml
    environment:
      # ... existing environment variables ...
      - NETDATA_CLAIM_TOKEN=YOUR_CLAIM_TOKEN
      - NETDATA_CLAIM_URLS=https://app.netdata.cloud
    ```
    Replace `YOUR_CLAIM_TOKEN` with the actual token from Netdata Cloud.

## Troubleshooting

- **Permission Denied / Cannot Access Metrics**:
  - Check `docker logs netdata` for specific errors.
  - Ensure `socket-proxy` is running and configured correctly (`docker logs socket-proxy`).
  - Verify volume mounts and SELinux labels if issues persist, though the provided configuration aims to cover this.
- **Web UI Not Accessible**:
  - Confirm the Netdata container is running: `docker ps | grep netdata`.
  - Check your firewall rules (though Tailscale should bypass local host firewalls for its traffic).
  - Ensure port `19999` is correctly mapped in `stacks/core.yml`.

This setup provides a solid foundation for monitoring your homelab. Explore the Netdata UI to discover the wealth of information it provides!
