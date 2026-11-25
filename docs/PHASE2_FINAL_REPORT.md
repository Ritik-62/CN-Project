# Academic Project Report — Phase 2: Private Network Service Platform

**Course**: Computer Networks Course Project  
**Project Title**: Private Network Service Platform — Production Hardening, High Availability, Recovery & Diagnostic Engineering  
**Student Name**: Ritik Raj  
**Host Architecture**: Apple Silicon MacBook Pro (arm64, macOS Darwin)  
**Repository Branch**: `phase2-single-mac`  
**Checkpoint Baseline**: `phase1-backup` (Commit `560da04`)  
**Date**: November 2026  

---

## Abstract
This project presents the design, implementation, and empirical evaluation of a hardened private network service platform deployed on a single physical Apple Silicon workstation. While modern client-server interactions appear trivial at the application layer, they depend on an intricate chain of lower-layer network protocols. In Phase 1, a foundational baseline consisting of private DNS resolution, TCP handshaking, TLS 1.3 termination, reverse proxying, round-robin load balancing, and HTTP caching was established. 

Phase 2 advances this baseline into an enterprise-resilient platform addressing real-world network failure modes. Six extensions were engineered: (1) an independent primary-backup DNS resolver pair with automated client-side failover; (2) authoritative DNS TTL management demonstrating TTL countdown, stale cache retention, and manual invalidation; (3) service isolation enforcing cryptographic edge token verification to block unauthorized direct backend access; (4) upstream high-availability failover utilizing nginx passive health checks; (5) zero-downtime standby edge migration via DNS cutover; and (6) an automated layer-by-layer diagnostic engine and fault injection manager. Real-time observability is provided via a centralized web-based Network Operations Center (NOC) dashboard. All extensions were rigorously validated using automated test suites, resulting in actual runtime logs and raw packet captures.

---

## 1. Introduction & Problem Statement
In enterprise production networks, high availability, resilience, and security isolation are paramount. Systems that function correctly under ideal conditions often collapse when components fail. A crash of an authoritative nameserver halts name resolution; an outage of an edge proxy interrupts all ingress traffic; an unshielded backend invites direct denial-of-service attacks; and unmanaged DNS caching creates extended service blackouts during migrations.

The fundamental premise of this project is: **"The application stays simple — the network is the project."** Rather than expending effort on complex application business logic, lightweight HTTP microservices were utilized to expose and measure the underlying transport, security, and application-layer networking dynamics.

The central challenge addressed in this work is: **How can a complete, multi-tiered enterprise network architecture featuring redundancy, isolation, and failover be authentically simulated and evaluated on ONE physical Apple Silicon MacBook without mocking network behavior or requiring multi-node physical hardware?**

---

## 2. Objectives & Scope
The key objectives of Phase 2 are:
1. **Eliminate Single Points of Failure (SPOFs)** at both the DNS naming tier and the edge reverse proxy tier.
2. **Demonstrate DNS Protocol Caching & Eventual Consistency** using authentic caching forwarders and configurable TTLs.
3. **Enforce Service Isolation** to restrict direct access to backend application ports.
4. **Implement Automatic Backend Failover** with zero dropped requests during single-node outages.
5. **Demonstrate Controlled Edge Cutover** using DNS record manipulation and response header verification.
6. **Construct a Layer-by-Layer Diagnostic Engine** spanning physical/network, transport, session/presentation, and application tiers.
7. **Maintain 100% Backward Compatibility** with Phase 1 deliverables without file corruption or breaking changes.

---

## 3. System Requirements & Technology Stack

### Hardware & Environment
- **Platform**: Apple MacBook Pro
- **Processor**: Apple Silicon (arm64, M-series)
- **Host Operating System**: macOS Darwin 24.6.0
- **Network Interface**: Loopback (`lo0` / `127.0.0.1`), Wi-Fi (`en0`)

### Software Components
- **Nameserver Software**: `dnsmasq` version 2.93 (Homebrew)
- **Edge Reverse Proxy**: `nginx` version 1.31.6 (Homebrew)
- **Packet Sniffer & Analyzer**: `TShark` / `Wireshark` version 4.6.9
- **Backend Runtimes**: Python 3.11.7 standard library (`http.server`, `socket`, `subprocess`)
- **Cryptographic Tools**: OpenSSL 3.x for X.509 certificate and SAN management
- **Client Utilities**: `curl` 8.7.1, BIND `dig` 9.10.6, `nc` (netcat)

---

## 4. Network Topology & Port Allocations

### 4.1 Logical-to-Physical Mapping
Four distinct machine roles are simulated as independent daemon processes on loopback sockets:

