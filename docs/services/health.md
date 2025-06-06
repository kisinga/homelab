# Service Health Monitoring

This document provides a guide on how to configure Netdata to perform health checks on various services in the homelab.

## Using Netdata for Health Checks

Netdata can be configured to monitor the health of any web service by using the `go.d/httpcheck` collector. This is useful for ensuring that services are not only running, but are also responsive.

### Example: Health Check for a Web Service

This example shows how to configure a health check for a hypothetical service named `my-app` that exposes a `/health` endpoint.

1.  **Create a Configuration File:**

    Create a file named `httpcheck.conf` in `stacks/netdata/config/`.

    ```yaml
    # stacks/netdata/config/httpcheck.conf
    jobs:
      - name: my_app_health
        url: http://my-app:8080/health
        timeout: 1000
        interval: 10
    ```

    - `name`: A unique name for the monitoring job.
    - `url`: The URL to check. Use the Docker service name for host.
    - `timeout`: How long to wait for a response in milliseconds.
    - `interval`: How often to perform the check in seconds.

2.  **Mount the Configuration in `core.yml`:**

    In `stacks/core.yml`, mount the `httpcheck.conf` file into the Netdata container.

    ```yaml
    # stacks/core.yml
    services:
      netdata:
        # ... other settings
        volumes:
          # ... other volumes
          - ./netdata/config/httpcheck.conf:/etc/netdata/go.d/httpcheck.conf:ro
        # ... rest of the service definition
    ```

3.  **Restart the Stack:**

    After saving the changes, restart the Docker stack. Netdata will automatically pick up the new configuration and start monitoring the health of `my-app`. The results will be visible in the Netdata UI under the "httpcheck" section.

## Using `wget` for Health Checks

The Netdata Docker image is minimal and does not include tools like `curl`. If you need to write health checks directly in your `docker-compose.yml` files (outside of Netdata's collectors), use `wget`.

### Example `wget` Health Check

```yaml
# In your docker-compose.yml for a specific service
services:
  my-other-app:
    # ...
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget --no-verbose --spider http://localhost:80/ping || exit 1",
        ]
      interval: 1m
      timeout: 10s
      retries: 3
```
