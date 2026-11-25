# Technical Viva Questions & Comprehensive Answers

This document prepares candidates for individual academic viva defense across all core networking concepts demonstrated in Phase 1 and Phase 2.

---

## 1. Domain Name System (DNS) & Caching

### Q1: What is the primary functional difference between an Authoritative DNS server and a Caching Resolver?
**Answer**: An Authoritative DNS server holds the original, definitive zone records for a domain (such as `app.cnproject.test`) and assigns the initial Time to Live (TTL). A Caching Resolver does not possess authoritative zone data; it queries authoritative servers on behalf of clients, caches the response in memory, and serves subsequent queries directly while decrementing the TTL counter until it reaches zero.

### Q2: Why does standard DNS use UDP port 53 by default, and under what conditions does it switch to TCP?
**Answer**: DNS utilizes UDP port 53 because UDP is connectionless and lightweight, incurring no three-way handshake overhead for small request/response transactions. DNS falls back to TCP port 53 when:
1. The response message size exceeds 512 bytes (or the negotiated EDNS0 buffer size), indicated by the Truncation (TC) flag in the DNS header.
2. Zone transfers (AXFR/IXFR) take place between master and replica servers requiring reliable stream delivery.

### Q3: What is the significance of the DNS Time to Live (TTL)?
**Answer**: TTL is a 32-bit unsigned integer specifying the maximum duration in seconds that an intermediary caching resolver or client stub resolver is permitted to cache a DNS resource record. A lower TTL (e.g., 30s) enables rapid traffic migration or cutover at the cost of higher query volume, whereas a higher TTL minimizes query overhead but increases propagation latency during changes.

### Q4: How does our project demonstrate DNS eventual consistency during record migration?
**Answer**: In Extension B, the Authoritative DNS was updated from `127.0.0.1` to `127.0.0.2`. When queried immediately, the Caching Resolver continued returning `127.0.0.1` because its local cache held an unexpired entry with 24 seconds remaining. Only when the TTL reached zero did the caching resolver forward a new query upstream and retrieve `127.0.0.2`.

### Q5: How does a client operating system handle primary DNS server failure?
**Answer**: When the primary DNS server fails to respond within a timeout threshold, the client resolver library attempts the secondary nameserver configured in its resolver list. In our implementation, `scripts/dns_client_resolver.sh` queries the primary resolver on port 5355 with a 1-second timeout and transparently falls back to the backup resolver on port 5354 upon timeout or failure.

---

## 2. Transport Layer (TCP) & Ports

### Q6: What packets constitute the TCP three-way handshake, and what is its objective?
**Answer**: The three-way handshake consists of:
1. **SYN**: Client sends a Synchronize packet with an initial sequence number ($ISN_c$).
2. **SYN-ACK**: Server acknowledges with an Acknowledgement number ($ISN_c + 1$) and its own sequence number ($ISN_s$).
3. **ACK**: Client acknowledges with ($ISN_s + 1$).
The objective is to establish synchronized sequence numbers, negotiate maximum segment size (MSS) and window scaling parameters, and verify bidirectional connectivity before application data exchange.

### Q7: What is the purpose of ephemeral ports versus well-known ports?
**Answer**: Well-known ports (0–1023) and registered ports (1024–49151) identify specific listening server services (e.g., port 53 for DNS, port 8443 for HTTPS). Ephemeral ports (49152–65535) are dynamically allocated by the client OS kernel for the client endpoint of a socket pair, uniquely identifying the communication channel.

### Q8: What occurs at the transport layer when a client attempts to connect to an unoccupied port?
**Answer**: The operating system kernel on the destination host sends an immediate TCP packet with the **RST (Reset)** flag set, resulting in a `Connection refused` error on the client. If an intermediate packet filter drops the packet, the client experiences a connection timeout.

---

## 3. Security, TLS & Cryptography

