# Private Network Service Platform (Phase 1 & Phase 2)

## Computer Networks Course Project

> **"The application stays simple — the network is the project."**

This project is an empirical implementation and evaluation of a hardened, multi-tier private network service platform. Rather than building complex application business logic, this platform implements decoupled networking infrastructure to demonstrate what happens across every layer of the protocol stack when a client accesses a private domain service.

All services operate on **ONE physical Apple Silicon MacBook Pro**, simulating a four-machine network topology through decoupled, isolated daemon processes and loopback socket bindings.

---

## 1. Project Overview & Problem Statement
A simple request such as:
```text
https://app.cnproject.test:8443/api/status
```
traverses an intricate chain of network protocol layers:
```text
Domain Name (app.cnproject.test)
     ↓
DNS Resolution (Primary / Backup Failover / Caching Resolver)
     ↓
TCP Three-Way Handshake (SYN → SYN/ACK → ACK)
     ↓
TLS 1.3 Negotiation (ClientHello, SNI, ServerHello, Certificate Validation)
     ↓
HTTPS Request (Encrypted Application Data)
     ↓
Edge Reverse Proxy (nginx with Service Isolation Token Injection)
     ↓
Load Balancing (Passive Health Checks & Failover Routing)
     ↓
Backend Compute Service (Backend A or Backend B)
     ↓
HTTP Response (Custom Headers: X-Edge, X-Backend, X-Cache-Status)
     ↓
TCP Connection Teardown (FIN/ACK)
```

In production networks, systems that work under ideal conditions often collapse when faults occur. Phase 1 established the baseline request flow; **Phase 2 hardens the platform**, eliminating single points of failure, enforcing service isolation, demonstrating DNS TTL expiration, enabling standby edge migration, and providing an automated diagnostic engine.

---

## 2. Logical Architecture & Single-Mac Simulation

The course project topology defines four machine roles. On our single physical Mac, these roles are simulated via independent processes, distinct ports, dedicated configuration files, and separate PID/log files:

```
+---------------------------------------------------------------------------------------------------------+
|                                    PHYSICAL WORKSTATION: APPLE SILICON MACBOOK                          |
|                                                                                                         |
|  +----------------------------------+                   +--------------------------------------------+  |
|  |     MACHINE 1: DNS SUBSYSTEM     |                   |       MACHINE 2: MAIN EDGE (REVERSE PROXY) |  |
|  |                                  |                   |                                            |  |
|  |  [Primary Authoritative DNS]     |                   |  [nginx Reverse Proxy / Load Balancer]     |  |
|  |  Socket: 127.0.0.1:5355          |                   |  HTTPS Socket: 127.0.0.1:8443 (TLS Term.)  |  |
|  |  TTL: 30 seconds                 |                   |  HTTP Socket:  127.0.0.1:8080              |  |
|  |                                  |                   |  Response Header: X-Edge: Main             |  |
|  |  [Backup Authoritative DNS]      |                   +---------------------+----------------------+  |
|  |  Socket: 127.0.0.1:5354          |                                         |                         |
|  |  TTL: 30 seconds                 |                                         | Upstream Proxying       |
|  |                                  |                                         | (Passive Health Checks) |
|  |  [Local Caching Resolver]        |                                         v                         |
|  |  Socket: 127.0.0.1:5356          |                   +--------------------------------------------+  |
|  |  Cache Size: 150 entries         |                   |           UPSTREAM BACKEND TIER            |  |
|  +----------------------------------+                   |                                            |  |
|                                                         |  +--------------------------------------+  |  |
|                                                         |  |      MACHINE 3: BACKEND SERVER A     |  |  |
|                                                         |  |  Socket: 127.0.0.1:3001              |  |  |
|                                                         |  |  Identity: X-Backend: A              |  |  |
|                                                         |  |  Policy: Service Isolation Token     |  |  |
|                                                         |  +--------------------------------------+  |  |
|                                                         |                                            |  |
|  +----------------------------------+                   |  +--------------------------------------+  |  |
|  |      MACHINE 4: STANDBY EDGE     |                   |  |      MACHINE 4: BACKEND SERVER B     |  |  |
|  |                                  |                   |  Socket: 127.0.0.1:3002              |  |  |
|  |  [Standby nginx Reverse Proxy]   |                   |  Identity: X-Backend: B              |  |  |
|  |  HTTPS Socket: 127.0.0.1:9443    |                   |  Policy: Service Isolation Token     |  |  |
|  |  Response Header: X-Edge: Standby|                   |  +--------------------------------------+  |  |
|  +----------------------------------+                   +--------------------------------------------+  |
+---------------------------------------------------------------------------------------------------------+
```

---

## 3. Technology Stack & Port Allocation Table

