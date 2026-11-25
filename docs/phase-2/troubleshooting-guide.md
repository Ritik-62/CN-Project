# Phase 2 — Layer-by-Layer Troubleshooting & Fault Playbook (Extension F)

## 1. Systematic Layer-by-Layer Diagnostic Methodology
When network failures occur, systematic deduction isolates the root cause rapidly without random restarts.

```
+-----------------------------------------------------------------------+
| LAYER 1-3 (Physical / Network) : Interface UP & IPv4 Loopback Assigned |
+-----------------------------------┬-----------------------------------+
                                    │ PASS
                                    v
+-----------------------------------------------------------------------+
| LAYER 4 (Transport)            : TCP Ports Listening (nc -z)          |
+-----------------------------------┬-----------------------------------+
                                    │ PASS
                                    v
+-----------------------------------------------------------------------+
| LAYER 5-6 (Session/Presentation: TLS Handshake, Cert Expiry & SAN     |
+-----------------------------------┬-----------------------------------+
                                    │ PASS
                                    v
+-----------------------------------------------------------------------+
| LAYER 7 (Application)          : DNS Resolution, Upstream HTTP & Cache |
+-----------------------------------------------------------------------+
```

---

## 2. Fault Matrix & Diagnostic Signatures

| Fault Scenario | Layer Affected | Symptom Observed | Diagnostic Signature | Safe Remediation Action |
|---|---|---|---|---|
| **Primary DNS Offline** | Application (DNS) | `connection timed out` on port 5355 | `nc -z 127.0.0.1 5355` fails | `./scripts/manage_dns.sh restart-primary` |
| **Wrong DNS Record** | Application (DNS) | Client connects to wrong destination | `dig` returns invalid IP | `./scripts/manage_dns.sh reset-records` |
| **Direct Backend Access** | Application (Security) | `HTTP 403 Forbidden` | `X-Isolation-Status: Blocked` | Route requests through trusted Edge |
| **One Backend Down** | Transport / App | No failure! Other backend serves | Port check fails; HTTP 200 via Edge | `./scripts/manage_services.sh start-backends` |
| **Both Backends Down** | Application (Upstream)| `HTTP 502 Bad Gateway` | Edge reachable, backends refused | `./scripts/manage_services.sh start-backends` |
| **Edge Down** | Transport / TLS | Connection refused on 8443 | `nc -z 127.0.0.1 8443` fails | `./scripts/manage_services.sh start-edges` |
| **Wrong Port** | Transport | `curl: (7) Failed to connect` | SYN sent, RST received | Connect to designated port (8443/9443)|

---

## 3. Automated Diagnostic Tooling
- **Full System Diagnostic**:
  ```bash
  ./scripts/diagnose_stack.sh
  ```
- **Controlled Fault Injection**:
  ```bash
  ./scripts/fault_manager.sh inject <fault-name>
  ```
- **Master Recovery**:
  ```bash
  ./scripts/fault_manager.sh recover-all
  ```