```
[Logical Machine 1: DNS Subsystem]
├── Primary DNS (dnsmasq)       : 127.0.0.1:5355 (TTL=30s)
├── Backup DNS (dnsmasq)        : 127.0.0.1:5354 (TTL=30s)
└── Caching Resolver (dnsmasq)  : 127.0.0.1:5356 (Cache=150)

[Logical Machine 2: Main Edge]
└── nginx Reverse Proxy         : 127.0.0.1:8443 (TLS) / :8080 (HTTP) [X-Edge: Main]

[Logical Machine 3: Backend A]
└── Python HTTP Server          : 127.0.0.1:3001 [X-Backend: A]

[Logical Machine 4: Backend B & Standby Edge]
├── Python HTTP Server          : 127.0.0.1:3002 [X-Backend: B]
└── Standby nginx Reverse Proxy : 127.0.0.1:9443 (TLS) / :9080 (HTTP) [X-Edge: Standby]

[Workstation Operations]
└── Centralized NOC Dashboard   : 127.0.0.1:8000
```

### 4.2 Port Allocation Table

| Service Identifier | Logical Machine | Transport | Port | Purpose |
|---|---|---|---|---|
| Primary DNS | Machine 1 | UDP / TCP | 5355 | Authoritative Primary Resolver |
| Backup DNS | Machine 1 | UDP / TCP | 5354 | Authoritative Secondary Resolver |
| Caching Resolver | Machine 1 | UDP / TCP | 5356 | Forwarding Cache (TTL Demonstration) |
| Main Edge HTTPS | Machine 2 | TCP | 8443 | Primary Ingress & TLS Termination |
| Main Edge HTTP | Machine 2 | TCP | 8080 | Primary Cleartext Ingress |
| Standby Edge HTTPS | Machine 4 | TCP | 9443 | Secondary Ingress & TLS Termination |
| Standby Edge HTTP | Machine 4 | TCP | 9080 | Secondary Cleartext Ingress |
| Backend A | Machine 3 | TCP | 3001 | Application Server Node A |
| Backend B | Machine 4 | TCP | 3002 | Application Server Node B |
| Operations Dashboard | Host | TCP | 8000 | Real-time Telemetry Web Interface |

---

## 5. Detailed Extension Engineering

### 5.1 Extension A: Redundant Backup DNS Resolver
- **Motivation**: In Phase 1, nameserver failure caused immediate service failure.
- **Design**: Primary DNS (`:5355`) and Backup DNS (`:5354`) execute as isolated daemons with independent PID tracking (`/tmp/dnsmasq-primary.pid`, `/tmp/dnsmasq-backup.pid`) and separate log sinks. Both read authoritative mappings from `config/dnsmasq/records.hosts`.
- **Client Failover**: `scripts/dns_client_resolver.sh` enforces query ordering: queries Primary first with a 1-second timeout; upon failure, it transparently fails over to Backup and logs the responding resolver.
- **Results**: Primary process was halted (`kill`). Client query immediately resolved via Backup (`127.0.0.1:5354`) with zero dropped queries. Packet capture: `evidence/phase-2/backup-dns-failover.pcapng`.

### 5.2 Extension B: DNS TTL & Caching Resolver
- **Motivation**: Real-world DNS relies on caching forwarders that exhibit eventual consistency during record updates.
- **Design**: Both authoritative daemons return `local-ttl=30`. A dedicated caching forwarder (`:5356`) runs with `cache-size=150` pointing upstream to port 5355.
- **Demonstration**:
  1. Initial query cached with `TTL: 30`.
  2. Query 5 seconds later returns `TTL: 25` (countdown verified).
  3. Authoritative record modified to `127.0.0.2` via `manage_dns.sh set-record 127.0.0.2`.
  4. Query at T=6s still returns `127.0.0.1` with `TTL: 24` (stale cache retention verified).
  5. After 29s wait, cache expires; query returns `127.0.0.2` with fresh `TTL: 30`.
  6. SIGHUP signal demonstrated to immediately invalidate cache.
- **Evidence**: `evidence/phase-2/dns-ttl-test.txt` and `dns-ttl-capture.pcapng`.

