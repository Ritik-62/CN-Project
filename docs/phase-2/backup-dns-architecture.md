# Phase 2 — Backup DNS Resolver Architecture

## 1. Overview
In Phase 1, a single DNS instance (`dnsmasq`) was deployed as the private nameserver for the project domain `cnproject.test`. This represented a Single Point of Failure (SPOF): if the primary DNS service crashed or became unreachable, name resolution failed immediately, preventing clients from connecting to the edge reverse proxy.

In Phase 2, an independent **Backup DNS Resolver** has been implemented. This satisfies **Extension A** of the Computer Networks course project specification.

## 2. Single-Mac Adaptation Topology
Because the entire project must execute on a single physical MacBook, the primary and backup DNS services run as two isolated, independent daemon processes bound to dedicated local loopback endpoints:

```
                            CLIENT RESOLVER
                     (scripts/dns_client_resolver.sh)
                                    │
                                    │ 1. Attempt Primary Query
                                    ▼
                         ┌─────────────────────┐
                         │     Primary DNS     │
                         │       dnsmasq       │
                         │   127.0.0.1:5355    │
                         └──────────┬──────────┘
                                    │ (Failure / Timeout)
                                    ▼
                         ┌─────────────────────┐
                         │     Backup DNS      │
                         │       dnsmasq       │
                         │   127.0.0.1:5354    │
                         └──────────┬──────────┘
                                    │ Success Response: 127.0.0.1
                                    ▼
                         ┌─────────────────────┐
                         │     nginx Edge      │
                         │   Port 80 / 443     │
                         └─────────────────────┘
```

## 3. Configuration Breakdown

### Primary DNS
- **Binary**: `/opt/homebrew/sbin/dnsmasq`
- **Config**: `config/dnsmasq/dnsmasq-primary.conf`
- **Socket**: `127.0.0.1:5355` (UDP/TCP)
- **PID File**: `/tmp/dnsmasq-primary.pid`
- **Log File**: `/tmp/dnsmasq-primary.log`
- **Records**:
  - `app.cnproject.test` → `127.0.0.1`
  - `api.cnproject.test` → `127.0.0.1`

### Backup DNS
- **Binary**: `/opt/homebrew/sbin/dnsmasq`
- **Config**: `config/dnsmasq/dnsmasq-backup.conf`
- **Socket**: `127.0.0.1:5354` (UDP/TCP)
- **PID File**: `/tmp/dnsmasq-backup.pid`
- **Log File**: `/tmp/dnsmasq-backup.log`
- **Records**:
  - `app.cnproject.test` → `127.0.0.1`
  - `api.cnproject.test` → `127.0.0.1`

## 4. Key Design Principles
1. **Process Isolation**: The two instances have separate configuration files, separate logging paths, separate PID files, and distinct socket ports. Stopping, modifying, or killing the primary instance has zero impact on the backup instance.
2. **Configuration Synchronization**: Both instances maintain identical authoritative records for the `.test` project namespace.
3. **No Privileged Changes**: By selecting verified unprivileged ports (`5355` and `5354`), the DNS failover architecture operates completely safely without requiring system administrator or root modifications to `/etc/resolv.conf` or `/etc/resolver`.
4. **Client-Side Failover Intelligence**: As macOS system resolvers do not guarantee sub-second failover across arbitrary ports, the client failover mechanism (`scripts/dns_client_resolver.sh`) provides deterministic query-order enforcement (Primary first, detect timeout/failure, immediately fallback to Backup).
