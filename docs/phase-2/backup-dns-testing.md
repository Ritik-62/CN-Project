# Phase 2 — Backup DNS Resolver Testing & Evidence

## 1. Test Objectives
1. Verify both Primary (`127.0.0.1:5355`) and Backup (`127.0.0.1:5354`) DNS instances start independently.
2. Verify direct resolution of `app.cnproject.test` and `api.cnproject.test` via `dig` against both instances.
3. Inject a failure by stopping the Primary DNS process while the Backup DNS continues running.
4. Verify that the Primary DNS is offline and that the client automatically falls back to Backup DNS.
5. Restore the Primary DNS service and verify that the system returns to its normal primary-preferred state.
6. Collect packet capture evidence of the DNS failover sequence.

## 2. Test Execution

The automated test script is executed via:
```bash
./scripts/test_dns_failover.sh
```

### Test Output Summary
- **Primary DNS Direct Query**:
  ```text
  ;; ANSWER SECTION:
  app.cnproject.test.    0    IN    A    127.0.0.1
  Status: NOERROR
  ```
- **Backup DNS Direct Query**:
  ```text
  ;; ANSWER SECTION:
  app.cnproject.test.    0    IN    A    127.0.0.1
  Status: NOERROR
  ```
- **Failure Injection**:
  Primary DNS process was stopped with `manage_dns.sh stop-primary`.
  Querying Primary DNS resulted in: `;; connection timed out; no servers could be reached`.
- **Failover Verification**:
  ```text
  [DNS Client] WARNING: Primary DNS (127.0.0.1:5355) unreachable or returned empty.
  [DNS Client] INITIATING FAILOVER -> Querying Backup DNS (127.0.0.1:5354)...
  [DNS Client] FAILOVER SUCCESS: Answered by Backup DNS (127.0.0.1:5354)
  [DNS Client] Answer: 127.0.0.1
  ```
- **Restoration**:
  Primary DNS restarted. Subsequent queries immediately hit Primary DNS as preferred resolver.

## 3. Evidence Artifacts
- **Automated Test Log**: [backup-dns-failover-test.txt](../../evidence/phase-2/backup-dns-failover-test.txt)
- **Wireshark / TShark Packet Capture**: [backup-dns-failover.pcapng](../../evidence/phase-2/backup-dns-failover.pcapng)

### Packet Breakdown (`backup-dns-failover.pcapng`)
| Packet # | Protocol | Source → Destination | Description |
|---|---|---|---|
| 1 | DNS / LLMNR | `127.0.0.1:ephemeral` → `127.0.0.1:5355` | Query for `A app.cnproject.test` to Primary DNS (Timeout / No Response) |
| 2 | DNS | `127.0.0.1:ephemeral` → `127.0.0.1:5354` | Failover query for `A app.cnproject.test` to Backup DNS |
| 3 | DNS | `127.0.0.1:5354` → `127.0.0.1:ephemeral` | Response from Backup DNS: `app.cnproject.test A 127.0.0.1` |