### 5.3 Extension C: Service Isolation & Backend Security
- **Motivation**: Backend application ports should never accept unauthenticated direct traffic from clients.
- **Challenge on Single Mac**: Client processes and edge proxies share loopback IP (`127.0.0.1`), making loopback IP-level filtering impossible without dropping proxy connections.
- **Solution**: Dual-layer defense-in-depth:
  - Edge proxies inject an internal authentication header `X-CN-Edge-Token`.
  - Backends reject direct unauthenticated requests (`curl http://127.0.0.1:3001/`) with **HTTP 403 Forbidden** (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
  - Edge-proxied requests (`curl https://app.cnproject.test:8443/`) are authenticated and return **HTTP 200 OK** (`X-Isolation-Status: Allowed-Edge-Authenticated`).
- **Evidence**: `evidence/phase-2/service-isolation-test.txt`.

### 5.4 Extension D: Upstream High Availability & Failover
- **Motivation**: Prevent edge request drops when individual backends fail.
- **Design**:
  ```nginx
  upstream cnproject_backends {
      server 127.0.0.1:3001 max_fails=1 fail_timeout=5s;
      server 127.0.0.1:3002 max_fails=1 fail_timeout=5s;
  }
  proxy_next_upstream error timeout invalid_header http_502 http_503;
  proxy_next_upstream_tries 2;
  ```
- **Results**:
  - Backend A halted: 100% of requests routed to Backend B without client errors.
  - Backend A restarted: After 5s `fail_timeout`, load balancing seamlessly resumed.
  - Both backends halted: Controlled `HTTP 502 Bad Gateway` returned.
  - Backends restarted: Self-healing recovery to `HTTP 200 OK`.
- **Evidence**: `evidence/phase-2/ha-failover-test.txt`.

### 5.5 Extension E: Controlled Standby Edge Migration
- **Motivation**: Eliminate the edge reverse proxy as a single point of failure.
- **Design**: Standby nginx proxy deployed on port 9443 emitting header `X-Edge: Standby` (Main Edge emits `X-Edge: Main`). Both share the same trusted TLS certificate and upstream pool.
- **Results**: Executing `manage_dns.sh set-record 127.0.0.2` cut over traffic to Standby Edge. Subsequent queries confirmed `X-Edge: Standby` with active backend load balancing. Rollback safely restored Main Edge.
- **Evidence**: `evidence/phase-2/edge-migration-test.txt`.

### 5.6 Extension F: Troubleshooting & Diagnostic Engine
- **Motivation**: Prevent speculative troubleshooting by providing automated root-cause isolation.
- **Design**: `scripts/diagnose_stack.sh` tests:
  - *Layer 1–3*: Loopback interface and IPv4 address.
  - *Layer 4*: TCP ports 5355, 5354, 5356, 8443, 9443, 3001, 3002.
  - *Layer 5–6*: TLS handshake, certificate validity, SAN matches.
  - *Layer 7*: DNS resolution and HTTP application endpoints.
- **Fault Management**: `scripts/fault_manager.sh` injects controlled faults (`backend-a-down`, `dns-primary-down`, `both-backends-down`) and executes master recovery (`recover-all`).
- **Evidence**: `evidence/phase-2/diagnostic-report.txt`.

---

## 6. Testing Methodology & Verification Results

The entire platform was verified using the master test runner `scripts/run_all_phase2_tests.sh`.

```
================================================================================
CN-PROJECT: PHASE 2 MASTER VERIFICATION SUITE RESULTS
================================================================================
>>> [1/6] EXTENSION A (BACKUP DNS FAILOVER)          : PASS (100%)
>>> [2/6] EXTENSION B (DNS TTL & CACHE EXPIRATION)    : PASS (100%)
>>> [3/6] EXTENSION C (SERVICE ISOLATION ENFORCEMENT) : PASS (100%)
>>> [4/6] EXTENSION D (HIGH AVAILABILITY & FAILOVER)  : PASS (100%)
>>> [5/6] EXTENSION E (STANDBY EDGE MIGRATION)        : PASS (100%)
>>> [6/6] EXTENSION F (LAYER 1-7 DIAGNOSTIC SCAN)     : PASS (100%)
================================================================================
MASTER VERIFICATION RESULT: ALL SUITES PASSED (100% SUCCESS RATE)
================================================================================
```

---

## 7. Security Considerations & Secret Management
To eliminate vulnerabilities identified during the engineering audit:
1. **Zero Committed Secrets**: Hardcoded tokens were purged from source files. Secrets reside in `config/.secrets.env` (file mode `0600`), excluded via `.gitignore`.
2. **Private Key Protection**: Nginx TLS keys (`config/nginx/certs/*.key`) are strictly excluded in `.gitignore` and were never committed to version control.
3. **Command Whitelisting**: The NOC dashboard server executes only pre-approved administrative commands using structured argument lists (`shell=False`), preventing command injection attacks.

---

## 8. Limitations & Single-Mac Adaptations
1. **Host-Level Fault Domain**: All logical machines share the physical CPU, memory, and kernel of one Mac. Power failure halts all components simultaneously. In cloud production, these would be distributed across distinct availability zones.
2. **DNS Port Invariance**: DNS A-records update IP mappings but cannot alter client destination ports. Therefore, traffic migration between port 8443 and port 9443 on a single IP requires client port awareness.
3. **Loopback Traffic Encapsulation**: Inter-process traffic on `127.0.0.1` does not pass over physical Ethernet frames and is observable only via Darwin loopback packet interfaces (`lo0`).

---

## 9. Conclusion
Phase 2 successfully transformed the single-Mac Computer Networks project into an enterprise-grade private network service platform. By combining independent DNS resolvers, authoritative TTL caching, cryptographic service isolation, nginx passive health failover, standby edge migration, and automated diagnostic tooling, the project provides rigorous empirical proof of core transport and application-layer networking principles.

---

## 10. References
1. Mockapetris, P. (1987). *Domain Names — Concepts and Facilities*. RFC 1034.
2. Fielding, R., et al. (2014). *Hypertext Transfer Protocol (HTTP/1.1): Caching*. RFC 7234.
3. Rescorla, E. (2018). *The Transport Layer Security (TLS) Protocol Version 1.3*. RFC 8446.
4. NGINX Documentation. *Using NGINX as an HTTP Load Balancer*. F5 Networks.
5. Kelley, S. *Dnsmasq — A Lightweight DHCP and Caching DNS Server*.
