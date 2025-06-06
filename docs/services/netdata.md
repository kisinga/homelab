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

Adding custom configuration to Netdata requires a careful approach to avoid permission issues with its Docker volume. The following method ensures that custom config files are correctly loaded without interfering with the container's startup process.

This example demonstrates how to add a custom `fping.conf` to monitor latency for specific hosts.

### Step 1: Create the Local Configuration File

1.  Create your custom configuration file inside the repository. For Netdata configurations, a good practice is to keep them organized. For this example, we use `stacks/netdata/config/fping.conf`.
2.  Add your desired configuration. For `fping.conf`, you can list hosts to ping:

    ```
    # stacks/netdata/config/fping.conf
    hosts: 8.8.8.8 1.1.1.1
    ```

### Step 2: Update Docker Compose Service

To load this file, you must modify the `netdata` service in `stacks/core.yml`.

1.  **Mount the File to a Temporary Location**: Mount your local config file to a temporary path inside the container, like `/tmp/fping.conf`. This avoids direct permission conflicts with the `/etc/netdata` volume.

2.  **Override the Entrypoint**: The Netdata image's default entrypoint needs to be overridden to copy the file into place before the service starts. This ensures the file has the correct ownership (`netdata:netdata`) inside the container.

The updated service definition in `stacks/core.yml` will look like this:

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
```

### Step 3: Restart the Stack

After saving the changes, restart the Docker stack. Netdata will start with your custom monitoring active.
