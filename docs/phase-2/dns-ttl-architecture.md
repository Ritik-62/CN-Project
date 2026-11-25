# Phase 2 — DNS TTL Architecture & Controlled Record Change

## 1. Overview
DNS caching is one of the most fundamental mechanisms of the Internet, reducing query latency and offloading authoritative nameservers. However, caching introduces eventual consistency: when an authoritative record is modified, caching resolvers and clients continue to serve the old (stale) IP address until the record's **Time to Live (TTL)** expires.

This implementation satisfies **Extension B** of the Computer Networks project specification.

## 2. Technical Design & Single-Mac Topology
To demonstrate realistic DNS TTL behavior on a single physical MacBook without simulated delays or mocked data, three distinct DNS services run in coordination:

```
                      CLIENT APPLICATION / dig
                                │
                                │ 1. Query app.cnproject.test
                                ▼
                    ┌─────────────────────────┐
                    │    Caching Resolver     │
                    │         dnsmasq         │
                    │     127.0.0.1:5356      │
                    │  (cache-size=150 names) │
                    └───────────┬─────────────┘
                                │
                                │ Upstream Query (Cache Miss / Expiration)
                                ▼
         ┌─────────────────────────────────────────────────┐
         │        Primary Authoritative DNS                │
         │                 dnsmasq                         │
         │             127.0.0.1:5355                      │
         │           local-ttl = 30 seconds                │
         │       records: config/dnsmasq/records.hosts     │
         └─────────────────────────────────────────────────┘
```

## 3. Protocol Mechanics
1. **Configurable TTL**: Both Primary (`:5355`) and Backup (`:5354`) DNS instances are configured with `local-ttl=30`. All responses for `.test` domains contain an explicit 30-second TTL in the DNS answer section.
2. **Authoritative Record Storage**: Records are maintained in `config/dnsmasq/records.hosts` and dynamically reloaded by sending `SIGHUP` to the dnsmasq daemons without dropping sockets or requiring a service restart.
3. **Caching & Decrement**:
   - On the first client query, the Caching Resolver queries upstream and caches `app.cnproject.test → 127.0.0.1` with TTL=30.
   - Subsequent queries return decreasing TTLs (30 → 25 → 20 → ...).
4. **Controlled Record Change**:
   - The authoritative record is updated to `127.0.0.2` (representing a Standby Edge or new server IP).
   - The authoritative server immediately serves `127.0.0.2`.
   - The Caching Resolver **continues to return 127.0.0.1** until the 30-second countdown reaches 0.
5. **Cache Invalidation (Manual Flush)**:
   - In production, emergency cutovers require flushing resolver caches. Sending `SIGHUP` to the Caching Resolver process immediately invalidates all cached entries.
   - On macOS, equivalent client-side cache flushes are performed via:
     ```bash
     sudo dscacheutil -flushcache
     sudo killall -HUP mDNSResponder
     ```
