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

## Adding Custom Configuration

Adding custom configuration to Netdata requires two steps: ensuring the necessary collector is installed in the container, and providing the configuration file.

This example demonstrates how to add the `fping` collector to monitor latency for specific hosts.

### Step 1: Install the Collector Package

The official Netdata container is modular and does not include all collector binaries by default. You can instruct it to install packages at startup using an environment variable.

In `stacks/core.yml`, add the `NETDATA_EXTRA_DEB_PACKAGES` environment variable to the `netdata` service, specifying any packages you need.

```yaml
# ...
netdata:
  image: netdata/netdata:latest
  # ... other settings
  volumes:
    # ... other volumes
    # Custom fping configuration, mounted to a temporary location
    - ./netdata/config/fping.conf:/tmp/fping.conf:ro
    # Netdata persistent data volumes with SELinux labels
    - netdataconfig:/etc/netdata:Z
    - netdatalib:/var/lib/netdata:Z
    - netdatacache:/var/cache/netdata:Z
  # Override the entrypoint to copy config and then run original script
  entrypoint:
    - /bin/sh
    - -c
    - "cp /tmp/fping.conf /etc/netdata/fping.conf && chown netdata:netdata /etc/netdata/fping.conf && /usr/sbin/run.sh"
  # ... rest of the service definition
  environment:
    # Add fping package at runtime using the official method
    - NETDATA_EXTRA_DEB_PACKAGES=fping
    # ... other environment variables
```

### Step 2: Provide the Configuration File

1.  Create your custom configuration file inside the repository. For this example, we use `stacks/netdata/config/fping.conf`.

    ```
    # stacks/netdata/config/fping.conf
    hosts: 8.8.8.8 1.1.1.1
    ```

2.  Mount this file directly into the appropriate subdirectory in Netdata's configuration volume. For the `fping` collector, the correct path is `/etc/netdata/fping.d/fping.conf`. Mounting to a subdirectory avoids the permission conflicts that can happen in the root `/etc/netdata` directory.

The updated `volumes` section in `stacks/core.yml` will look like this:

```yaml
# ...
volumes:
  # ... other volumes
  # Custom fping configuration, mounted directly to the collector's config directory
  - ./netdata/config/fping.conf:/etc/netdata/fping.d/fping.conf:ro
  # Netdata persistent data volumes with SELinux labels
  - netdataconfig:/etc/netdata:Z
  - netdatalib:/var/lib/netdata:Z
  - netdatacache:/var/cache/netdata:Z
# ... rest of the service definition
```

### Step 3: Restart the Stack

After saving the changes, restart the Docker stack. Netdata will install the `fping` package and then load your `fping.conf`, activating the new charts in the UI.