### Q9: Explain the primary steps of a TLS 1.3 handshake.
**Answer**:
1. **ClientHello**: Client sends supported cipher suites, key shares (Diffie-Hellman), and Server Name Indication (SNI).
2. **ServerHello**: Server selects the cipher suite, provides its key share, presents its X.509 certificate, and sends a Finished message.
3. **Application Data**: Once keys are derived, symmetric encryption (e.g., AES-GCM or ChaCha20-Poly1305) begins immediately with a single round-trip time (1-RTT).

### Q10: What is Server Name Indication (SNI) and why is it necessary?
**Answer**: SNI is an extension to the TLS protocol whereby the client indicates the hostname it is attempting to connect to in the ClientHello packet. This allows a reverse proxy hosting multiple virtual domains on a single IP address to present the correct TLS certificate before decrypting the HTTP request.

### Q11: What is the purpose of Subject Alternative Names (SAN) in an X.509 certificate?
**Answer**: The SAN extension allows an SSL/TLS certificate to specify multiple hostnames, domain names, or IP addresses (e.g., `DNS:app.cnproject.test, DNS:api.cnproject.test`) for which the certificate is valid, replacing the deprecated Common Name (CN) field.

### Q12: How is service isolation implemented on a single Mac in this project?
**Answer**: Because all processes share `127.0.0.1`, network packet filters cannot distinguish between client curl commands and nginx proxy processes originating from the same loopback interface. We implemented a defense-in-depth model: the edge proxy injects an authenticated header (`X-CN-Edge-Token`). Backend application servers validate this token; direct client access without the token is rejected with `HTTP 403 Forbidden`, while edge-proxied traffic is granted access.

---

## 4. Reverse Proxying, Load Balancing & High Availability

### Q13: What is the difference between a forward proxy and a reverse proxy?
**Answer**: A forward proxy acts on behalf of clients to access external Internet services, often for caching, content filtering, or anonymity. A reverse proxy acts on behalf of backend origin servers, serving as the single public entry point for incoming client requests to provide TLS termination, load balancing, and application caching.

### Q14: How does round-robin load balancing distribute incoming requests?
**Answer**: Round-robin balancing cyclically cycles through an ordered upstream pool, routing request $N$ to server 1, request $N+1$ to server 2, and so forth. In our project, consecutive requests alternate between Backend A (`X-Backend: A`) and Backend B (`X-Backend: B`).

### Q15: What is the difference between active and passive health checks in nginx?
**Answer**:
- **Passive Health Checks**: Monitored inline during actual client requests using directives like `max_fails` and `fail_timeout`. If a backend fails or times out during a live request, nginx marks it temporarily down and fails over to the next upstream node.
- **Active Health Checks**: Independent background probes periodically sent to upstream backends regardless of client traffic (available in NGINX Plus).

### Q16: What does the HTTP 502 Bad Gateway status code indicate?
**Answer**: HTTP 502 indicates that nginx, while acting as a gateway or reverse proxy, attempted to connect to an upstream backend server and received an invalid response, connection refusal, or timeout. In our project, halting both Backend A and Backend B triggers a controlled 502 Bad Gateway response.

### Q17: What does `proxy_next_upstream` accomplish?
**Answer**: It specifies which error conditions (e.g., `error timeout invalid_header http_502 http_503`) trigger nginx to immediately retry the client request on the next configured upstream server, ensuring zero dropped requests during single-node backend failures.

---

## 5. Caching & HTTP Protocols

### Q18: What is the role of the `Cache-Control` header?
**Answer**: It dictates caching directives across all caching agents (browsers, intermediary CDNs, and reverse proxies). For example, `Cache-Control: public, max-age=60` allows any cache to store the response and consider it fresh for 60 seconds without revalidating with the origin server.

### Q19: Explain the meaning of `X-Cache-Status` header values.
**Answer**:
- **MISS**: The requested resource was not in cache; nginx fetched it from the upstream backend.
- **HIT**: The resource was served directly from the local proxy cache without contacting the backend.
- **EXPIRED**: A previously cached entry exists but its `max-age` has elapsed; nginx fetches a fresh copy.
- **BYPASS**: Caching was bypassed due to directives such as `proxy_cache_bypass`.

