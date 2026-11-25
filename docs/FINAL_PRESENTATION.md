# Phase 2 Final Presentation Slide Deck Outline

**Project Title**: Private Network Service Platform — Phase 2: Harden, Recover & Troubleshoot  
**Author**: Ritik Raj  
**Target Environment**: 1 Physical Apple Silicon MacBook Pro (4-Machine Logical Simulation)  
**Course**: Computer Networks Course Project  

---

## Slide 1: Title & Project Overview
- **Header**: Private Network Service Platform (Phase 2)
- **Subtitle**: Enterprise Hardening, High Availability, Resilience, and Diagnostic Engineering
- **Presenter**: Ritik Raj
- **Core Principle**: *"The application stays simple — the network is the project."*
- **Execution Target**: Single Physical Apple Silicon Mac running four fully decoupled logical nodes.

---

## Slide 2: Problem Statement & Objectives
- **Problem**: Modern web requests involve complex multi-layer networking dependencies (DNS, TCP, TLS, Reverse Proxying, Load Balancing). A failure at any single point disrupts service.
- **Phase 1 Baseline**: Built core functionality (single DNS, single edge, round-robin backends, TLS termination).
- **Phase 2 Mission**: Eliminate single points of failure, enforce service isolation, demonstrate real DNS TTL behavior, enable controlled edge cutover, and build an automated diagnostic engine.

---

## Slide 3: 4-Machine Logical Architecture (Single Mac)
- **Visual**: Mermaid diagram showing logical nodes:
  - **Machine 1 (DNS Subsystem)**: Primary DNS (`:5355`), Backup DNS (`:5354`), Caching Resolver (`:5356`).
  - **Machine 2 (Main Edge)**: nginx Reverse Proxy (`:8443` SSL / `:8080` HTTP, `X-Edge: Main`).
  - **Machine 3 (Backend Node A)**: Python HTTP Server (`:3001`, `X-Backend: A`).
  - **Machine 4 (Backend Node B & Standby Edge)**: Python HTTP Server (`:3002`, `X-Backend: B`), Standby nginx (`:9443` SSL, `X-Edge: Standby`).
- **Isolation Key**: Decoupled daemon processes, distinct listening sockets, independent PID and log tracking.

---

## Slide 4: Extension A — Redundant Backup DNS Resolver
- **Concept**: Eliminating the DNS Single Point of Failure.
- **Implementation**:
  - Independent primary (`:5355`) and backup (`:5354`) `dnsmasq` daemons.
  - Client failover script `scripts/dns_client_resolver.sh`.
- **Live Demo Point**: Stop Primary DNS -> Client automatically queries Backup -> Answer resolved in ~1 second with zero user interruption.
- **Evidence**: `backup-dns-failover-test.txt` and raw packet capture `backup-dns-failover.pcapng`.

---

## Slide 5: Extension B — DNS TTL & Caching Resolver
- **Concept**: Eventual consistency and cache lifetime in DNS-based migrations.
- **Implementation**:
  - Authoritative TTL set to 30 seconds (`local-ttl=30`).
  - Local caching resolver running on port 5356 (`cache-size=150`).
- **Live Demo Point**:
  1. Initial query cached with TTL=30.
  2. Countdown observed (30 -> 25 -> 24).
  3. Authoritative record updated to `127.0.0.2`.
  4. Caching resolver continues serving old `127.0.0.1` until TTL expires!
  5. Post-expiration query retrieves new `127.0.0.2` with fresh TTL=30.
  6. SIGHUP cache flush demonstrated.
- **Evidence**: `dns-ttl-test.txt` and `dns-ttl-capture.pcapng`.

---

## Slide 6: Extension C — Service Isolation & Backend Security
- **Concept**: Zero-trust edge mediation — blocking direct access to backend application servers.
- **Implementation**:
  - Defense-in-depth model: Edge injects cryptographic `X-CN-Edge-Token`.
  - Backends enforce token validation when isolation is enabled.
- **Live Demo Point**:
  - Direct access `http://127.0.0.1:3001/` -> **403 Forbidden** (`Blocked-Direct-Access-Denied`).
  - Access via Edge `https://app.cnproject.test:8443/` -> **200 OK** (`Allowed-Edge-Authenticated`).
- **Evidence**: `service-isolation-test.txt`.

---

## Slide 7: Extension D — High Availability & Upstream Failover
- **Concept**: Nginx passive health checks and passive failover backend resilience.
- **Implementation**:
  - `upstream cnproject_backends` with `max_fails=1 fail_timeout=5s`.
  - `proxy_next_upstream error timeout invalid_header http_502 http_503`.
- **Live Demo Point**:
  - Stop Backend A -> 100% of requests routed to Backend B with zero dropped requests.
  - Restart Backend A -> After 5s timeout, load balancing seamlessly auto-resumes.
  - Stop both backends -> Controlled **HTTP 502 Bad Gateway**.
  - Restart backends -> Self-healing auto-recovery.
- **Evidence**: `ha-failover-test.txt`.

---

## Slide 8: Extension E — Controlled Edge Migration
- **Concept**: Eliminating the Edge reverse proxy Single Point of Failure.
- **Implementation**:
  - Standby Edge nginx running on port 9443 with identical upstream pool and TLS certificate.
  - Headers: `X-Edge: Main` vs `X-Edge: Standby`.
- **Live Demo Point**:
  - DNS cutover executed -> Standby Edge assumes application traffic.
  - Rollback executed -> Main Edge safely resumes traffic.
- **Evidence**: `edge-migration-test.txt`.

---

## Slide 9: Extension F — Troubleshooting & Diagnostic Engine
- **Concept**: Automated layer-by-layer root-cause deduction (Layers 1 through 7).
- **Implementation**:
  - Diagnostic scanner `scripts/diagnose_stack.sh`.
  - Fault manager `scripts/fault_manager.sh`.
- **Live Demo Point**: Inject fault (e.g., stop Backend A) -> Run diagnostic -> Scanner identifies exact layer, fault description, and exact recovery command.
- **Evidence**: `diagnostic-report.txt`.

---

## Slide 10: Centralized NOC Operations Dashboard
- **Concept**: Real-time infrastructure observability.
- **Implementation**: Native Python web server (`http://127.0.0.1:8000/`) with real-time telemetry polling every 2 seconds.
- **Features**: Visual status badges for all 4 machines, DNS sync status, active edge routing, and interactive buttons for live failover demonstrations.

---

## Slide 11: Single-Mac Limitations & Enterprise Comparison
- **Single-Mac Constraint**:
  - All processes share loopback (`127.0.0.1`).
  - DNS A-record cutover updates the destination IP, but client HTTPS port must match the target edge listener (8443 vs 9443).
- **Enterprise Cloud Equivalent**:
  - Physical multi-datacenter nodes across availability zones.
  - Anycast BGP routing and floating Virtual IPs (VIPs via Keepalived/VRRP) for transparent edge failover.

---

## Slide 12: Conclusion & Summary of Deliverables
- **Status**: 100% of Phase 1 and Phase 2 requirements implemented and verified.
- **Deliverables**:
  - 12 comprehensive documentation guides.
  - 10 automated test and management scripts.
  - 6 verified evidence logs and 2 raw Wireshark pcapng packet captures.
  - Master Verification Report (`master-phase2-test-report.txt`) confirming 100% test pass rate.
