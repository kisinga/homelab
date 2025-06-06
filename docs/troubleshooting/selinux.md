# Troubleshooting: SELinux and Docker Socket Proxy

This guide provides steps to diagnose and resolve SELinux issues that prevent containers from accessing the Docker socket (`/var/run/docker.sock`), a common problem when using services like `tecnativa/docker-socket-proxy`.

## The Problem

A container (like `socket-proxy`) needs to communicate with the Docker daemon via its socket, but SELinux, by default, denies this cross-domain communication for security reasons.

**Symptoms:**

- A client service (e.g., Watchtower) gets connection errors when trying to use the proxy.
- The proxy container's logs show errors like "connection refused" or "permission denied" when trying to connect to `/var/run/docker.sock`.

## Diagnosis

1.  **Confirm Docker is Healthy**:
    Verify that the Docker socket is accessible from the host. If this command succeeds, Docker is not the problem.

    ```bash
    sudo curl --unix-socket /var/run/docker.sock http://localhost/version
    ```

2.  **Check SELinux Logs**:
    This is the most critical step. Look for `avc: denied` messages in the audit log.

    ```bash
    sudo ausearch -m avc -ts recent
    ```

    You are looking for a denial related to your proxy container's process (e.g., `comm="haproxy"`) trying to `connectto` the Docker socket.

3.  **Temporarily Set Permissive Mode (for diagnosis only)**:
    If you suspect SELinux, you can temporarily switch it to permissive mode.
    ```bash
    sudo setenforce 0
    ```
    If the service now works, SELinux is confirmed as the cause. **Immediately re-enable enforcing mode**:
    ```bash
    sudo setenforce 1
    ```
    **Do not leave your system in permissive mode.**

## Solution: Create a Custom SELinux Policy

The recommended solution is to create a custom SELinux policy module that specifically allows the proxy container to connect to the Docker socket.

1.  **Generate the Policy**:
    First, ensure `policycoreutils-python-utils` is installed.

    ```bash
    sudo dnf install policycoreutils-python-utils -y
    ```

    Then, use `audit2allow` to generate a policy from the denial message you found earlier.

    ```bash
    sudo ausearch -m avc -ts recent --raw | sudo audit2allow -M my_socket_proxy_policy
    ```

    This creates a Type Enforcement file (`.te`) and a compiled Policy Package (`.pp`). You can inspect the `.te` file to see the `allow` rule being created.

2.  **Install the Policy**:
    Install the new policy module using `semodule`.

    ```bash
    sudo semodule -i my_socket_proxy_policy.pp
    ```

3.  **Restart Services**:
    Restart the proxy container and any services that depend on it. They should now function correctly.

**Note**: The `:z` or `:Z` flags on volume mounts in a `docker-compose.yml` file are important for setting the correct file labels, but they do not grant the process permissions to perform actions that are denied by an active policy. A custom policy is often still required.

## SELinux and Persistent Docker Volumes

Another common issue on SELinux-hardened systems like Fedora involves permissions for Docker's named volumes, which are used for persistent data.

### The Problem

A container fails to start, and its logs show permission errors when trying to write to a directory that is backed by a named volume.

**Symptoms:**

- `Permission denied` errors during container startup.
- Errors like `cp: preserving times for '/path/to/dir': Permission denied`.

This occurs because the directory created by Docker on the host for the named volume does not have the correct SELinux label. The container's process is therefore denied write access by the SELinux policy.

### The Solution: Use the `:Z` Relabeling Flag

The solution is to instruct Docker to apply the correct SELinux label to the volume when it is mounted. This is done by appending `:Z` to the volume definition in your `docker-compose.yml`.

- **`:z` (lowercase)**: Use for a **shared volume**, accessible by multiple containers.
- **`:Z` (uppercase)**: Use for a **private, unshared volume**.

**Example:**

If a Netdata container cannot write to its configuration volume, modify the service definition as follows:

```yaml
services:
  netdata:
    # ...
    volumes:
      # Relabel the named volume to be private to this container
      - netdataconfig:/etc/netdata:Z
      - netdatalib:/var/lib/netdata:Z
      - netdatacache:/var/cache/netdata:Z
```

This ensures the container has the necessary permissions to read and write to its own persistent data directories, resolving the startup errors.
