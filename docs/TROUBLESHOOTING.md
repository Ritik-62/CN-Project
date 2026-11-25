# Troubleshooting Guide & Layer-by-Layer Playbook

## 1. Systematic Layer-by-Layer Diagnostic Workflow

When troubleshooting network incidents, avoid random component restarts. Follow the standard bottom-up OSI/TCP stack hierarchy:

```
Step 1: Layer 1-3 (Physical / Network)  --> Check lo0 interface and IPv4 loopback binding.
Step 2: Layer 4   (Transport)           --> Test TCP socket listening states (nc -z).
Step 3: Layer 5-6 (Session/Presentation)--> Verify TLS handshake, SAN match, and cert expiration.
Step 4: Layer 7   (Application)         --> Verify DNS resolution, upstream response, and HTTP headers.
```

---

## 2. Automated Diagnostic Scanner
Execute the integrated diagnostic scanner:
```bash
./scripts/diagnose_stack.sh
```
The script validates all 7 layers sequentially and outputs root-cause analysis with actionable remediation commands.

---

## 3. Failure Signature & Recovery Matrix

### Scenario 1: Primary DNS Unreachable
- **Layer**: Layer 7 (Application - DNS) / Layer 4 (Transport)
- **Symptom**: `connection timed out; no servers could be reached` when querying port 5355.
- **Diagnostic Command**:
  ```bash
  nc -z 127.0.0.1 5355 || echo "Port 5355 Down"
  ```
- **Remediation**:
  ```bash
  ./scripts/manage_dns.sh restart-primary
  ```

### Scenario 2: Backend A Outage
- **Layer**: Layer 7 (Application Tier)
- **Symptom**: Port 3001 connection refused, but client HTTPS requests continue succeeding via Backend B (`X-Backend: B`).
- **Diagnostic Command**:
  ```bash
  curl -s http://127.0.0.1:3001/health || echo "Backend A Unresponsive"
  ```
- **Remediation**:
  ```bash
  ./scripts/manage_services.sh start-backends
  ```

### Scenario 3: Complete Backend Outage (HTTP 502 Bad Gateway)
- **Layer**: Layer 7 (Upstream Gateway Failure)
- **Symptom**: Client receives `HTTP/1.1 502 Bad Gateway` from nginx.
- **Root Cause**: Both Backend A (:3001) and Backend B (:3002) are down. Nginx terminates TLS successfully but has no reachable upstream nodes.
- **Remediation**:
  ```bash
  ./scripts/manage_services.sh start-backends
  ```

### Scenario 4: Direct Backend Access Denied (403 Forbidden)
- **Layer**: Layer 7 (Security Policy)
- **Symptom**: `curl http://127.0.0.1:3001/` returns `HTTP 403 Forbidden` (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
- **Explanation**: Expected behavior under Extension C. Direct access is intentionally blocked by the Service Isolation policy. Clients must route through the edge reverse proxy.

### Scenario 5: Edge Port Connection Refused
- **Layer**: Layer 4 (Transport)
- **Symptom**: `curl: (7) Failed to connect to app.cnproject.test port 8443`.
- **Root Cause**: Main Edge nginx process has halted.
- **Remediation**:
  ```bash
  ./scripts/manage_services.sh start-edges
  # Or failover to Standby Edge:
  ./scripts/manage_dns.sh set-record 127.0.0.2
  ```

---

## 4. Master Recovery Command
To instantly restore all services, reload DNS records, and clear all failure states:
```bash
./scripts/fault_manager.sh recover-all
```
