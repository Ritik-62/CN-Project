# Phase 2 — Controlled Edge Migration & Standby Edge (Extension E)

## 1. Architecture Overview
In enterprise networks, having redundant backend servers is not enough: the edge reverse proxy itself can be a **Single Point of Failure (SPOF)**. If the edge load balancer crashes or requires hardware maintenance, all client traffic is interrupted.

**Extension E** introduces a **Standby Edge** instance, enabling zero-downtime edge migration via DNS cutover.

```
                  AUTHORITATIVE DNS
                  (app.cnproject.test)
                      │          │
         Initial:     │          │  Migrated:
         127.0.0.1   │          │  127.0.0.2
                      ▼          ▼
            ┌──────────────┐    ┌──────────────┐
            │  MAIN EDGE   │    │ STANDBY EDGE │
            │  nginx :8443 │    │  nginx :9443 │
            │ X-Edge: Main │    │X-Edge:Standby│
            └───────┬──────┘    └──────┬───────┘
                    │                  │
                    └────────┬─────────┘
                             │
                             ▼
                    [ BACKEND SERVICES ]
                    (Backend A & Backend B)
```

---

## 2. Configuration & Process Isolation
1. **Main Edge**:
   - Configuration: `config/nginx/nginx-main.conf`
   - Ports: `8443` (HTTPS) / `8080` (HTTP)
   - PID: `/tmp/nginx-main.pid`
   - Header: `X-Edge: Main`
2. **Standby Edge**:
   - Configuration: `config/nginx/nginx-standby.conf`
   - Ports: `9443` (HTTPS) / `9080` (HTTP)
   - PID: `/tmp/nginx-standby.pid`
   - Header: `X-Edge: Standby`

Both edge instances share the same trusted TLS certificate (`app.cnproject.test.crt`), proxy cache settings, and upstream pool definitions.

---

## 3. Migration Sequence & Test Results

Test suite: `./scripts/test_edge_migration.sh`

### Step 1: Pre-Flight Health Check
- Query Standby Edge on port 9443 directly.
- Verified response: `HTTP 200 OK`, `X-Edge: Standby`, upstream routing active.

### Step 2: DNS Cutover
- Execute `manage_dns.sh set-record 127.0.0.2`.
- Primary and Backup authoritative DNS instantly reload and serve `app.cnproject.test → 127.0.0.2`.

### Step 3: Traffic Migration
- Client requests routed to Standby Edge.
- Verified response headers:
  ```text
  HTTP/1.1 200 OK
  X-Edge: Standby
  X-Backend: A / B (alternating)
  ```

### Step 4: Graceful Rollback
- Execute `manage_dns.sh reset-records` and flush cache.
- Traffic cleanly reverts to Main Edge (`X-Edge: Main`).

Evidence log: [edge-migration-test.txt](file:///Users/ritikraj/CN-Project/evidence/phase-2/edge-migration-test.txt)