### Technology Stack
- **Operating System**: macOS Darwin (Apple Silicon arm64)
- **Authoritative & Caching DNS**: `dnsmasq` version 2.93
- **Edge Reverse Proxy & Load Balancer**: `nginx` version 1.31.6
- **Packet Capture & Inspection**: `TShark` / `Wireshark` version 4.6.9
- **Backend Application Services**: Python 3.11+ standard library (`http.server`)
- **Certificates & TLS**: OpenSSL 3.x (Self-signed CA with SAN extension)

### Port Allocation Reference

| Role / Identifier | Logical Node | Protocol | Port | Description | Health Command |
|---|---|---|---|---|---|
| **Primary DNS** | Machine 1 | UDP/TCP | `5355` | Authoritative Primary DNS (TTL=30) | `dig @127.0.0.1 -p 5355 app.cnproject.test` |
| **Backup DNS** | Machine 1 | UDP/TCP | `5354` | Authoritative Backup DNS (TTL=30) | `dig @127.0.0.1 -p 5354 app.cnproject.test` |
| **Caching Resolver** | Machine 1 | UDP/TCP | `5356` | Local Caching Forwarder | `dig @127.0.0.1 -p 5356 app.cnproject.test` |
| **Main Edge HTTPS** | Machine 2 | TCP | `8443` | Primary Reverse Proxy (TLS Term.) | `curl -k https://127.0.0.1:8443/api/status` |
| **Main Edge HTTP** | Machine 2 | TCP | `8080` | Primary Cleartext Proxy | `curl http://127.0.0.1:8080/api/status` |
| **Standby Edge HTTPS** | Machine 4 | TCP | `9443` | Standby Reverse Proxy (TLS Term.) | `curl -k https://127.0.0.1:9443/api/status` |
| **Standby Edge HTTP** | Machine 4 | TCP | `9080` | Standby Cleartext Proxy | `curl http://127.0.0.1:9080/api/status` |
| **Backend Server A** | Machine 3 | TCP | `3001` | Application Server Node A | `curl http://127.0.0.1:3001/health` |
| **Backend Server B** | Machine 4 | TCP | `3002` | Application Server Node B | `curl http://127.0.0.1:3002/health` |
| **NOC Dashboard** | Host | TCP | `8000` | Real-time Operations Dashboard | `http://127.0.0.1:8000/` |

---

## 4. Phase 2 Hardening Extensions

### Extension A: Redundant Backup DNS Resolver
- **Mechanics**: Runs independent Primary (`:5355`) and Backup (`:5354`) `dnsmasq` instances with synchronized authoritative records.
- **Client Failover**: `scripts/dns_client_resolver.sh` enforces query ordering (Primary first, 1s timeout, failover to Backup upon timeout/failure).
- **Verification**: Stopping Primary DNS results in zero dropped queries; client seamlessly resolves via Backup. Real pcap saved to `evidence/phase-2/backup-dns-failover.pcapng`.

### Extension B: DNS TTL & Caching Resolver
- **Mechanics**: Authoritative responses return `local-ttl=30`. A local caching resolver (`:5356`) stores responses and decrements TTL over time.
- **Eventual Consistency Demonstration**: When authoritative records change from `127.0.0.1` to `127.0.0.2`, the caching resolver continues serving the old IP until the 30s TTL timer expires. Manual SIGHUP flush demonstrates immediate cache invalidation.
- **Verification**: `scripts/test_dns_ttl.sh` verifies TTL countdown, stale cache retention, expiration, and manual flushing. Packet capture: `evidence/phase-2/dns-ttl-capture.pcapng`.

