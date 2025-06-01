# Compact Troubleshooting: Docker Socket Access for `socket-proxy` on Fedora/SELinux

This summarizes the critical steps taken to diagnose SELinux preventing `tecnativa/docker-socket-proxy` from accessing `/var/run/docker.sock` on Fedora.

**User:** `kisinga`
**Date of Troubleshooting:** `2025-06-01` (approx.)

## Core Problem:

Watchtower, configured to use `docker-socket-proxy`, failed to connect to the Docker API, resulting in 503 errors from the proxy.

## Key Diagnostic & Resolution Steps:

1.  **Symptom Confirmation:**

    - Watchtower logs showed connection errors.
    - `curl http://127.0.0.1:2375/version` (to `socket-proxy`) returned `503 Service Unavailable`.
    - `docker logs socket-proxy` showed HAProxy requests failing with `SC--` (Server Connection Aborted), indicating the proxy reached the socket but the connection was then dropped.

2.  **Isolate Docker Daemon Health:**

    - `sudo curl --unix-socket /var/run/docker.sock http://localhost/version` **WORKED**.
    - **Conclusion:** Docker daemon was healthy and socket was accessible directly on the host. Problem lay between `socket-proxy` and the socket.

3.  **Pinpoint SELinux Involvement (Crucial):**

    - **Check SELinux Audit Logs:**

      ```bash
      sudo ausearch -m avc -ts recent
      ```

      - **Finding:** Revealed `avc: denied { connectto } for pid=... comm="haproxy" path="/run/docker.sock" scontext=...container_t... tcontext=...container_runtime_t... tclass=unix_stream_socket`. This showed SELinux blocking HAProxy (in `socket-proxy`) from connecting to the Docker socket.

    - **Attempt Standard SELinux Booleans:**

      - Listed with `sudo getsebool -a | grep container`.
      - Tried `sudo setsebool -P container_connect_any 1`.
      - **Result:** Problem persisted; this boolean was insufficient for this specific interaction.

    - **Definitive SELinux Test - Permissive Mode (Temporary):**
      1.  `sudo setenforce 0` (Set SELinux to permissive).
      2.  Retested `curl http://127.0.0.1:2375/version`.
      3.  **Result:** **WORKED!** JSON output received.
      4.  `sudo setenforce 1` (Immediately set SELinux back to enforcing).
      - **Conclusion:** SELinux was definitively the sole blocker.

4.  **Solution Path (Standard SELinux Practice):**
    - Since booleans were ineffective, the correct resolution is a **Custom SELinux Policy Module**.
    - **Steps:**
      1.  Ensure SELinux is enforcing.
      2.  Trigger the denial (e.g., run the failing `curl` to `socket-proxy`).
      3.  Install `policycoreutils-python-utils`: `sudo dnf install policycoreutils-python-utils`.
      4.  Generate policy:
          ```bash
          sudo ausearch -m avc -ts recent --raw > /tmp/haproxy_avc.log
          sudo audit2allow -M haproxy_docker_sock -i /tmp/haproxy_avc.log
          ```
      5.  Install policy:
          ```bash
          sudo semodule -i haproxy_docker_sock.pp
          ```
      6.  Restart containers and verify.

## Summary of Lessons:

- For Fedora/SELinux, direct socket access or proxy access often requires SELinux adjustments.
- The `:z` or `:Z` volume mount flags are necessary but may not be sufficient.
- `ausearch` is critical for identifying specific SELinux denials.
- `setenforce 0` is invaluable for isolating SELinux as the root cause.
- If SELinux booleans fail, `audit2allow` to create a custom policy is the targeted solution.