### Q20: What is conditional validation using ETags and `If-None-Match`?
**Answer**: The server sends an entity tag (`ETag`) representing the specific version of a resource. On subsequent requests, the client sends `If-None-Match: <etag>`. If the content has not changed, the server responds with `HTTP 304 Not Modified` with no response body, saving network bandwidth.

---

## 6. Architecture, Migration & Failover

### Q21: What is a Single Point of Failure (SPOF)? What was the SPOF in Phase 1?
**Answer**: A SPOF is any component whose failure causes the entire system to halt. In Phase 1, the single DNS server and the single nginx edge proxy were both single points of failure. In Phase 2, we eliminated these by adding a Backup DNS resolver and a Standby Edge proxy.

### Q22: Why does DNS record cutover alone not update the client's destination port during edge migration?
**Answer**: DNS A-records map hostnames to IP addresses exclusively; they do not encode port numbers. When DNS changes `app.cnproject.test` from `127.0.0.1` to `127.0.0.2`, the client continues connecting to whichever port is in its URL (e.g., port 8443). To migrate to port 9443 on a single host, clients must explicitly query the standby port, or IP aliasing must be employed.

### Q23: What is the purpose of the `X-Edge: Main` and `X-Edge: Standby` headers?
**Answer**: They provide verifiable proof of which physical or logical edge node terminated the TLS session and proxied the request, allowing evaluators to confirm edge cutover and rollback without ambiguity.

### Q24: What is the purpose of SIGHUP in Unix network daemons?
**Answer**: SIGHUP (Signal Hangup, signal 1) is conventionally used by network daemons (such as `dnsmasq` and `nginx`) to reload configuration files, re-read host record mappings, and flush internal caches without terminating the running process or closing active sockets.

### Q25: How does this local single-Mac deployment translate to cloud architectures?
**Answer**:
- `dnsmasq` represents managed DNS services like Amazon Route 53 or Cloudflare DNS.
- `nginx` represents Cloud Load Balancers (AWS ALB, Google Cloud HTTP Load Balancer) or Cloudflare CDN edge nodes.
- Python HTTP backends represent containerized microservices running on ECS, Kubernetes, or Google Cloud Run.
- The Standby Edge represents multi-region active-passive failover infrastructure.

---

## 7. Troubleshooting & Operational Scenarios

### Q26: If `curl -i https://app.cnproject.test:8443/` hangs indefinitely, what is the first diagnostic step?
**Answer**: Test transport-layer reachability using `nc -z -G 2 127.0.0.1 8443`. If the connection hangs, the issue is at the TCP/packet filter level. If it connects, the issue is an upstream timeout or TLS negotiation hang.

### Q27: If `dig app.cnproject.test` returns `NXDOMAIN`, what does that indicate?
**Answer**: `NXDOMAIN` (Non-Existent Domain) indicates that the queried DNS server is operational and reachable, but has no record matching the requested domain name in its authoritative zones or forwarders.

### Q28: What is the difference between `curl: (7) Failed to connect` and an HTTP 502 response?
**Answer**:
- `curl: (7)` is a Layer 4 TCP connection failure: no service is listening on the destination port, or the connection was actively refused.
- `HTTP 502` is a Layer 7 application gateway response: the edge proxy was reached over TCP and terminated TLS successfully, but its connection to the upstream backend failed.

### Q29: How can an administrator verify that a TLS certificate matches a given private key?
**Answer**: By computing and comparing the public key hashes using OpenSSL:
```bash
openssl x509 -noout -modulus -in cert.crt | openssl md5
openssl rsa -noout -modulus -in key.key | openssl md5
```
If both MD5 checksums match, the certificate and private key form a valid cryptographic pair.

### Q30: How does the diagnostic engine `diagnose_stack.sh` achieve automated root-cause isolation?
**Answer**: It queries layers in dependency order: if Layer 4 port check fails for a service, it flags a daemon crash; if Layer 4 passes but Layer 6 TLS fails, it isolates a handshake or certificate issue; if Layer 6 passes but Layer 7 returns 502, it pinpoints upstream backend failure.