### Extension C: Service Isolation & Backend Security
- **Mechanics**: On a single Mac, loopback IP filtering cannot differentiate between local client curl processes and nginx proxy workers. We implemented an application-layer defense-in-depth model:
  - Edge proxies inject an authenticated header `X-CN-Edge-Token`.
  - Backends reject direct client access (`http://127.0.0.1:3001/`) with **HTTP 403 Forbidden** (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
  - Edge-proxied requests (`https://app.cnproject.test:8443/`) are authenticated and return **HTTP 200 OK** (`X-Isolation-Status: Allowed-Edge-Authenticated`).
- **Verification**: `scripts/test_service_isolation.sh` verifies all 5 required access control scenarios.

### Extension D: Upstream High Availability & Failover
- **Mechanics**: Configured nginx passive health checks:
  ```nginx
  upstream cnproject_backends {
      server 127.0.0.1:3001 max_fails=1 fail_timeout=5s;
      server 127.0.0.1:3002 max_fails=1 fail_timeout=5s;
  }
  proxy_next_upstream error timeout invalid_header http_502 http_503;
  proxy_next_upstream_tries 2;
  ```
- **Verification**:
  - Backend A halted: 100% of requests routed to Backend B with zero dropped requests.
  - Backend A restarted: After 5s `fail_timeout`, load balancing auto-resumes.
  - Both backends halted: Controlled `HTTP 502 Bad Gateway` returned.
  - Backends restarted: Self-healing auto-recovery.

### Extension E: Controlled Edge Migration (Standby Edge)
- **Mechanics**: Standby nginx proxy deployed on port 9443 emitting header `X-Edge: Standby` (Main Edge emits `X-Edge: Main`).
- **Verification**: DNS cutover via `manage_dns.sh set-record 127.0.0.2` migrates traffic to Standby Edge. Rollback cleanly restores Main Edge.

### Extension F: Troubleshooting & Diagnostic Engine
- **Mechanics**: `scripts/diagnose_stack.sh` inspects Layer 1-3 (Interfaces), Layer 4 (Ports), Layer 5-6 (TLS & Certificates), and Layer 7 (DNS & HTTP applications), providing root-cause isolation and recovery guidance.
- **Fault Management**: `scripts/fault_manager.sh` injects controlled faults and executes master recovery.

---

## 5. Operations & Demonstration Instructions

### Prerequisites
- macOS Apple Silicon (arm64)
- Homebrew packages: `dnsmasq`, `nginx`, `wireshark` (`tshark`), Python 3.11+

### Master Service Controls
```bash
# Start all 4 logical machines
./scripts/manage_services.sh start-all

# Inspect status of all subsystems
./scripts/manage_services.sh status

# Stop all services
./scripts/manage_services.sh stop-all
```

### Centralized NOC Dashboard
Launch the web operations dashboard:
```bash
python3 scripts/dashboard_server.py &
open http://127.0.0.1:8000/
```
The dashboard updates every 2 seconds, displaying live machine statuses, PID tracking, DNS synchronization, and interactive demonstration controls.

### Running Test Suites
```bash
# Run Master Phase 2 Verification Suite (Tests Extensions A through F)
./scripts/run_all_phase2_tests.sh

# Run Individual Extension Tests:
./scripts/test_dns_failover.sh       # Extension A
./scripts/test_dns_ttl.sh            # Extension B
./scripts/test_service_isolation.sh  # Extension C
./scripts/test_ha_failover.sh        # Extension D
./scripts/test_edge_migration.sh     # Extension E
./scripts/diagnose_stack.sh          # Extension F
```

---

## 6. Academic Deliverables Index

- [docs/PHASE2_FINAL_REPORT.md](file:///Users/ritikraj/CN-Project/docs/PHASE2_FINAL_REPORT.md) — Comprehensive academic project report.
- [docs/ARCHITECTURE.md](file:///Users/ritikraj/CN-Project/docs/ARCHITECTURE.md) — Detailed architecture specification and Mermaid diagrams.
- [docs/TESTING_AND_EVIDENCE.md](file:///Users/ritikraj/CN-Project/docs/TESTING_AND_EVIDENCE.md) — Extension-by-extension testing and verification logs.
- [docs/CONFIGURATION_GUIDE.md](file:///Users/ritikraj/CN-Project/docs/CONFIGURATION_GUIDE.md) — Configuration guide and port allocations.
- [docs/TROUBLESHOOTING.md](file:///Users/ritikraj/CN-Project/docs/TROUBLESHOOTING.md) — Layer 1–7 troubleshooting guide and fault matrix.
- [docs/VIVA_QUESTIONS.md](file:///Users/ritikraj/CN-Project/docs/VIVA_QUESTIONS.md) — 30 comprehensive technical viva questions and answers.
- [docs/FINAL_PRESENTATION.md](file:///Users/ritikraj/CN-Project/docs/FINAL_PRESENTATION.md) — Slide-by-slide final presentation outline.
- [docs/phase-2/final-engineering-audit.md](file:///Users/ritikraj/CN-Project/docs/phase-2/final-engineering-audit.md) — Engineering audit and security findings.
- [evidence/README.md](file:///Users/ritikraj/CN-Project/evidence/README.md) — Index of all runtime logs and Wireshark captures.

---

## 7. Limitations & Single-Mac Adaptations

1. **Host-Level Fault Domain**: All four simulated machines run on one physical MacBook. A kernel crash or power outage affects all nodes simultaneously. In production, these roles would be distributed across distinct physical availability zones.
2. **DNS Port Invariance**: Standard DNS A-records map hostnames to IP addresses; they do not encode port numbers. Consequently, migrating traffic from port 8443 to port 9443 on the same IP requires client-side port awareness.
3. **Loopback Traffic Encapsulation**: Inter-process traffic on `127.0.0.1` does not traverse a physical switch and is captured via the Darwin loopback interface (`lo0`).

---

## 8. Author & Repository
- **Author**: Ritik Raj
- **Course**: Computer Networks Course Project
- **Git Branch**: `phase2-single-mac`
- **Backup Branch**: `phase1-backup`
- **GitHub Repository**: [https://github.com/Ritik-62/CN-Project](https://github.com/Ritik-62/CN-Project)
