# Phase 2 — Production Network Architecture Document

## 1. Executive Summary & Objective
This document defines the comprehensive architecture of **Phase 2 (Harden, Recover & Troubleshoot)** for the Computer Networks Course Project (*Private Network Service Platform*).

The implementation transitions the initial Phase 1 prototype into an enterprise-grade, fault-tolerant private service platform running entirely on **ONE physical Apple Silicon MacBook Pro** while maintaining strict logical process, network socket, and security separation across four simulated hardware roles.

---

## 2. Simulated 4-Machine Logical Topology

```
+---------------------------------------------------------------------------------------------------------+
|                                    PHYSICAL HOST: APPLE SILICON MACBOOK PRO                             |
|                                                                                                         |
|  +----------------------------------+                   +--------------------------------------------+  |
|  |     MACHINE 1: DNS SUBSYSTEM     |                   |       MACHINE 2: MAIN EDGE (REVERSE PROXY) |  |
|  |                                  |                   |                                            |  |
|  |  [Primary Authoritative DNS]     |                   |  [nginx Reverse Proxy / Load Balancer]     |  |
|  |  Socket: 127.0.0.1:5355 (UDP/TCP)|                   |  HTTPS Socket: 127.0.0.1:8443 (TLS Term.)  |  |
|  |  Config: dnsmasq-primary.conf    |                   |  HTTP Socket:  127.0.0.1:8080              |  |
|  |  Records: app.cnproject.test     |                   |  Config: nginx-main.conf                   |  |
|  |  TTL: 30 seconds                 |                   |  Cert: app.cnproject.test.crt (CA Trusted) |  |
|  |                                  |                   |  Health Checks: max_fails=1 fail_timeout=5s|  |
|  |  [Backup Authoritative DNS]      |                   |  Response Header: X-Edge: Main             |  |
|  |  Socket: 127.0.0.1:5354 (UDP/TCP)|                   +---------------------+----------------------+  |
|  |  Config: dnsmasq-backup.conf     |                                         |                         |
|  |  TTL: 30 seconds                 |                                         | Upstream Proxying       |
|  |                                  |                                         | (Round-Robin HA)        |
|  |  [Local Caching Resolver]        |                                         v                         |
|  |  Socket: 127.0.0.1:5356 (UDP/TCP)|                   +--------------------------------------------+  |
|  |  Forwarder: 127.0.0.1#5355       |                   |           UPSTREAM SERVICE TIER            |  |
|  |  Cache Size: 150 entries         |                   |                                            |  |
|  +----------------------------------+                   |  +--------------------------------------+  |  |
|                                                         |  |      MACHINE 3: BACKEND SERVER A     |  |  |
|                                                         |  |  Socket: 127.0.0.1:3001              |  |  |
|                                                         |  |  Identity: X-Backend: A              |  |  |
|                                                         |  |  Security: Service Isolation Token   |  |  |
|                                                         |  +--------------------------------------+  |  |
|                                                         |                                            |  |
|  +----------------------------------+                   |  +--------------------------------------+  |  |
|  |      MACHINE 4: STANDBY EDGE     |                   |  |      MACHINE 4: BACKEND SERVER B     |  |  |
|  |                                  |                   |  Socket: 127.0.0.1:3002              |  |  |
|  |  [Standby nginx Reverse Proxy]   |                   |  Identity: X-Backend: B              |  |  |
|  |  HTTPS Socket: 127.0.0.1:9443    |                   |  Security: Service Isolation Token   |  |  |
|  |  HTTP Socket:  127.0.0.1:9080    |                   |  +--------------------------------------+  |  |
|  |  Config: nginx-standby.conf      |                   +--------------------------------------------+  |
|  |  Response Header: X-Edge: Standby|                                                                   |
|  +----------------------------------+                                                                   |
+---------------------------------------------------------------------------------------------------------+
```

---

## 3. Subsystem Breakdown

### 3.1 Extension A: Redundant Backup DNS Resolver
- **Architecture**: Primary DNS (`:5355`) and Backup DNS (`:5354`) operate as independent `dnsmasq` instances with separate PID tracking, dedicated logs, and synchronized authoritative host files.
- **Client Failover Engine**: `scripts/dns_client_resolver.sh` enforces deterministic query-order fallback: attempts Primary with a 1-second timeout, immediately fails over to Backup upon error, and logs the responding nameserver.

### 3.2 Extension B: DNS TTL & Traffic Migration
- **TTL Configuration**: Authoritative responses return an explicit 30-second TTL (`local-ttl=30`).
- **Caching Resolver**: A local caching forwarder (`:5356`) demonstrates RFC-compliant eventual consistency: when an authoritative record changes from `127.0.0.1` (Main Edge) to `127.0.0.2` (Standby Edge), cached clients continue receiving the old IP until the 30-second countdown reaches 0.
- **Manual Cache Invalidation**: Supports instantaneous cache flushing via `SIGHUP` signal.

### 3.3 Extension C: Service Isolation & Security
- **Defense-in-Depth Model**:
  - **Application Token Enforcement**: Backends verify `X-CN-Edge-Token: cn-project-edge-trusted-secret-2026`. Direct client access without this token returns `HTTP 403 Forbidden`.
  - **Packet Filter Compatibility**: macOS `pf` firewall rule generator blocks external access to backend ports while preserving loopback connectivity.

### 3.4 Extension D: Upstream High Availability & Failover
- **nginx Passive Health Checks**:
  ```nginx
  upstream cnproject_backends {
      server 127.0.0.1:3001 max_fails=1 fail_timeout=5s;
      server 127.0.0.1:3002 max_fails=1 fail_timeout=5s;
  }
  proxy_next_upstream error timeout invalid_header http_502 http_503;
  proxy_next_upstream_tries 2;
  ```
- **Fault Resilience**: If Backend A stops, requests immediately failover to Backend B with zero dropped requests. When Backend A restarts and the 5-second `fail_timeout` expires, load balancing seamlessly auto-resumes. If both backends fail, a controlled `HTTP 502 Bad Gateway` is returned.

### 3.5 Extension E: Controlled Edge Migration
- **Standby Edge**: An independent nginx instance runs on port 9443 (`X-Edge: Standby`) with identical upstream routing and TLS termination.
- **Cutover**: Authoritative DNS is updated to `127.0.0.2`. Standby Edge assumes traffic, enabling zero-downtime edge maintenance.

### 3.6 Extension F: Troubleshooting & Fault Management
- **Diagnostic Engine**: `scripts/diagnose_stack.sh` systematically verifies Layer 1-3 (Interfaces), Layer 4 (Ports), Layer 5-6 (TLS & Certificates), and Layer 7 (DNS & HTTP applications), isolating root causes with automated remediation advice.
- **Fault Injection**: `scripts/fault_manager.sh` enables controlled, reversible failure simulations.

### 3.7 Centralized Monitoring Dashboard
- Native Python telemetry server running on `http://127.0.0.1:8000/` providing real-time infrastructure visualization and interactive operations controls.
