# Evidence Directory — Packet Captures and Execution Logs

This directory contains verified runtime test logs, terminal exports, and raw Wireshark/TShark packet captures generated during the implementation and evaluation of Phase 1 and Phase 2.

All evidence was collected from live network daemon processes executing on **one physical Apple Silicon MacBook Pro**.

---

## Directory Index

### Phase 2 Evidence (`evidence/phase-2/`)

| File | Type | Description |
|---|---|---|
| [`master-phase2-test-report.txt`](phase-2/master-phase2-test-report.txt) | Text Log | Unified execution output of the Master Phase 2 Verification Suite (Extensions A through F). |
| [`backup-dns-failover-test.txt`](phase-2/backup-dns-failover-test.txt) | Text Log | Full terminal trace of Extension A primary failure and backup DNS resolution. |
| [`backup-dns-failover.pcapng`](phase-2/backup-dns-failover.pcapng) | Packet Capture | Loopback Wireshark capture of DNS queries failing on port 5355 and succeeding on port 5354. |
| [`dns-ttl-test.txt`](phase-2/dns-ttl-test.txt) | Text Log | Extension B terminal log showing TTL decrement, stale cache retention, and expiration. |
| [`dns-ttl-capture.pcapng`](phase-2/dns-ttl-capture.pcapng) | Packet Capture | Raw packet capture demonstrating DNS query/response cycles with 30s TTL. |
| [`service-isolation-test.txt`](phase-2/service-isolation-test.txt) | Text Log | Verification of Scenarios A through E (403 Forbidden for direct access, 200 OK via edge). |
| [`ha-failover-test.txt`](phase-2/ha-failover-test.txt) | Text Log | Verification of Cases 1 through 6 (upstream load balancing, failure handling, 502, recovery). |
| [`edge-migration-test.txt`](phase-2/edge-migration-test.txt) | Text Log | Controlled migration from Main Edge (`:8443`) to Standby Edge (`:9443`) via DNS cutover. |
| [`diagnostic-report.txt`](phase-2/diagnostic-report.txt) | Text Log | Complete Layer 1 through Layer 7 diagnostic scan report. |

### Phase 1 Evidence (`evidence/module-3/` & `evidence/module-4/`)

| File | Type | Description |
|---|---|---|
| [`cache-verification.txt`](module-3/cache-verification.txt) | Text Log | Module 3 proxy cache verification (`X-Cache-Status: HIT` / `EXPIRED`). |
| [`tls-verification.txt`](module-3/tls-verification.txt) | Text Log | Module 3 TLS termination verification on port 443. |
| [`dns-capture.pcapng`](module-4/dns-capture.pcapng) | Packet Capture | Phase 1 DNS query and response exchange. |
| [`https-flow-capture.pcapng`](module-4/https-flow-capture.pcapng) | Packet Capture | Phase 1 TCP handshake, TLS 1.3 handshake, and encrypted application data. |
| [`backend-a-failure.txt`](module-4/backend-a-failure.txt) | Text Log | Phase 1 failure test when Backend A was halted. |
| [`both-backends-failure.txt`](module-4/both-backends-failure.txt) | Text Log | Phase 1 failure test resulting in HTTP 502 Bad Gateway. |
| [`wrong-dns-server.txt`](module-4/wrong-dns-server.txt) | Text Log | Phase 1 failure test querying public DNS (8.8.8.8) returning NXDOMAIN. |
| [`wrong-dns-record.txt`](module-4/wrong-dns-record.txt) | Text Log | Phase 1 failure test querying non-existent domain name. |
| [`wrong-destination-port.txt`](module-4/wrong-destination-port.txt) | Text Log | Phase 1 failure test querying closed destination port. |
