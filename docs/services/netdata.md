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

## Adding Collectors

Adding new collectors to Netdata is a straightforward process of providing a configuration file and ensuring any required packages are installed.

This example demonstrates how to add the `ping` collector to monitor latency for specific hosts. For more advanced health checking (e.g., for web services), see the [Health Monitoring](./health.md) guide.

### Step 1: Provide a Configuration File

First, create a configuration file for the collector you want to add. In this case, we'll configure the `ping` collector.

Create a file named `ping.conf` in `stacks/netdata/config/`.

```yaml
# stacks/netdata/config/ping.conf
jobs:
  - name: google_dns
    host: 8.8.8.8
  - name: cloudflare_dns
    host: 1.1.1.1
```

### Step 2: Mount the Configuration and Install Packages

Next, update the `netdata` service definition in `stacks/core.yml` to mount the new configuration file and install any necessary packages.

The `ping` collector requires the `iputils-ping` package. We can instruct Netdata to install this at startup using the `NETDATA_EXTRA_DEB_PACKAGES` environment variable.

The updated service definition will look like this:

```yaml
# stacks/core.yml
services:
  netdata:
    # ...
    volumes:
      # ... other volumes
      # Mount the custom ping configuration
      - ./netdata/config/ping.conf:/etc/netdata/go.d/ping.conf:ro
      - netdataconfig:/etc/netdata:Z
      - netdatalib:/var/lib/netdata:Z
      - netdatacache:/var/cache/netdata:Z
    environment:
      # Install the iputils-ping package for the ping collector
      - NETDATA_EXTRA_DEB_PACKAGES=iputils-ping
      # ... other environment variables
    # ...
```

### Step 3: Restart the Stack

After saving the changes, restart the Docker stack. Netdata will install the `iputils-ping` package and then load your `ping.conf`, activating the new latency monitoring charts in the UI.
