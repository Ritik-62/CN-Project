# Phase 2 — DNS TTL Testing & Evidence

## 1. Test Objectives
1. Verify that Authoritative DNS returns an explicit 30-second TTL.
2. Verify that the Caching Resolver stores the answer and shows the TTL decrementing over time.
3. Execute a controlled record change at the authoritative layer from `127.0.0.1` to `127.0.0.2`.
4. Prove that the Caching Resolver continues to return the old IP (`127.0.0.1`) while its cache remains unexpired.
5. Prove that after the TTL reaches 0, the Caching Resolver transparently retrieves the new IP (`127.0.0.2`).
6. Demonstrate manual cache flushing and immediate pickup of updated records.
7. Record packet capture evidence using TShark.

## 2. Automated Test Execution
Run the automated test suite:
```bash
./scripts/test_dns_ttl.sh
```

## 3. Observed Protocol Lifecycle

### Phase A: Initial Query & TTL Verification
- Authoritative DNS (`127.0.0.1:5355`):
  ```text
  app.cnproject.test.    30    IN    A    127.0.0.1
  ```
- Caching Resolver (`127.0.0.1:5356`):
  ```text
  Query 1 (T = 0s):  app.cnproject.test.    30    IN    A    127.0.0.1
  Query 2 (T = 5s):  app.cnproject.test.    25    IN    A    127.0.0.1
  ```

### Phase B: Controlled Migration & Stale Cache Retention
- Authoritative record updated to `127.0.0.2`.
- Direct query to Authoritative DNS returns `127.0.0.2` immediately.
- Query to Caching Resolver at T = 7s returns:
  ```text
  app.cnproject.test.    23    IN    A    127.0.0.1
  ```
  **Result**: Eventual consistency verified. Caching resolver shields client from immediate authoritative change until TTL expires.

### Phase C: Expiration & Fresh Resolution
- Wait until TTL = 0.
- Query to Caching Resolver returns:
  ```text
  app.cnproject.test.    30    IN    A    127.0.0.2
  ```
  **Result**: Cache expired. Fresh authoritative answer loaded with renewed 30-second TTL.

### Phase D: Manual Cache Invalidation
- Authoritative record changed back to `127.0.0.1`.
- Caching Resolver flushed via `manage_dns.sh flush-cache` (`kill -HUP`).
- Immediate query returns `127.0.0.1` without waiting for the 30-second timer.

## 4. Evidence Artifacts
- **Test Output Log**: [dns-ttl-test.txt](../../evidence/phase-2/dns-ttl-test.txt)
- **Wireshark / TShark Packet Capture**: [dns-ttl-capture.pcapng](../../evidence/phase-2/dns-ttl-capture.pcapng)
