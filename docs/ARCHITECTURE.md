# System Architecture — Private Network Service Platform

## 1. System Overview
The Private Network Service Platform is a local, resilient network environment designed to demonstrate core networking protocols: DNS resolution, caching, TCP connection lifecycle, TLS termination, reverse proxy load balancing, service isolation, and edge failover.

The implementation runs entirely on **a single physical Apple Silicon macOS workstation**. The four logical machines specified in the course design are implemented as dedicated, decoupled daemon processes bound to distinct ports and loopback sockets on `127.0.0.1`.

---

## 2. End-to-End Logical Architecture

```mermaid
flowchart TD
    Client["Client / Evaluation Tools<br/>(curl / dig / Browser)"]

    subgraph M1["Logical Machine 1: DNS Subsystem"]
        direction TB
        CachingResolver["Caching Resolver (dnsmasq)<br/>127.0.0.1:5356<br/>Cache Size: 150 names"]
        PrimaryDNS["Primary Authoritative DNS<br/>127.0.0.1:5355<br/>local-ttl: 30s"]
        BackupDNS["Backup Authoritative DNS<br/>127.0.0.1:5354<br/>local-ttl: 30s"]
        RecordsFile["Host Records File<br/>config/dnsmasq/records.hosts"]
        
        CachingResolver -->|Forward on Cache Miss| PrimaryDNS
        PrimaryDNS -.->|Dynamic SIGHUP Reload| RecordsFile
        BackupDNS -.->|Dynamic SIGHUP Reload| RecordsFile
    end

    subgraph EdgeTier["Edge Reverse Proxy Tier"]
        direction TB
        MainEdge["Logical Machine 2: Main Edge (nginx)<br/>HTTPS: 127.0.0.1:8443 (TLS Termination)<br/>HTTP: 127.0.0.1:8080<br/>Header: X-Edge: Main"]
        StandbyEdge["Logical Machine 4: Standby Edge (nginx)<br/>HTTPS: 127.0.0.1:9443 (TLS Termination)<br/>HTTP: 127.0.0.1:9080<br/>Header: X-Edge: Standby"]
    end

    subgraph UpstreamTier["Logical Machine 3 & 4: Backend Compute Tier"]
        direction LR
        BackendA["Logical Machine 3: Backend A<br/>Python HTTP: 127.0.0.1:3001<br/>Header: X-Backend: A<br/>Policy: Service Isolation Token"]
        BackendB["Logical Machine 4: Backend B<br/>Python HTTP: 127.0.0.1:3002<br/>Header: X-Backend: B<br/>Policy: Service Isolation Token"]
    end

    Client -->|1. DNS Query| CachingResolver
    Client -->|Failover DNS Query| BackupDNS
    Client -->|2. HTTPS Request :8443| MainEdge
    Client -.->|2. HTTPS Post-Cutover :9443| StandbyEdge

    MainEdge -->|Passive Health Check / Round-Robin| BackendA
    MainEdge -->|Passive Health Check / Round-Robin| BackendB
    StandbyEdge -->|Passive Health Check / Round-Robin| BackendA
    StandbyEdge -->|Passive Health Check / Round-Robin| BackendB
```

---

## 3. Logical Machine Mapping & Role Isolation

| Logical Node | Simulated Hardware Role | Running Service & Port | Configuration Artifact | Process Isolation |
|---|---|---|---|---|
| **Machine 1** | Primary Nameserver & Client | Primary DNS (`:5355`)<br/>Backup DNS (`:5354`)<br/>Caching Resolver (`:5356`) | `config/dnsmasq/dnsmasq-primary.conf`<br/>`config/dnsmasq/dnsmasq-backup.conf`<br/>`config/dnsmasq/dnsmasq-cache.conf` | Distinct PID files: `/tmp/dnsmasq-primary.pid`, `/tmp/dnsmasq-backup.pid`, `/tmp/dnsmasq-cache.pid` |
| **Machine 2** | Edge Reverse Proxy & Load Balancer | Main nginx (`:8443` SSL / `:8080` HTTP) | `config/nginx/nginx-main.conf` | PID: `/tmp/nginx-main.pid`, dedicated logs in `/tmp/nginx-main-*.log` |
| **Machine 3** | Backend Compute Node A | Python HTTP Server (`:3001`) | `backends/backend-a/server.py` | PID: `/tmp/backend-a.pid`, standard out log `/tmp/backend-a.log` |
| **Machine 4** | Backend Compute Node B & Standby Edge | Python HTTP Server (`:3002`)<br/>Standby nginx (`:9443` SSL / `:9080` HTTP) | `backends/backend-b/server.py`<br/>`config/nginx/nginx-standby.conf` | PIDs: `/tmp/backend-b.pid`, `/tmp/nginx-standby.pid` |

---

## 4. Network Protocol Flow & Data Path

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant DNS as Machine 1 (DNS)
    participant Edge as Machine 2 (Main Edge :8443)
    participant BackA as Machine 3 (Backend A :3001)
    participant BackB as Machine 4 (Backend B :3002)

    Client->>DNS: Standard DNS Query (A app.cnproject.test)
    DNS-->>Client: Authoritative Response (127.0.0.1, TTL: 30)
    Note over Client,Edge: TCP Three-Way Handshake (SYN -> SYN/ACK -> ACK)
    Client->>Edge: TLS 1.3 ClientHello (SNI: app.cnproject.test)
    Edge-->>Client: TLS ServerHello + Certificate Chain (Self-Signed CA)
    Note over Client,Edge: TLS Session Key Exchange & Handshake Complete
    Client->>Edge: HTTPS GET /api/status (Encrypted Application Data)
    Note over Edge: Terminate TLS, Evaluate Upstream Pool, Inject X-CN-Edge-Token
    Edge->>BackA: HTTP/1.1 GET /api/status (Proxy Request)
    BackA-->>Edge: HTTP/1.0 200 OK (X-Backend: A, JSON Payload)
    Edge-->>Client: HTTPS 200 OK (X-Edge: Main, X-Backend: A, X-Cache-Status)
```

---

## 5. Architectural Invariants
1. **Single Physical Workstation**: No external virtual machines, containers, or remote hosts are assumed. All communications occur via loopback sockets.
2. **Deterministic Port Allocations**: All ports exceed 1024, enabling clean execution under macOS standard non-root privileges.
3. **Decoupled Configuration**: Every logical component maintains independent configuration and state tracking, allowing any service to be halted without cascading failures to unrelated daemons.
