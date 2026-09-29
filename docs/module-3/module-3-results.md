# Module 3 — HTTPS/TLS & HTTP Caching

## Scope

Module 3 implements the Phase 1 requirements for:

- Task E — Add HTTPS / TLS
- Task F — Demonstrate HTTP Caching Behavior

The edge service is nginx.

Backend services:

- Backend A — port 3001
- Backend B — port 3002

Application domain:

- `app.cnproject.test`

HTTPS:

- TCP port 443

---

## Task E — HTTPS / TLS

### TLS Termination

nginx terminates HTTPS connections on TCP port 443.

The HTTPS server is configured for:

- `app.cnproject.test`
- `api.cnproject.test`

TLS is terminated at the nginx edge and requests are then proxied to the backend services.

### Certificate

A self-signed X.509 certificate was generated using OpenSSL.

The active certificate contains the following Subject Alternative Names:

- `DNS:app.cnproject.test`
- `DNS:api.cnproject.test`

SAN verification was performed with:
```bash
sudo openssl x509 -in /opt/homebrew/etc/nginx/certs/server-san.crt -noout -ext subjectAltName
```

Verified result:

```text
X509v3 Subject Alternative Name:
    DNS:app.cnproject.test, DNS:api.cnproject.test
```
### nginx Configuration Validation

The nginx configuration was validated with:

```bash
sudo nginx -t

## Task F — HTTP Caching

### nginx Cache Configuration

nginx uses a local proxy cache:

```nginx
proxy_cache_path /opt/homebrew/var/cache/nginx/cnproject levels=1:2 keys_zone=cnproject_cache:10m max_size=100m inactive=60m use_temp_path=off;


---

## Module 3 Verification Summary

| Requirement | Result |
|---|---|
| HTTPS on port 443 | PASS |
| Self-signed TLS certificate | PASS |
| SAN for `app.cnproject.test` | PASS |
| SAN for `api.cnproject.test` | PASS |
| Certificate trusted by macOS | PASS |
| HTTPS works without `curl -k` | PASS |
| nginx TLS termination | PASS |
| `Cache-Control` header | PASS |
| nginx proxy caching | PASS |
| Cache reuse demonstrated | PASS |

## Conclusion

Task E (HTTPS / TLS) and Task F (HTTP Caching) have been implemented and verified for the single-Mac project environment.

Module 3 implementation is complete.

Packet-level DNS/TCP/TLS flow capture and Phase 1 failure demonstrations are handled separately under Task G / Module 4.