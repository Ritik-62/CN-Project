# Configuration Guide — Private Network Service Platform

## 1. Directory Structure

```
config/
├── dnsmasq/
│   ├── dnsmasq-primary.conf    # Authoritative Primary DNS config (:5355)
│   ├── dnsmasq-backup.conf     # Authoritative Backup DNS config (:5354)
│   ├── dnsmasq-cache.conf      # Local Caching Resolver config (:5356)
│   └── records.hosts           # Authoritative A-record mapping
└── nginx/
    ├── certs/
    │   ├── cnproject-ca.crt    # Root Certificate Authority
    │   ├── app.cnproject.test.crt  # Edge SAN Certificate
    │   └── app.cnproject.test.ext  # OpenSSL SAN extensions
    ├── nginx-main.conf         # Main Edge reverse proxy (:8443 SSL / :8080 HTTP)
    └── nginx-standby.conf      # Standby Edge reverse proxy (:9443 SSL / :9080 HTTP)
```

---

## 2. Port Allocation Reference Table

| Service Identifier | Logical Host | Transport | Port | Purpose | Health Endpoint |
|---|---|---|---|---|---|
| **Primary DNS** | Machine 1 | UDP / TCP | `5355` | Authoritative DNS Primary Resolver | `dig @127.0.0.1 -p 5355 app.cnproject.test` |
| **Backup DNS** | Machine 1 | UDP / TCP | `5354` | Authoritative DNS Backup Resolver | `dig @127.0.0.1 -p 5354 app.cnproject.test` |
| **Caching Resolver** | Machine 1 | UDP / TCP | `5356` | Local Caching Forwarder (TTL Observation) | `dig @127.0.0.1 -p 5356 app.cnproject.test` |
| **Main Edge HTTPS** | Machine 2 | TCP | `8443` | Primary Reverse Proxy & TLS Termination | `https://app.cnproject.test:8443/api/status` |
| **Main Edge HTTP** | Machine 2 | TCP | `8080` | Primary Unencrypted Ingress | `http://127.0.0.1:8080/api/status` |
| **Standby Edge HTTPS** | Machine 4 | TCP | `9443` | Standby Reverse Proxy & TLS Termination | `https://app.cnproject.test:9443/api/status` |
| **Standby Edge HTTP** | Machine 4 | TCP | `9080` | Standby Unencrypted Ingress | `http://127.0.0.1:9080/api/status` |
| **Backend Node A** | Machine 3 | TCP | `3001` | Upstream Application Server A | `http://127.0.0.1:3001/health` |
| **Backend Node B** | Machine 4 | TCP | `3002` | Upstream Application Server B | `http://127.0.0.1:3002/health` |
| **Operations Dashboard** | Workstation | TCP | `8000` | Centralized Telemetry & Operations Web UI | `http://127.0.0.1:8000/api/status` |

---

## 3. DNS Configuration Analysis

### 3.1 Authoritative Primary & Backup (`dnsmasq-primary.conf` / `dnsmasq-backup.conf`)
- `port=5355` / `port=5354`: Assigns dedicated non-privileged ports.
- `listen-address=127.0.0.1`: Constrains socket listening to loopback.
- `bind-interfaces`: Ensures socket binding does not collide with other local resolvers.
- `no-resolv`: Disables reading default system `/etc/resolv.conf`.
- `addn-hosts=.../config/dnsmasq/records.hosts`: Loads authoritative A-records from an external mapping file.
- `local-ttl=30`: Forces dnsmasq to return an authoritative TTL of exactly 30 seconds.

### 3.2 Caching Resolver (`dnsmasq-cache.conf`)
- `port=5356`: Listens on port 5356.
- `server=127.0.0.1#5355`: Forwards all domain queries upstream to the Primary Authoritative DNS.
- `cache-size=150`: Allocates local memory for 150 DNS resource record sets.

---

## 4. Nginx Edge & Upstream High Availability

### Upstream Definition
Both `nginx-main.conf` and `nginx-standby.conf` configure identical upstream pools:
```nginx
upstream cnproject_backends {
    server 127.0.0.1:3001 max_fails=1 fail_timeout=5s;
    server 127.0.0.1:3002 max_fails=1 fail_timeout=5s;
}
```

### Proxy Failover Directives
```nginx
proxy_next_upstream error timeout invalid_header http_502 http_503;
proxy_next_upstream_tries 2;
proxy_next_upstream_timeout 5s;
proxy_connect_timeout 2s;
proxy_read_timeout 3s;
```
When a connection to one backend fails or times out, nginx transparently routes the pending request to the remaining backend without returning an error to the client.

---

## 5. Secret & Security Token Management

To comply with production security standards:
- Secrets are stored outside version control in `config/.secrets.env` (file mode `0600`).
- Nginx imports the authentication token via `config/nginx/security-token.conf` (file mode `0600`), which is excluded in `.gitignore`.
- Backends read `CN_EDGE_SECRET` dynamically from the environment or `.secrets.env`.
