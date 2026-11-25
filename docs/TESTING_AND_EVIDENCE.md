# Testing and Evidence Guide — Phase 2 Verification

This document provides complete instructions for executing the Phase 2 test suites and maps each test scenario to its recorded runtime evidence.

---

## 1. Master Verification Suite

To run all six extension tests sequentially and compile a unified report:
```bash
./scripts/run_all_phase2_tests.sh
```
- **Report Location**: [evidence/phase-2/master-phase2-test-report.txt](../evidence/phase-2/master-phase2-test-report.txt)
- **Verified Result**: All 6 test suites passed with 100% success rate on macOS Apple Silicon.

---

## 2. Extension-by-Extension Test Matrix

### Extension A: Redundant Backup DNS Resolver
- **Script**: `scripts/test_dns_failover.sh`
- **Execution Command**:
  ```bash
  ./scripts/test_dns_failover.sh
  ```
- **Tested Lifecycle**:
  1. Primary DNS (:5355) returns `127.0.0.1` (NOERROR).
  2. Backup DNS (:5354) returns `127.0.0.1` (NOERROR).
  3. Client resolver queries Primary -> logs `Answered by Primary DNS (127.0.0.1:5355)`.
  4. Primary stopped -> Client queries Primary, detects timeout, fails over to Backup -> logs `Answered by Backup DNS (127.0.0.1:5354)`.
  5. Primary restarted -> Client queries immediately resume using Primary.
- **Evidence Artifacts**:
  - Log: [backup-dns-failover-test.txt](../evidence/phase-2/backup-dns-failover-test.txt)
  - Packet Capture: [backup-dns-failover.pcapng](../evidence/phase-2/backup-dns-failover.pcapng)

### Extension B: DNS TTL & Controlled Record Change
- **Script**: `scripts/test_dns_ttl.sh`
- **Execution Command**:
  ```bash
  ./scripts/test_dns_ttl.sh
  ```
- **Tested Lifecycle**:
  1. Authoritative Primary DNS returns `127.0.0.1` with `TTL: 30`.
  2. Caching Resolver (:5356) populates cache on initial query.
  3. Query 5 seconds later shows TTL decrement (`TTL: 25`).
  4. Authoritative record updated to `127.0.0.2` via `manage_dns.sh set-record 127.0.0.2`.
  5. Query to Caching Resolver at T=6s still returns `127.0.0.1` (stale cache retention).
  6. After 29s wait, cache expires; query returns `127.0.0.2` with fresh `TTL: 30`.
  7. Manual SIGHUP flush demonstrated; immediate query returns reverted `127.0.0.1`.
- **Evidence Artifacts**:
  - Log: [dns-ttl-test.txt](../evidence/phase-2/dns-ttl-test.txt)
  - Packet Capture: [dns-ttl-capture.pcapng](../evidence/phase-2/dns-ttl-capture.pcapng)

### Extension C: Service Isolation & Backend Security
- **Script**: `scripts/test_service_isolation.sh`
- **Execution Command**:
  ```bash
  ./scripts/test_service_isolation.sh
  ```
- **Tested Scenarios**:
  - *Scenario A*: Direct access to Backend A (:3001) -> `HTTP 403 Forbidden` (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
  - *Scenario B*: Direct access to Backend B (:3002) -> `HTTP 403 Forbidden` (`X-Isolation-Status: Blocked-Direct-Access-Denied`).
  - *Scenario C*: Main Edge (:8443) proxy access -> `HTTP 200 OK` (`X-Isolation-Status: Allowed-Edge-Authenticated`).
  - *Scenario D*: Standby Edge (:9443) proxy access -> `HTTP 200 OK` (`X-Isolation-Status: Allowed-Edge-Authenticated`).
  - *Scenario E*: End-to-end HTTPS access -> `HTTP 200 OK` (`X-Edge: Main`).
- **Evidence Artifacts**:
  - Log: [service-isolation-test.txt](../evidence/phase-2/service-isolation-test.txt)

### Extension D: Upstream High Availability & Failover
- **Script**: `scripts/test_ha_failover.sh`
- **Execution Command**:
  ```bash
  ./scripts/test_ha_failover.sh
  ```
- **Tested Cases**:
  - *Case 1*: Both backends healthy -> 4 requests to Backend A, 4 requests to Backend B.
  - *Case 2*: Backend A stopped -> 5/5 requests (100%) routed to Backend B with zero dropped requests.
  - *Case 3*: Backend A restarted -> After 5s `fail_timeout`, load balancing auto-resumes.
  - *Case 4*: Backend B stopped -> 5/5 requests routed to Backend A.
  - *Case 5*: Both backends stopped -> Edge returns `HTTP 502 Bad Gateway`.
  - *Case 6*: Backends recovered -> Edge auto-recovers to `HTTP 200 OK`.
- **Evidence Artifacts**:
  - Log: [ha-failover-test.txt](../evidence/phase-2/ha-failover-test.txt)

### Extension E: Controlled Edge Migration
- **Script**: `scripts/test_edge_migration.sh`
- **Execution Command**:
  ```bash
  ./scripts/test_edge_migration.sh
  ```
- **Tested Lifecycle**:
  - Baseline traffic routed to Main Edge (:8443) -> `X-Edge: Main`.
  - Standby Edge pre-flight checked on port 9443 -> `X-Edge: Standby`.
  - DNS record changed to `127.0.0.2` via `manage_dns.sh set-record 127.0.0.2`.
  - Standby Edge receives traffic and load balances across backends.
  - Rollback executed; traffic safely returns to Main Edge.
- **Evidence Artifacts**:
  - Log: [edge-migration-test.txt](../evidence/phase-2/edge-migration-test.txt)

### Extension F: Troubleshooting & Diagnostic Engine
- **Script**: `scripts/diagnose_stack.sh`
- **Execution Command**:
  ```bash
  ./scripts/diagnose_stack.sh
  ```
- **Diagnostic Scope**: Layer 1-3 (Interfaces), Layer 4 (Ports 5355, 5354, 5356, 8443, 9443, 3001, 3002), Layer 5-6 (TLS handshake & SAN), Layer 7 (DNS resolution & HTTP).
- **Evidence Artifacts**:
  - Log: [diagnostic-report.txt](../evidence/phase-2/diagnostic-report.txt)
