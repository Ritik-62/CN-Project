# Phase 2 — High Availability & Failover Behavior (Extension D)

## 1. Overview
High Availability (HA) ensures that a network service remains accessible and responsive even when one or more backend compute nodes experience catastrophic failure or planned maintenance.

This implementation satisfies **Extension D** of the Computer Networks project specification.

---

## 2. Upstream Configuration & Passive Health Checks
The nginx edge reverse proxy uses an upstream group configured with passive health checks:

```nginx
upstream cnproject_backends {
    server 127.0.0.1:3001 max_fails=1 fail_timeout=5s;
    server 127.0.0.1:3002 max_fails=1 fail_timeout=5s;
}
```

### Key Parameters:
- `max_fails=1`: Number of unsuccessful communication attempts with the server before it is considered unavailable.
- `fail_timeout=5s`: Time window within which failures must occur, and duration for which the server is considered unavailable before retry.
- `proxy_next_upstream error timeout invalid_header http_502 http_503`: Directs nginx to transparently re-route the request to the next upstream backend if the selected server fails or times out.
- `proxy_next_upstream_tries 2`: Limits retry attempts to avoid cascading timeouts.

---

## 3. Test Cases & Observed Behavior

Test suite: `./scripts/test_ha_failover.sh`

### CASE 1: Both Backends Healthy
- **Action**: Sent 8 consecutive requests to `https://app.cnproject.test:8443/api/status`.
- **Result**: Exactly 4 requests served by Backend A and 4 requests served by Backend B.
- **Verdict**: **PASS** — Round-robin distribution active.

### CASE 2: Backend A Stops (Zero Dropped Requests)
- **Action**: Stopped Backend A process (`kill <pid>`). Sent 5 requests immediately.
- **Result**: 5 out of 5 requests (100%) successfully handled by Backend B with HTTP 200 OK. Zero dropped requests.
- **Verdict**: **PASS** — Instantaneous failover verified.

### CASE 3: Backend A Restarts (Load Balancing Auto-Recovery)
- **Action**: Restarted Backend A. Waited 6 seconds for the 5-second `fail_timeout` window to expire. Sent 8 requests.
- **Result**: Backend A seamlessly rejoined the pool and began serving traffic alternately with Backend B.
- **Verdict**: **PASS** — Upstream re-integration verified.

### CASE 4: Backend B Stops (Failover to Backend A)
- **Action**: Stopped Backend B. Sent 5 requests.
- **Result**: 100% of requests served by Backend A.
- **Verdict**: **PASS** — Symmetric failover verified.

### CASE 5: Both Backends Stop (Controlled 502 Bad Gateway)
- **Action**: Stopped both Backend A and Backend B while nginx edge remained running.
- **Result**: nginx returned a clean `HTTP/1.1 502 Bad Gateway`.
- **Verdict**: **PASS** — Clear demonstration of where the edge ends and backend begins.

### CASE 6: Backends Recover
- **Action**: Re-launched both backends.
- **Result**: Application auto-recovered to HTTP 200 OK without rebuilding or restarting nginx.
- **Verdict**: **PASS** — Self-healing infrastructure verified.

Evidence log: [ha-failover-test.txt](../../evidence/phase-2/ha-failover-test.txt)
