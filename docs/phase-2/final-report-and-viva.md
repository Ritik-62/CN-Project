# Phase 2 — Final Project Report & Comprehensive Viva Preparation

## 1. Executive Summary
- **Course**: Computer Networks Course Project
- **Project Title**: Private Network Service Platform (Phase 2: Harden, Recover & Troubleshoot)
- **Author**: Ritik Raj
- **Hardware Architecture**: 1 Physical Apple Silicon MacBook Pro
- **Branch**: `phase2-single-mac`

### What Changed from Phase 1 to Phase 2:
1. **DNS Resilience**: Evolved from a single `dnsmasq` instance (SPOF) to redundant **Primary** (`:5355`) and **Backup** (`:5354`) resolvers with automated client failover and real packet capture evidence.
2. **DNS TTL & Caching**: Added explicit 30-second TTL and a dedicated Caching Resolver (`:5356`) demonstrating eventual consistency, stale cache retention during record updates, and manual SIGHUP cache flushing.
3. **Service Isolation**: Replaced open backend access with an edge-token security policy (`X-CN-Edge-Token`) and pf firewall rules, blocking direct client access (403 Forbidden) while preserving edge proxying.
4. **High Availability**: Configured nginx passive health checks (`max_fails=1 fail_timeout=5s`, `proxy_next_upstream`), proving 100% request continuity during backend failures, auto-recovery upon restart, and controlled 502 Bad Gateway handling.
5. **Edge Migration**: Added a Standby Edge nginx instance (`:9443`, `X-Edge: Standby`), demonstrating seamless DNS cutover and rollback.
6. **Diagnostic Automation**: Built an automated layer-by-layer diagnostic engine (`scripts/diagnose_stack.sh`), a fault-injection manager (`scripts/fault_manager.sh`), and a real-time web operations dashboard (`http://127.0.0.1:8000/`).

---

## 2. Comprehensive Viva Questions & Expert Answers

### Q1: Why is DNS over UDP port 53 by default, and when does it use TCP?
> **Answer**: Standard DNS queries and responses use UDP port 53 because UDP is connectionless and incurs zero connection-establishment overhead (no 3-way handshake), making lookups fast. DNS falls back to TCP port 53 when response sizes exceed 512 bytes (or EDNS0 buffer limits), during zone transfers (AXFR), or when the TC (Truncation) bit is set in the UDP header.

### Q2: What is the exact difference between an Authoritative DNS server and a Caching Resolver?
> **Answer**: An Authoritative DNS server holds the definitive, configured DNS records for a domain (e.g. `app.cnproject.test`) and sets the original TTL. A Caching Resolver does not own the domain; it queries authoritative servers on behalf of clients, stores the response in memory, and serves subsequent queries locally while decrementing the TTL counter until it reaches zero.

### Q3: Why does client traffic not immediately switch when an Authoritative DNS record changes?
> **Answer**: Because of DNS TTL caching. Intermediary caching resolvers and operating system stub resolvers (such as macOS `mDNSResponder`) cache the previous answer for the duration specified by the TTL. Clients continue receiving the cached (stale) answer until the TTL expires or the cache is manually flushed.

### Q4: How does nginx distinguish between active and passive health checks?
> **Answer**: Open-source nginx supports **passive health checks**: it detects backend failure during actual live client requests using `max_fails` and `fail_timeout`. If a request fails, `proxy_next_upstream` redirects the request to the next backend without client interruption, and marks the failed node temporarily down. Active health checks (synthetic probing independent of client traffic) require NGINX Plus or third-party modules.

### Q5: How does this project achieve service isolation on a single Mac?
> **Answer**: Because all processes share `127.0.0.1`, pure IP filtering on loopback cannot distinguish between an nginx worker process and a client curl command. We implemented a defense-in-depth model: the edge injects a cryptographic header `X-CN-Edge-Token`. The backends validate this header; direct unauthenticated client requests are blocked with HTTP 403 Forbidden, while edge-proxied requests succeed with HTTP 200 OK. Additionally, pf firewall rules block external Wi-Fi ingress.

### Q6: What is the remaining Single Point of Failure in this architecture, and how would enterprise cloud systems eliminate it?
> **Answer**: In our setup, the Main Edge nginx instance was initially a single point of failure. In Phase 2, we eliminated this by introducing a Standby Edge on port 9443 with DNS cutover. In enterprise cloud deployments, edge redundancy is achieved using Anycast BGP routing, VRRP/Keepalived (Virtual Router Redundancy Protocol) for floating VIPs, or cloud network load balancers (NLB/ALB) across multiple availability zones.
