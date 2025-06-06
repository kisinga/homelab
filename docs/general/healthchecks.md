# Adding Health Checks to Services

All long-running services in this homelab should have a `healthcheck` defined in their Docker Compose configuration. Health checks allow Docker and monitoring tools like Netdata to accurately report the status of a service, making the entire system more reliable and easier to troubleshoot.

A container's health status will be one of:

- `starting`: The container is initializing and the health check grace period (`start_period`) has not passed.
- `healthy`: The health check is consistently passing.
- `unhealthy`: The health check has failed more than the configured number of `retries`.

## The Generic Plan

Adding a health check to any service involves three main steps:

### Step 1: Identify the Service and Check Tool

First, determine what kind of service the container provides to choose the right tool.

- **Web Service / HTTP API:** The best tools are `curl` or `wget`.
- **Database:** Use the database's native client (e.g., `pg_isready` for PostgreSQL, `mysqladmin ping` for MySQL).
- **Other TCP Service:** A simple `netcat` (`nc`) can check if a port is open.
- **Any Other Process:** As a last resort, `pgrep` or a similar tool can check if the main process is running.

**Crucially, you must verify which tool is actually available inside the container.** Many official images are minimal and may not include `curl`. If a check fails with a "command not found" error, switch to a more lightweight alternative like `wget`.

### Step 2: Choose the Right Endpoint/Target

- **For Web Services:** The most reliable target is the **container's own name**, not `localhost`. For example, a container with `container_name: myservice` should be checked with `curl http://myservice`. Docker's internal DNS ensures this name resolves correctly _inside the container_. `localhost` may not work if the application only binds to its public network interface.
- **For Dedicated Health Endpoints:** Always prefer a dedicated health endpoint like `/health`, `/_ping`, or `/api/v1/info` over just checking the root (`/`). These are designed to be lightweight and provide a clear status.

### Step 3: Construct the `healthcheck` Block

Add the following block to the service in its `docker-compose.yml`:

```yaml
healthcheck:
  # Use CMD-SHELL for commands with pipes (||) or shell logic.
  # Use CMD for direct executable calls.
  test:
    [
      "CMD-SHELL",
      "wget --no-verbose --spider http://container-name:port/health || exit 1",
    ]
  interval: 1m # How often to run the check.
  timeout: 10s # How long to wait for a response.
  retries: 3 # How many consecutive failures mark it as unhealthy.
  start_period: 60s # Grace period on startup.
```

- The `test` command **must** exit with code `0` for success and `1` for failure. The `-f` flag for `curl` and the `--spider` flag for `wget` are essential for this.
- The `|| exit 1` is a critical safeguard that ensures the check fails if the tool itself (e.g., `wget`) is not found or fails unexpectedly.

## Examples from the Core Stack

### Watchtower (Built-in Check)

Watchtower provides a dedicated argument for its health check, which is the most reliable method.

```yaml
# stacks/core.yml
services:
  watchtower:
    # ...
    healthcheck:
      test: ["CMD", "/watchtower", "--health-check"]
      # ...
```

### Netdata (API Endpoint)

Netdata exposes a standard `/api/v1/info` endpoint. The `netdata/netdata` image contains `curl`.

```yaml
# stacks/core.yml
services:
  netdata:
    # ...
    healthcheck:
      test:
        ["CMD-SHELL", "curl -f http://localhost:19999/api/v1/info || exit 1"]
      # ...
```

### Socket Proxy (`wget` Fallback)

The `tecnativa/docker-socket-proxy` image is minimal and does not contain `curl`, so `wget` is used instead to query the Docker API's `/_ping` endpoint.

```yaml
# stacks/core.yml
services:
  socket-proxy:
    # ...
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget --no-verbose --spider http://localhost:2375/_ping || exit 1",
        ]
      # ...
```
