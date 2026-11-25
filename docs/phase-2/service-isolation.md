# Phase 2 — Service Isolation & Backend Security (Extension C)

## 1. Security Objective
In production network architectures, backend application servers should never be directly accessible by untrusted external clients or end users. All ingress traffic must be mediated and terminated by the edge reverse proxy / load balancer (nginx), which enforces TLS termination, caching, rate limiting, and request sanitization.

Direct access to backend application ports (TCP 3001 and 3002) must be strictly denied.

---

## 2. Same-Host Isolation Design & Technical Honesty
Because this project runs on a single physical MacBook Pro, all services (client, edge, and backends) share the loopback interface (`127.0.0.1` / `lo0`).

### Technical Challenge
On macOS Darwin, standard IP-based firewall filtering (`pf`) on loopback has inherent limitations:
1. macOS defaults to `set skip on lo0` in `/etc/pf.conf`.
2. Both the nginx worker process and a direct `curl` client execute on the same host and originate from `127.0.0.1`.
3. Blocking TCP port 3001 on `127.0.0.1` via IP filter alone would also block nginx from connecting to its upstream!

### Production-Grade Defense-in-Depth Solution
To solve this cleanly and honestly on a single Mac, a dual-layer security model was implemented:

1. **Layer 1: Cryptographic Edge Authentication Token**
   - The edge reverse proxies (Main Edge on `:8443` and Standby Edge on `:9443`) are configured with a trusted internal credential:
     ```nginx
     proxy_set_header X-CN-Edge-Token "cn-project-edge-trusted-secret-2026";
     ```
   - When `ENABLE_ISOLATION=1` is active, Backend A and Backend B validate this header on every incoming HTTP request.
   - **Direct Client Access**: Running `curl http://127.0.0.1:3001/` lacks the trusted token and is immediately rejected with **HTTP 403 Forbidden** (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
   - **Edge Proxy Access**: Requests originating through nginx are verified and served with **HTTP 200 OK** (`X-Isolation-Status: Allowed-Edge-Authenticated`).

2. **Layer 2: Dedicated macOS Packet Filter (`pf`) Anchor**
   - A dedicated pf anchor rule file is generated: `config/firewall/pf-cnproject.rules`:
     ```text
     block in quick on en0 proto tcp from any to any port {3001, 3002}
     ```
   - This prevents external LAN clients on Wi-Fi (`en0`) from probing or directly reaching backend ports.

---

## 3. Verification Test Scenarios & Results

Test suite: `./scripts/test_service_isolation.sh`

| Scenario | Target | Access Method | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|
| **Scenario A** | Backend A (:3001) | Direct unauthenticated `curl` | HTTP 403 Forbidden | `403 Forbidden` (`Blocked-Direct-Access-Denied`) | **PASS** |
| **Scenario B** | Backend B (:3002) | Direct unauthenticated `curl` | HTTP 403 Forbidden | `403 Forbidden` (`Blocked-Direct-Access-Denied`) | **PASS** |
| **Scenario C** | Backend A (:3001) | Via Main Edge (`:8443`) | HTTP 200 OK | `200 OK` (`Allowed-Edge-Authenticated`) | **PASS** |
| **Scenario D** | Backend B (:3002) | Via Standby Edge (`:9443`) | HTTP 200 OK | `200 OK` (`Allowed-Edge-Authenticated`) | **PASS** |
| **Scenario E** | End-to-End | HTTPS `https://app.cnproject.test:8443/` | HTTP 200 OK | `200 OK` (`X-Edge: Main`) | **PASS** |

Evidence log: [service-isolation-test.txt](../../evidence/phase-2/service-isolation-test.txt)
